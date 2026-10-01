import '../../l10n/strings.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/pin.dart';
import '../../models/route.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/photo_storage.dart';
import '../../services/route_db_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import 'widgets/pin_preview_sheet.dart';

/// 단일 여정의 상세 지도 화면.
///
/// 동작:
///   1. 진입 시 DB에서 점들 + 핀들 동시 로드
///   2. Polyline + 마커 그리기
///   3. 카메라를 경로 전체가 화면에 들어오게 자동 fit
///   4. 상단 카드: 제목 + 거리 + 시간 + 핀 수
///   5. 마커 탭 → 핀 미리보기 (HomeScreen과 동일한 시트)
class RouteMapScreen extends StatefulWidget {
  final TraceRoute route;
  const RouteMapScreen({super.key, required this.route});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  GoogleMapController? _mapController;

  List<LatLng> _points = [];
  List<Pin> _pins = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routeId = widget.route.id;
    if (routeId == null) {
      setState(() {
        _loading = false;
        _error = l10n.invalidRoute;
      });
      return;
    }

    try {
      final pointsFuture = RouteDBService.getPoints(routeId);
      final pinsFuture = RouteDBService.getPins(routeId);
      final routePoints = await pointsFuture;
      final pins = await pinsFuture;

      _points = [for (final p in routePoints) LatLng(p.lat, p.lng)];
      _pins = pins;

      _polylines = _points.length < 2
          ? {}
          : {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _points,
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 5,
              ),
            };

      _markers = {
        for (final pin in _pins)
          Marker(
            markerId: MarkerId('pin_${pin.id}'),
            position: LatLng(pin.lat, pin.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(pin.category.markerHue),
            onTap: () => _showPinPreview(pin),
          ),
      };

      if (mounted) {
        setState(() => _loading = false);
        // 다음 프레임에 fit (mapController 준비 보장)
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l10n.routeLoadFailed;
        });
      }
    }
  }

  /// 모든 점이 화면에 보이도록 카메라 위치/줌 조정.
  void _fitCamera() {
    final controller = _mapController;
    if (controller == null) return;

    final all = [..._points, for (final p in _pins) LatLng(p.lat, p.lng)];
    if (all.isEmpty) return;

    if (all.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(all.first, 16));
      return;
    }

    double minLat = all.first.latitude, maxLat = all.first.latitude;
    double minLng = all.first.longitude, maxLng = all.first.longitude;
    for (final p in all) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64, // 가장자리 패딩
      ),
    );
  }

  void _showPinPreview(Pin pin) {
    PinPreviewSheet.show(context, pin: pin, onDelete: () => _deletePin(pin));
  }

  Future<void> _deletePin(Pin pin) async {
    if (pin.id == null) return;
    await RouteDBService.deletePin(pin.id!);
    if (pin.photoPath != null) {
      await PhotoStorage.delete(pin.photoPath!);
    }
    // 이 화면은 종료된 여정만 보여주므로 항상 동기화
    CloudSyncService.syncPinDeleted(
      pinUuid: pin.uuid,
      routeUuid: widget.route.uuid,
      photoStoragePath: pin.photoStoragePath,
    );
    setState(() {
      _pins.removeWhere((p) => p.id == pin.id);
      _markers.removeWhere((m) => m.markerId.value == 'pin_${pin.id}');
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pinDeleted)));
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initialCamera = _points.isNotEmpty
        ? CameraPosition(target: _points.first, zoom: 14)
        : const CameraPosition(target: LatLng(37.5665, 126.9780), zoom: 14);

    return Scaffold(
      backgroundColor: context.bgColor,
      // 지도 위에 떠있는 투명 AppBar — 뒤로가기/제목만
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: context.cardColor,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.sm,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 지도
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: initialCamera,
              onMapCreated: (c) {
                _mapController = c;
                if (!_loading) _fitCamera();
              },
              polylines: _polylines,
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              padding: const EdgeInsets.only(top: 100, bottom: 24),
            ),
          ),

          // 로딩
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x80FFFFFF),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

          // 에러
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(_error!, style: AppTextStyles.body),
              ),
            ),

          // 하단 정보 카드
          if (!_loading && _error == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: _RouteInfoCard(
                route: widget.route,
                pinCount: _pins.length,
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Route info card
// ──────────────────────────────────────────────────────────────

class _RouteInfoCard extends StatelessWidget {
  final TraceRoute route;
  final int pinCount;

  const _RouteInfoCard({required this.route, required this.pinCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateText = '${DateFormat.yMd(Strings.current.localeName).format(route.startedAt)} · '
        '${DateFormat.jm(Strings.current.localeName).format(route.startedAt)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(route.title, style: AppTextStyles.h3),
                    const SizedBox(height: 4),
                    Text(dateText, style: AppTextStyles.small),
                  ],
                ),
              ),
              if (route.isActive)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    l10n.runInProgress,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              _StatCell(
                icon: Icons.straighten_rounded,
                label: l10n.runDistance,
                value: _formatDistance(route.distance),
              ),
              _Divider(),
              _StatCell(
                icon: Icons.schedule_rounded,
                label: l10n.runTime,
                value: _formatDuration(route.duration),
              ),
              _Divider(),
              _StatCell(
                icon: Icons.place_rounded,
                label: l10n.statPins,
                value: l10n.pinCountValue(pinCount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${d.inSeconds}s';
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.bodyBold),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}
