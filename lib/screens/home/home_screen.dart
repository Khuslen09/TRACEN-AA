import '../../l10n/generated/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

import '../../l10n/strings.dart';
import '../../models/pin.dart';
import '../../models/route.dart';
import '../../services/auth_service.dart';
import '../../services/category_color_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/photo_storage.dart';
import '../../services/pin_place_lookup_service.dart';
import '../../services/route_db_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/marker_bitmap_util.dart';
import 'widgets/purple_map_style.dart';
import 'widgets/scratch_tile_provider.dart';
import '../profile/profile_screen.dart';
import '../run/activity_result_screen.dart';
import '../run/tracking/activity_tracking_screen.dart';
import '../save_files_screen.dart';
import 'place_input_screen.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  AppLocalizations get l10n => AppLocalizations.of(context);

  // ─── 지도 / 위치 ───
  GoogleMapController? _mapController;

  // ─── 카테고리 색상 ───
  final CategoryColorNotifier _colorNotifier = CategoryColorNotifier.instance;

  // ─── 내 위치 커스텀 마커 ───
  Marker? _myLocationMarker;

  /// 저장된 경로 점들 — routeId → 점 목록.
  /// 스크래치 오버레이가 발자취 표시를 담당하므로 polyline 직접 안 그림.
  final Map<int, List<LatLng>> _savedRoutePoints = {};

  /// 지우기 반경 (m): 현재 위치에서 이 거리 이내 점은 제거.
  static const double _eraseRadiusMeters = 15.0;

  /// day_tracks 기반 발자취 — dayId → LatLng 리스트.
  /// **이전엔 polyline으로 그렸지만, v5에서 스크래치 오버레이로 변경**.
  Map<String, List<LatLng>> _dayTrackPoints = {};

  /// 발자취 스크래치 효과를 지도 타일 자체로 그려주는 프로바이더.
  /// 화면 레이어가 아니라 지도 렌더링 파이프라인 안에서 그려지므로
  /// 팬/줌/회전 중에도 지도와 어긋날 수 없음 ([ScratchTileProvider] 참고).
  final ScratchTileProvider _scratchTileProvider = ScratchTileProvider();
  static const _scratchTileOverlayId = TileOverlayId('scratch');

  Set<Marker> get _allMarkers {
    final markers = <Marker>{..._pinMarkers};
    if (_myLocationMarker != null) markers.add(_myLocationMarker!);
    return markers;
  }

  final Set<Marker> _pinMarkers = {};
  final Map<String, Pin> _pinByMarkerId = {}; // markerId → Pin 역참조

  // ─── UI 토글 ───
  int _bottomNavIndex = 0;

  static const _initialPosition = CameraPosition(
    target: LatLng(37.5665, 126.9780),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    // 저장된 색상은 main에서 이미 로드됨 — 앱 공용 인스턴스라 여기선 구독만.
    _colorNotifier.addListener(_onColorChanged);
    _restoreActiveRouteIfAny();
    _loadAllSavedRoutes();
    _loadDayTracks();
    _dayTrackRefresh = Timer.periodic(
      _dayTrackRefreshInterval,
      (_) => _loadDayTracks(),
    );
    WidgetsBinding.instance.addObserver(this);
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
      zIndexInt: 10, // 핀 마커보다 위
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

  /// 백그라운드 추적이 day_tracks에 계속 점을 쌓으므로, 앱을 켜둔 채로도
  /// 오늘 간 길이 지도에 나타나도록 주기적으로 다시 읽는다 — 예전엔
  /// initState에서 한 번만 읽어 다음 날 앱을 다시 열어야 보였다.
  static const _dayTrackRefreshInterval = Duration(minutes: 5);
  Timer? _dayTrackRefresh;

  /// 백그라운드에선 타이머가 멈추므로(iOS) 돌아오는 즉시 한 번 갱신.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadDayTracks();
  }

  /// day_tracks 데이터를 로드해서 _dayTrackPoints에 저장.
  /// 기간 제한 없이 기기에 설치된 이후 기록된 전체 발자취를 표시.
  ///
  /// **v5 변경**: 이전엔 polyline을 직접 만들었지만, 이제 스크래치 오버레이가
  /// 발자취 표시를 담당하므로 LatLng 점만 보관. 변환은 카메라 이동 시.
  Future<void> _loadDayTracks() async {
    final uid = AuthService.currentUser?.uid;
    final grouped = await RouteDBService.getDayTrackPoints(userId: uid);

    final newPoints = <String, List<LatLng>>{};
    grouped.forEach((dayId, points) {
      if (points.length < 2) return;
      newPoints[dayId] = [for (final p in points) LatLng(p.lat, p.lng)];
    });

    if (!mounted) return;
    setState(() => _dayTrackPoints = newPoints);
    _rebuildScratchTiles();
  }

  /// 발자취(day_tracks + 저장된 경로) 데이터가 바뀔 때마다 호출.
  /// 타일 프로바이더에 최신 경로를 넘기고, 이미 그려둔 타일 캐시를 지워서
  /// 지도가 다음에 그 타일을 다시 요청하게 만든다.
  void _rebuildScratchTiles() {
    _scratchTileProvider.updatePaths([
      ..._dayTrackPoints.values,
      ..._savedRoutePoints.values,
    ]);
    _mapController?.clearTileCache(_scratchTileOverlayId);
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

    _rebuildScratchTiles();
  }

  StreamSubscription<Position>? _eraseSub;

  @override
  void dispose() {
    _colorNotifier.removeListener(_onColorChanged);
    _eraseSub?.cancel();
    _dayTrackRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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

  /// 진행 중('recording') 또는 저장 대기 중('pending_review')인 route가
  /// 있으면 복구한다 — **조용히 백그라운드에서 이어 기록하지 않는다.**
  /// recording이면 기록 화면을 열어 [ActivityRecorder]가 이어받게 하고,
  /// pending_review면 결과 화면을 다시 열어 저장/버리기를 고르게 한다.
  Future<void> _restoreActiveRouteIfAny() async {
    final resumable = await RouteDBService.getResumableRoute();
    if (resumable == null || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => resumable.status == RouteStatus.recording
              ? ActivityTrackingScreen(
                  activityType: resumable.activityType,
                  resumeRouteId: resumable.id,
                )
              : ActivityResultScreen(routeId: resumable.id!),
        ),
      );
      if (mounted) {
        await _loadAllSavedRoutes();
        await _loadStandalonePins();
      }
    });
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

    if (changed && mounted) {
      setState(() {});
      _rebuildScratchTiles();
    }
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
      unawaited(
        PinPlaceLookupService.resolveAndPersist(
          result,
          languageCode: Strings.current.localeName,
        ),
      );
      _showSnack(l10n.pinAdded);
    }
  }

  Future<void> _addPinMarker(Pin pin) async {
    final color = _colorNotifier.colorOf(pin.category);
    final categoryIcon = _colorNotifier.iconOf(pin.category);
    final icon = await MarkerBitmapUtil.categoryMarker(
      categoryIcon,
      color,
      size: 12,
    );
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
    PinPreviewSheet.show(
      context,
      pin: pin,
      onDelete: () => _deletePin(pin),
      onEdited: _onPinEdited,
    );
  }

  /// 핀 수정 후 — 마커를 새 카테고리 색/내용으로 교체.
  Future<void> _onPinEdited(Pin updated) async {
    final markerId = 'pin_${updated.id}';
    _pinMarkers.removeWhere((m) => m.markerId.value == markerId);
    _pinByMarkerId.remove(markerId);
    await _addPinMarker(updated);
    if (mounted) setState(() {});
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
      _showSnack(l10n.pinDeleted);
    }
  }

  // ─────────────────────────────────────────────
  // 바텀 네비
  // ─────────────────────────────────────────────

  /// 0=지도(현재 화면 유지), 1=타임라인, 2=프로필.
  /// 다른 탭으로 가도 메인으로 돌아오면 인덱스를 0으로 리셋해
  /// l10n.navMap가 항상 현재 활성 탭으로 보이게 함.
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
              style: purpleMapStyle,
              onMapCreated: (c) {
                _mapController = c;
                // 지도가 준비된 뒤에야 타일을 요청하므로, 이미 로드돼있던
                // 발자취가 있으면 그제서야 처음으로 타일 캐시를 채운다.
                _rebuildScratchTiles();
              },
              onLongPress: _onMapLongPress,
              myLocationEnabled: false, // 보라 커스텀 dot으로 대체
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              // 발자취 스크래치 효과를 타일로 직접 그리므로(ScratchTileProvider),
              // 회전·기울임 중에도 지도 SDK가 알아서 같이 그려준다 — 더 이상
              // "북쪽이 항상 위"라는 가정이 필요 없어 제스처를 다시 켜둠.
              markers: _allMarkers,
              tileOverlays: {
                TileOverlay(
                  tileOverlayId: _scratchTileOverlayId,
                  tileProvider: _scratchTileProvider,
                  // 빠르게 스크롤해서 새 영역의 타일을 처음 그릴 때 뚝
                  // 끊기듯 나타나는 게 더 거슬려서 켜둠 — 네이티브 지도가
                  // 새 타일을 부드럽게 크로스페이드시켜준다.
                  fadeIn: true,
                ),
              },
              padding: const EdgeInsets.only(bottom: 220),
            ),
          ),

          // ── 우상단: 액션 버튼들 ──
          // v5 변경: REC 버튼 제거 — 길게 누르면 즉시 핀 추가, 별도 기록 없음.
          // Week 7: 러닝 시작 버튼 추가
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            // 가로모드에서는 카메라 노치가 좌우 중 한쪽에 생기므로, 세로모드에서
            // 항상 0인 padding.right도 같이 더해야 버튼이 거기 가려지지 않음.
            right: MediaQuery.of(context).padding.right + 16,
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
                      // 활동 선택(러닝/걷기/자전거)은 기록 화면의 시작
                      // 대기 상태에서 — 마지막 선택을 기억해 기본값으로.
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActivityTrackingScreen(),
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
                // AI 장소 추천
                _CircleIconButton(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.primary,
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlaceInputScreen(),
                      ),
                    );
                    // AI 추천 결과에서 "핀으로 저장"한 장소를 지도에 반영
                    if (mounted) _rebuildAllMarkers();
                  },
                ),
              ],
            ),
          ),

          // ── 우하단: 내 위치 버튼 (네비바 위에 배치) ──
          Positioned(
            right: MediaQuery.of(context).padding.right + 16,
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
                    _showSnack(l10n.locationNotFound, isError: true);
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
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.md,
      ),
      child: Row(
        children: [
          _navItem(context, 0, Icons.map_rounded, l10n.navMap),
          _navItem(context, 1, Icons.photo_library_rounded, l10n.navTimeline),
          _navItem(context, 2, Icons.person_rounded, l10n.navProfile),
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
