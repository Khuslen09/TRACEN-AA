import 'package:flutter/foundation.dart' show ValueListenable, kDebugMode;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../theme/app_colors.dart';
import '../tracking_state.dart';

/// 지도 패널 — [mapStateListenable]만 구독해서, 지표 패널이 1초마다
/// 갱신돼도 이 위젯의 build()는 영향받지 않는다(부모가 각자 다른
/// ValueNotifier를 따로 내려주는 구조 — MockTrackingController 참고).
///
/// 데이터(위치/경로)는 받는 즉시 polyline/marker에 반영하되, 실제 카메라
/// 이동(`animateCamera`)만 내부적으로 2.5초 스로틀링한다 — 예전에 있었다는
/// "카메라 이동 너무 잦아서 크래시" 문제의 재발을 막기 위함. 이 스로틀
/// 로직은 실제 GPS 연동 때도 그대로 재사용 가능하도록 데이터 소스와
/// 독립적으로 작성됨.
class TrackingMapPanel extends StatefulWidget {
  final ValueNotifier<TrackingMapState> mapStateListenable;

  /// 컨트롤 바 높이 + safe area bottom — GoogleMap의 padding으로 그대로
  /// 전달해서 내 위치 마커/버튼/Google 로고가 컨트롤 바에 안 가리게 함.
  final double bottomPadding;

  /// 디버그 빌드 전용 — 원본 GPS 진단 오버레이. null이면(예: mock 컨트롤러)
  /// 그냥 안 그림.
  final ValueListenable<DebugGpsSnapshot?>? debugInfoListenable;

  /// iOS "정확한 위치" 상태. reduced면 배너로 안내.
  final ValueListenable<LocationAccuracyStatus?>? accuracyStatusListenable;
  final VoidCallback? onRequestFullAccuracy;

  const TrackingMapPanel({
    super.key,
    required this.mapStateListenable,
    required this.bottomPadding,
    this.debugInfoListenable,
    this.accuracyStatusListenable,
    this.onRequestFullAccuracy,
  });

  @override
  State<TrackingMapPanel> createState() => _TrackingMapPanelState();
}

class _TrackingMapPanelState extends State<TrackingMapPanel> {
  static const _cameraThrottle = Duration(milliseconds: 2500);

  GoogleMapController? _controller;
  bool _followMe = true;
  DateTime? _lastCameraMove;

  /// animateCamera 자체도 onCameraMoveStarted를 유발하므로, 우리가 유발한
  /// 이동인지 사용자가 직접 움직인 건지 구분해야 팔로우가 즉시 스스로
  /// 꺼지는 걸 막을 수 있다.
  bool _programmaticMove = false;

  @override
  void initState() {
    super.initState();
    widget.mapStateListenable.addListener(_onMapStateChanged);
  }

  @override
  void dispose() {
    widget.mapStateListenable.removeListener(_onMapStateChanged);
    super.dispose();
  }

  void _onMapStateChanged() {
    final position = widget.mapStateListenable.value.position;
    if (position != null) _maybeMoveCamera(position);
  }

  Future<void> _maybeMoveCamera(LatLng pos) async {
    if (!_followMe) return;
    final now = DateTime.now();
    final last = _lastCameraMove;
    if (last != null && now.difference(last) < _cameraThrottle) return;
    _lastCameraMove = now;

    _programmaticMove = true;
    await _controller?.animateCamera(CameraUpdate.newLatLng(pos));
    _programmaticMove = false;
  }

  void _onCameraMoveStarted() {
    if (_programmaticMove) return; // 우리가 유발한 이동 — 팔로우 유지
    if (_followMe) setState(() => _followMe = false);
  }

  Future<void> _onRecenterPressed() async {
    final position = widget.mapStateListenable.value.position;
    if (position == null) return;
    setState(() => _followMe = true);
    _lastCameraMove = DateTime.now();
    _programmaticMove = true;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 17),
    );
    _programmaticMove = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<TrackingMapState>(
                valueListenable: widget.mapStateListenable,
                builder: (context, mapState, _) {
                  final position = mapState.position;
                  if (position == null) {
                    return const _MapLoadingPlaceholder();
                  }
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: position,
                      zoom: 17,
                    ),
                    onMapCreated: (c) => _controller = c,
                    onCameraMoveStarted: _onCameraMoveStarted,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    padding: EdgeInsets.only(bottom: widget.bottomPadding),
                    polylines: {
                      if (mapState.path.length >= 2)
                        Polyline(
                          polylineId: const PolylineId('live_mock'),
                          points: mapState.path,
                          color: AppColors.primary,
                          width: 6,
                          startCap: Cap.roundCap,
                          endCap: Cap.roundCap,
                          jointType: JointType.round,
                        ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('current'),
                        position: position,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueViolet,
                        ),
                        anchor: const Offset(0.5, 0.5),
                        flat: true,
                      ),
                    },
                  );
                },
              ),
            ),
            if (!_followMe)
              Positioned(
                right: 16,
                bottom: widget.bottomPadding + 16,
                child: _RecenterButton(
                  label: l10n.trackingBackToCurrentLocation,
                  onPressed: _onRecenterPressed,
                ),
              ),
            if (widget.accuracyStatusListenable != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: ValueListenableBuilder<LocationAccuracyStatus?>(
                  valueListenable: widget.accuracyStatusListenable!,
                  builder: (context, status, _) {
                    if (status != LocationAccuracyStatus.reduced) {
                      return const SizedBox.shrink();
                    }
                    return _PreciseLocationBanner(
                      onRequestFullAccuracy: widget.onRequestFullAccuracy,
                    );
                  },
                ),
              ),
            if (kDebugMode && widget.debugInfoListenable != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: ValueListenableBuilder<DebugGpsSnapshot?>(
                  valueListenable: widget.debugInfoListenable!,
                  builder: (context, info, _) => _DebugGpsOverlay(info: info),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapLoadingPlaceholder extends StatelessWidget {
  const _MapLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              l10n.trackingLocatingGps,
              style: const TextStyle(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreciseLocationBanner extends StatelessWidget {
  final VoidCallback? onRequestFullAccuracy;
  const _PreciseLocationBanner({this.onRequestFullAccuracy});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.gps_not_fixed_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.trackingPreciseLocationOff,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (onRequestFullAccuracy != null)
              TextButton(
                onPressed: onRequestFullAccuracy,
                child: Text(
                  l10n.trackingPreciseLocationTurnOn,
                  style: const TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DebugGpsOverlay extends StatelessWidget {
  final DebugGpsSnapshot? info;
  const _DebugGpsOverlay({required this.info});

  @override
  Widget build(BuildContext context) {
    final i = info;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 10,
          fontFamily: 'monospace',
          height: 1.3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: i == null
              ? const [Text('GPS: waiting for fix…')]
              : [
                  Text(
                    'lat ${i.lat?.toStringAsFixed(6)}  lng ${i.lng?.toStringAsFixed(6)}',
                  ),
                  Text(
                    'acc ${i.accuracyMeters?.toStringAsFixed(1)}m  '
                    '${i.passedAccuracyFilter ? "PASS" : "FILTERED"}',
                  ),
                  Text('ts ${i.timestamp?.toIso8601String() ?? "-"}'),
                  Text(
                    'perm ${i.permission?.name ?? "?"}  '
                    'precise ${i.accuracyStatus?.name ?? "?"}',
                  ),
                ],
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _RecenterButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Tooltip(
            message: label,
            child: const Icon(
              Icons.my_location_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
