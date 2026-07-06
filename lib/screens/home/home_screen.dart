import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/pin.dart';
import '../../services/auth_service.dart';
import '../../services/category_color_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/photo_storage.dart';
import '../../services/route_db_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/marker_bitmap_util.dart';
import 'widgets/scratch_overlay.dart';
import '../profile/profile_screen.dart';
import '../run/running_live_screen.dart';
import '../save_files_screen.dart';
import 'category_color_screen.dart';
import 'place_input_screen.dart';
import 'route_list_screen.dart';
import 'timeline_screen.dart';
import 'widgets/pin_preview_sheet.dart';

/// 메인 화면.
///
/// 핵심 인터랙션:
///   - 우상단 빨간 점 = 기록 시작 / 정지
///   - 지도 길게 누르기 = 그 위치에 핀 추가 (사진+메모)
///   - 마커 탭 = 핀 미리보기 + 삭제 가능
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ─── 지도 / 위치 ───
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posSub;

  // ─── 카테고리 색상 ───
  final CategoryColorNotifier _colorNotifier = CategoryColorNotifier();

  // ─── 내 위치 커스텀 마커 ───
  Marker? _myLocationMarker;
  Position? _myPosition;

  // ─── 여정 상태 ───
  int? _currentRouteId;
  final List<LatLng> _path = [];

  /// 진행 중 여정의 polyline (1개, GPS 받을 때마다 갱신).
  Polyline? _currentPolyline;

  /// 저장된 경로 점들 — routeId → 점 목록.
  /// 스크래치 오버레이가 발자취 표시를 담당하므로 polyline 직접 안 그림.
  final Map<int, List<LatLng>> _savedRoutePoints = {};

  /// 지우기 반경 (m): 현재 위치에서 이 거리 이내 점은 제거.
  static const double _eraseRadiusMeters = 15.0;

  /// day_tracks 기반 발자취 — dayId → LatLng 리스트.
  /// **이전엔 polyline으로 그렸지만, v5에서 스크래치 오버레이로 변경**.
  Map<String, List<LatLng>> _dayTrackPoints = {};

  /// 스크래치 오버레이에 전달할 픽셀 좌표 리스트.
  /// 카메라 이동 시 [_recomputeTrackScreenPoints]에서 다시 계산.
  List<List<Offset>> _trackScreenPoints = [];

  /// 카메라 이동 디바운스 — 너무 자주 변환 안 하게.
  final bool _recomputeScheduled = false;

  Set<Marker> get _allMarkers {
    final markers = <Marker>{..._pinMarkers};
    if (_myLocationMarker != null) markers.add(_myLocationMarker!);
    return markers;
  }

  /// 진행 중 러닝만 polyline으로 표시 — 실시간성 우선
  /// (저장된 발자취/러닝은 스크래치 오버레이가 마스킹으로 표현)
  Set<Polyline> get _polylines => {
    if (_currentPolyline != null) _currentPolyline!,
  };

  final Set<Marker> _pinMarkers = {};
  final Map<String, Pin> _pinByMarkerId = {}; // markerId → Pin 역참조
  Position? _lastPos;

  // ─── UI 토글 ───
  int _bottomNavIndex = 0;

  static const _initialPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _colorNotifier.init(); // 저장된 색상 로드
    _colorNotifier.addListener(_onColorChanged);
    _restoreActiveRouteIfAny();
    _loadAllSavedRoutes();
    _loadDayTracks();
    _loadStandalonePins();
    _moveCameraToMyLocation();
    _startEraseStream();
    _startMyLocationMarker(); // 내 위치 보라 dot
  }

  /// 카테고리 색상 변경 시 모든 핀 마커 재생성.
  void _onColorChanged() {
    _rebuildAllMarkers();
  }

  /// 내 위치를 보라색 dot으로 실시간 표시.
  Future<void> _startMyLocationMarker() async {
    try {
      await LocationService.ensurePermission();
    } catch (e) {
      debugPrint('내 위치 마커: 권한 실패 — $e');
      return;
    }

    // 1) 첫 위치 즉시 받기 (positionStream은 사용자가 움직여야 첫 이벤트가
    //    생성될 수 있어 시뮬레이터/실내에서 한참 동안 마커 안 보일 수 있음)
    try {
      final initialPos = await LocationService.currentPosition();
      if (mounted) {
        await _updateMyLocationMarker(initialPos);
      }
    } catch (e) {
      debugPrint('내 위치 마커: 초기 위치 실패 — $e');
    }

    // 2) 이후 스트림으로 실시간 업데이트
    LocationService.positionStream().listen((pos) async {
      if (!mounted) return;
      await _updateMyLocationMarker(pos);
    }, onError: (e) => debugPrint('내 위치 마커: 스트림 에러 — $e'));
  }

  /// 위치 받아 마커 생성/갱신. 첫 위치 + 이후 스트림 모두에서 호출.
  Future<void> _updateMyLocationMarker(Position pos) async {
    _myPosition = pos;
    // 내 위치 전용 마커 — 일반 카테고리 핀과 구별되는 디자인
    // (큰 반투명 외곽 링 + 작은 안쪽 dot).
    final icon = await MarkerBitmapUtil.myLocationMarker(
      AppColors.primary,
      size: 20,
    );
    final marker = Marker(
      markerId: const MarkerId('my_location'),
      position: LatLng(pos.latitude, pos.longitude),
      icon: icon,
      zIndex: 10, // 핀 마커보다 위
      anchor: const Offset(0.5, 0.5),
      flat: false,
      consumeTapEvents: false,
    );
    if (mounted) setState(() => _myLocationMarker = marker);
  }

  /// 일반 핀(runId == null)들을 지도에 표시.
  ///
  /// **v5 신규**: 24시간 추적 도입으로 핀이 독립 엔티티가 되면서
  /// 러닝과 별도로 어디서든 만들 수 있게 됨. 앱 진입 시 모두 로드.
  Future<void> _loadStandalonePins() async {
    final uid = AuthService.currentUser?.uid;
    final rows = await RouteDBService.getAllPinsWithRoute(userId: uid);
    final pins = rows
        .map((r) => Pin.fromMap(r))
        .where((p) => p.runId == null)
        .toList();

    if (!mounted) return;
    for (final pin in pins) {
      await _addPinMarker(pin);
    }
    if (mounted) setState(() {});
  }

  /// 앱 진입 시 사용자 현재 위치로 카메라 이동.
  ///
  /// - mapController가 onMapCreated에서 채워질 때까지 짧은 polling
  /// - 권한이 없으면 조용히 실패 (서울 시청 초기값 유지)
  Future<void> _moveCameraToMyLocation() async {
    try {
      final pos = await LocationService.currentPosition();
      for (int i = 0; i < 20; i++) {
        if (_mapController != null) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (_) {
      // 위치 못 가져와도 앱은 계속 동작
    }
  }

  // ─────────────────────────────────────────────
  // 발자취 (day_tracks)
  // ─────────────────────────────────────────────

  /// 일별 색상 팔레트 — 오늘부터 7일 전까지.
  /// index 0 = 오늘, index 1 = 어제, ...
  // 오늘 → 흰색 진하게, 오래될수록 점점 투명해짐

  /// day_tracks 데이터를 로드해서 _dayTrackPoints에 저장.
  ///
  /// **v5 변경**: 이전엔 polyline을 직접 만들었지만, 이제 스크래치 오버레이가
  /// 발자취 표시를 담당하므로 LatLng 점만 보관. 변환은 카메라 이동 시.
  Future<void> _loadDayTracks() async {
    final uid = AuthService.currentUser?.uid;
    final grouped = await RouteDBService.getDayTrackPoints(
      userId: uid,
      days: 7,
    );

    final newPoints = <String, List<LatLng>>{};
    grouped.forEach((dayId, points) {
      if (points.length < 2) return;
      newPoints[dayId] = [for (final p in points) LatLng(p.lat, p.lng)];
    });

    if (!mounted) return;
    setState(() => _dayTrackPoints = newPoints);

    // 발자취 픽셀 좌표 다시 계산 (스크래치 오버레이용)
    _scheduleRecomputeScreenPoints();
  }

  // ─────────────────────────────────────────────
  // 스크래치 오버레이 — 픽셀 좌표 변환
  // ─────────────────────────────────────────────

  /// GoogleMap의 카메라가 멈췄을 때 호출. 발자취 LatLng를 픽셀로 변환.
  void _onCameraIdle() {
    _scheduleRecomputeScreenPoints();
  }

  /// 카메라 이동 중 즉시 스크래치 오버레이 갱신 (자연스러운 따라오기)
  void _onCameraMove(CameraPosition position) {
    // 샘플링으로 빠르게 변환 → 지연 없이 즉시 실행
    _recomputeTrackScreenPoints();
  }

  /// addPostFrameCallback 기반 1회성 스케줄링.
  /// initState 직후처럼 mapController 아직 null일 때 안전하게.
  void _scheduleRecomputeScreenPoints() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recomputeTrackScreenPoints();
    });
  }

  /// 모든 발자취 LatLng를 픽셀 좌표(Offset)로 변환해 _trackScreenPoints 갱신.
  ///
  /// 변환 비용:
  ///   - getScreenCoordinate는 비동기 + 네이티브 호출
  ///   - 점 1000개 = 약 100-300ms (디바이스 따라)
  ///   - 그래서 디바운스 + 캐싱 중요
  ///
  /// 좌표계 주의:
  ///   - getScreenCoordinate 반환값은 **physical pixels** (devicePixelRatio 곱해진 값)
  ///   - Flutter Canvas는 **logical pixels** 사용
  ///   - 그래서 devicePixelRatio로 나눠줘야 정확히 일치
  Future<void> _recomputeTrackScreenPoints() async {
    final controller = _mapController;
    if (controller == null || !mounted) return;

    final dpr = Platform.isIOS ? 1.0 : MediaQuery.of(context).devicePixelRatio;
    final allPaths = <List<Offset>>[];

    // 점이 많으면 샘플링 — 변환 속도 향상으로 줌/팬 자연스럽게
    List<LatLng> sample(List<LatLng> pts) {
      if (pts.length <= 200) return pts;
      final step = (pts.length / 200).ceil();
      return [
        for (var i = 0; i < pts.length; i += step) pts[i],
        pts.last,
      ];
    }

    // 1. day_tracks 변환
    for (final points in _dayTrackPoints.values) {
      final sampled = sample(points);
      final offsets = <Offset>[];
      for (final latLng in sampled) {
        try {
          final sc = await controller.getScreenCoordinate(latLng);
          offsets.add(Offset(sc.x / dpr, sc.y / dpr));
        } catch (_) {}
      }
      if (offsets.length >= 2) allPaths.add(offsets);
    }

    // 2. 저장된 러닝 경로 변환
    for (final points in _savedRoutePoints.values) {
      final sampled = sample(points);
      final offsets = <Offset>[];
      for (final latLng in sampled) {
        try {
          final sc = await controller.getScreenCoordinate(latLng);
          offsets.add(Offset(sc.x / dpr, sc.y / dpr));
        } catch (_) {}
      }
      if (offsets.length >= 2) allPaths.add(offsets);
    }

    if (mounted) {
      setState(() => _trackScreenPoints = allPaths);
    }
  }

  /// 저장된 모든 완료된 경로를 점 목록으로 로드.
  ///
  /// Polyline을 Set으로 관리하던 방식 대신 _savedRoutePoints(Map)에
  /// 직접 점 목록을 보관 — 내가 지나갈 때 점을 제거해 선이 지워지게.
  Future<void> _loadAllSavedRoutes() async {
    final uid = AuthService.currentUser?.uid;
    final grouped = await RouteDBService.getCompletedRoutePoints(uid);

    if (!mounted) return;
    setState(() {
      _savedRoutePoints.clear();
      grouped.forEach((routeId, points) {
        if (points.length >= 2) {
          _savedRoutePoints[routeId] = [
            for (final p in points) LatLng(p.lat, p.lng),
          ];
        }
      });
    });

    // 스크래치 오버레이용 픽셀 좌표 다시 계산
    _scheduleRecomputeScreenPoints();
  }

  StreamSubscription<Position>? _eraseSub;

  @override
  void dispose() {
    _colorNotifier.removeListener(_onColorChanged);
    _colorNotifier.dispose();
    _posSub?.cancel();
    _eraseSub?.cancel();
    super.dispose();
  }

  /// 모든 핀 마커를 현재 색상으로 재생성 (색상 변경 시 호출).
  Future<void> _rebuildAllMarkers() async {
    final uid = AuthService.currentUser?.uid;
    final rows = await RouteDBService.getAllPinsWithRoute(userId: uid);
    final pins = rows.map((r) => Pin.fromMap(r)).toList();

    _pinMarkers.clear();
    _pinByMarkerId.clear();
    for (final pin in pins) {
      await _addPinMarker(pin);
    }
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // 진행 중 여정 복구
  // ─────────────────────────────────────────────

  Future<void> _restoreActiveRouteIfAny() async {
    final active = await RouteDBService.getActiveRoute();
    if (active == null || !mounted) return;

    final points = await RouteDBService.getPoints(active.id!);
    _path
      ..clear()
      ..addAll(points.map((p) => LatLng(p.lat, p.lng)));
    _updatePolyline();

    setState(() {
      _currentRouteId = active.id;
    });

    await _reloadPins(active.id!);
    await _startLocationStream();
  }

  // ─────────────────────────────────────────────
  // 시작 / 정지
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // 위치 스트림
  // ─────────────────────────────────────────────

  Future<void> _startLocationStream() async {
    await _posSub?.cancel();
    _posSub = LocationService.positionStream().listen(_onPosition);
  }

  /// 앱 실행 중 항상 켜져있는 GPS 스트림 — 내가 지나간 길의 polyline을 지움.
  /// 러닝 중이 아닐 때도 동작. 러닝 스트림(_posSub)과 별개.
  Future<void> _startEraseStream() async {
    try {
      await LocationService.ensurePermission();
    } catch (_) {
      return; // 권한 없으면 조용히 실패
    }
    await _eraseSub?.cancel();
    _eraseSub = LocationService.positionStream().listen(_eraseNearby);
  }

  /// 현재 위치 반경 [_eraseRadiusMeters] 이내의 저장된 경로 점들을 제거.
  void _eraseNearby(Position p) {
    if (_savedRoutePoints.isEmpty) return;

    bool changed = false;
    final toRemove = <int>[]; // 점이 다 지워진 routeId

    for (final entry in _savedRoutePoints.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((pt) {
        final dist = Geolocator.distanceBetween(
          p.latitude,
          p.longitude,
          pt.latitude,
          pt.longitude,
        );
        return dist <= _eraseRadiusMeters;
      });
      if (entry.value.length < before) changed = true;
      if (entry.value.length < 2) toRemove.add(entry.key);
    }

    for (final id in toRemove) {
      _savedRoutePoints.remove(id);
    }

    if (changed && mounted) setState(() {});
  }

  Future<void> _onPosition(Position p) async {
    final routeId = _currentRouteId;
    if (routeId == null) return;

    // GPS 정확도가 25m 이상이면 노이즈로 간주하고 스킵
    if (p.accuracy > 25) return;

    if (_lastPos != null) {
      final delta = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        p.latitude,
        p.longitude,
      );
      // 3m 미만 제자리 떨림, 50m 초과 GPS 점프 — 둘 다 스킵
      if (delta < 3 || delta > 50) return;
    }
    _lastPos = p;

    await RouteDBService.insertPoint(
      routeId: routeId,
      lat: p.latitude,
      lng: p.longitude,
    );

    final latLng = LatLng(p.latitude, p.longitude);
    _path.add(latLng);
    _updatePolyline();
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    if (mounted) setState(() {});
  }

  void _updatePolyline() {
    _currentPolyline = Polyline(
      polylineId: const PolylineId('current_path'),
      points: List.unmodifiable(_path),
      color: AppColors.primary.withValues(alpha: 0.8),
      width: 12,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      jointType: JointType.round,
    );
  }

  // ─────────────────────────────────────────────
  // 핀 (사진 + 메모) — 추가 / 로드 / 삭제
  // ─────────────────────────────────────────────

  /// 지도를 길게 누르면 호출. SaveFilesScreen으로 이동해서 사진/메모를 받아옴.
  ///
  /// **MVP v5**: 일반 핀(runId == null)으로 추가. 더 이상 자동 여정 시작 안 함.
  /// 러닝 기능은 별도 진입점 (RouteListScreen 또는 추후 러닝 전용 화면).
  Future<void> _onMapLongPress(LatLng position) async {
    final result = await Navigator.push<Pin?>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveFilesScreen(
          lat: position.latitude,
          lng: position.longitude,
          colorNotifier: _colorNotifier,
        ),
      ),
    );

    if (result != null && mounted) {
      await _addPinMarker(result);
      setState(() {});
      CloudSyncService.syncPinAdded(result);
      _showSnack('핀이 추가되었어요 📍');
    }
  }

  Future<void> _reloadPins(int routeId) async {
    final pins = await RouteDBService.getPins(routeId);
    _pinMarkers.clear();
    _pinByMarkerId.clear();
    for (final pin in pins) {
      await _addPinMarker(pin);
    }
    if (mounted) setState(() {});
  }

  Future<void> _addPinMarker(Pin pin) async {
    final color = _colorNotifier.colorOf(pin.category);
    // 사이즈 28 — 이전 44는 dpr 3.0 곱해서 132px 이미지로 너무 컸음.
    final icon = await MarkerBitmapUtil.dotMarker(color, size: 12);
    final markerId = MarkerId('pin_${pin.id}');
    _pinByMarkerId[markerId.value] = pin;
    _pinMarkers.add(
      Marker(
        markerId: markerId,
        position: LatLng(pin.lat, pin.lng),
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () => _showPinPreview(pin),
      ),
    );
  }

  void _showPinPreview(Pin pin) {
    PinPreviewSheet.show(context, pin: pin, onDelete: () => _deletePin(pin));
  }

  Future<void> _deletePin(Pin pin) async {
    if (pin.id == null) return;

    // 러닝에 속한 핀이면 그 러닝 정보도 가져와 동기화에 사용
    final run = pin.runId == null
        ? null
        : await RouteDBService.getRoute(pin.runId!);

    await RouteDBService.deletePin(pin.id!);
    if (pin.photoPath != null) {
      await PhotoStorage.delete(pin.photoPath!);
    }

    // 클라우드 동기화 트리거
    if (pin.runId == null) {
      // **v5 신규**: 일반 핀 삭제 — runId 없음을 알리는 빈 routeUuid
      CloudSyncService.syncPinDeleted(
        pinUuid: pin.uuid,
        routeUuid: '', // 빈 문자열 = 일반 핀 신호
        photoStoragePath: pin.photoStoragePath,
      );
    } else if (run != null && !run.isActive) {
      // 종료된 러닝의 핀 — 즉시 동기화
      // (진행 중 러닝은 종료 시 한 번에 동기화되므로 여기서는 안 함)
      CloudSyncService.syncPinDeleted(
        pinUuid: pin.uuid,
        routeUuid: run.uuid,
        photoStoragePath: pin.photoStoragePath,
      );
    }

    final markerId = 'pin_${pin.id}';
    _pinMarkers.removeWhere((m) => m.markerId.value == markerId);
    _pinByMarkerId.remove(markerId);
    if (mounted) {
      setState(() {});
      _showSnack('핀을 삭제했어요');
    }
  }

  // ─────────────────────────────────────────────
  // 바텀 네비
  // ─────────────────────────────────────────────

  /// 0=지도(현재 화면 유지), 1=타임라인, 2=프로필.
  /// 다른 탭으로 가도 메인으로 돌아오면 인덱스를 0으로 리셋해
  /// "지도"가 항상 현재 활성 탭으로 보이게 함.
  Future<void> _onBottomNavChanged(int i) async {
    if (i == 0) return; // 이미 지도 화면

    setState(() => _bottomNavIndex = i);

    if (i == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TimelineScreen()),
      );
    } else if (i == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    }

    if (mounted) setState(() => _bottomNavIndex = 0);
  }

  // ─────────────────────────────────────────────
  // 헬퍼
  // ─────────────────────────────────────────────

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.gray900,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          // ── 지도 ──
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (c) => _mapController = c,
              onLongPress: _onMapLongPress,
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
              myLocationEnabled: false, // 보라 커스텀 dot으로 대체
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              polylines: _polylines,
              markers: _allMarkers,
              padding: const EdgeInsets.only(bottom: 220),
            ),
          ),

          // ── 지도 위 보라 톤 오버레이 (스크래치 효과) ──
          // 발자취 경로 부분만 보라가 벗겨져 원래 지도가 비침.
          // CustomPainter + BlendMode.dstOut으로 마스킹.
          //
          // 한계: 줌/팬 중에는 0.1초 정도 발자취 위치 어긋날 수 있음
          //       (onCameraIdle에서 보정).
          ScratchOverlay(
            trackScreenPoints: _trackScreenPoints,
            strokeWidth: 36,
            overlayAlpha: 0.30,
          ),

          // ── 우상단: 액션 버튼들 ──
          // v5 변경: REC 버튼 제거 — 길게 누르면 즉시 핀 추가, 별도 기록 없음.
          // Week 7: 러닝 시작 버튼 추가
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Column(
              children: [
                // 러닝 시작 버튼 (primary 색, 강조)
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () async {
                      // 러닝 라이브 화면으로 push.
                      // 사용자가 종료하면 → Result 화면으로 pushReplacement
                      // → Result에서 닫기/확인 누르면 → 이 자리(HomeScreen)로 pop
                      // 그래서 await는 Result 화면 pop 시점에 풀림.
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RunningLiveScreen(),
                        ),
                      );
                      // 경로 + 핀 새로고침
                      if (mounted) {
                        await _loadAllSavedRoutes();
                        await _loadStandalonePins();
                      }
                    },
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.directions_run_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _CircleIconButton(
                  icon: Icons.list_alt_rounded,
                  iconColor: context.textPrimary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RouteListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _CircleIconButton(
                  icon: Icons.palette_outlined,
                  iconColor: context.textPrimary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CategoryColorScreen(notifier: _colorNotifier),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // AI 장소 추천
                _CircleIconButton(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlaceInputScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── 우하단: 내 위치 버튼 (네비바 위에 배치) ──
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 100,
            child: _CircleIconButton(
              icon: Icons.my_location_rounded,
              iconColor: AppColors.primary,
              onPressed: () async {
                try {
                  final pos = await LocationService.currentPosition();
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(pos.latitude, pos.longitude),
                      16,
                    ),
                  );
                } catch (_) {
                  if (mounted) {
                    _showSnack('위치를 찾을 수 없어요', isError: true);
                  }
                }
              },
            ),
          ),

          // ── 하단: 네비게이션만 (Picture/Memo 토글 제거) ──
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: _BottomNavBar(
                currentIndex: _bottomNavIndex,
                onChanged: _onBottomNavChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomNavBar({required this.currentIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          _navItem(context, 0, Icons.map_rounded, '지도'),
          _navItem(context, 1, Icons.auto_awesome_rounded, '타임라인'),
          _navItem(context, 2, Icons.person_rounded, '프로필'),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = currentIndex == index;
    final inactiveColor = context.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(index),
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : inactiveColor,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.primary : inactiveColor,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
