import '../../l10n/generated/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/pin.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/location_service.dart';
import '../../services/route_db_service.dart';
import '../../services/run_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../save_files_screen.dart';
import 'running_result_screen.dart';

enum _RunState { ready, starting, running }

class RunningLiveScreen extends StatefulWidget {
  const RunningLiveScreen({super.key});

  @override
  State<RunningLiveScreen> createState() => _RunningLiveScreenState();
}

class _RunningLiveScreenState extends State<RunningLiveScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posSub;
  Timer? _ticker;
  Timer? _followResumeTimer;
  bool _followMe = true;

  int? _runId;
  DateTime? _startedAt;
  final List<LatLng> _path = [];
  final List<({DateTime time, LatLng pos})> _recentPositions = [];

  Position? _lastPos;
  double _distanceMeters = 0.0;
  Duration _elapsed = Duration.zero;
  double _currentPaceSecondsPerKm = 0;

  _RunState _state = _RunState.ready;

  @override
  void dispose() {
    _posSub?.cancel();
    _ticker?.cancel();
    _followResumeTimer?.cancel();
    super.dispose();
  }

  Future<void> _onStartPressed() async {
    setState(() => _state = _RunState.starting);
    try {
      await LocationService.ensurePermission();
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.runLocationPermissionNeeded, isError: true);
      setState(() => _state = _RunState.ready);
      return;
    }

    final id = await RouteDBService.startRoute(
      userId: AuthService.currentUser?.uid,
    );
    if (!mounted) return;

    setState(() {
      _runId = id;
      _startedAt = DateTime.now();
      _state = _RunState.running;
    });

    _posSub = LocationService.positionStream().listen(_onPosition);

    // 시작 즉시 현재 위치로 카메라 이동
    _moveToCurrentLocation();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _startedAt == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startedAt!);
        _currentPaceSecondsPerKm = _calcCurrentPace();
      });
    });
  }

  /// 현재 페이스: 최근 30초 구간 기반 (더 실시간).
  /// 데이터 부족 시 전체 평균으로 fallback.
  double _calcCurrentPace() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 30));
    final recent = _recentPositions
        .where((r) => r.time.isAfter(cutoff))
        .toList();

    if (recent.length >= 2) {
      double recentDist = 0;
      for (int i = 1; i < recent.length; i++) {
        recentDist += RunMetrics.haversineMeters(
          recent[i - 1].pos.latitude,
          recent[i - 1].pos.longitude,
          recent[i].pos.latitude,
          recent[i].pos.longitude,
        );
      }
      final recentSecs = now.difference(recent.first.time).inSeconds;
      if (recentDist >= 10 && recentSecs > 0) {
        return recentSecs / (recentDist / 1000.0);
      }
    }

    return RunMetrics.averagePaceSecondsPerKm(
      distanceMeters: _distanceMeters,
      elapsed: _elapsed,
    );
  }

  Future<void> _onPosition(Position p) async {
    if (_runId == null) return;

    // GPS 정확도가 25m 이상이면 노이즈로 간주하고 스킵
    if (p.accuracy > 25) return;

    if (_lastPos != null) {
      final delta = RunMetrics.haversineMeters(
        _lastPos!.latitude,
        _lastPos!.longitude,
        p.latitude,
        p.longitude,
      );
      // 3m 미만은 제자리 떨림, 50m 초과는 GPS 점프 — 둘 다 스킵
      if (delta < 3 || delta > 50) return;
      _distanceMeters += delta;
    }
    _lastPos = p;

    await RouteDBService.insertPoint(
      routeId: _runId!,
      lat: p.latitude,
      lng: p.longitude,
    );

    final latLng = LatLng(p.latitude, p.longitude);
    _path.add(latLng);

    _recentPositions.add((time: DateTime.now(), pos: latLng));
    final oldCutoff = DateTime.now().subtract(const Duration(minutes: 3));
    _recentPositions.removeWhere((r) => r.time.isBefore(oldCutoff));

    if (_followMe) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
    }
    if (mounted) setState(() {});
  }

  /// 사용자가 손으로 지도를 조작하면 자동 팔로우를 잠깐 해제.
  /// 5초 뒤 다시 자동으로 현재 위치를 따라가도록 복귀.
  void _onCameraMoveStarted() {
    _followMe = false;
    _followResumeTimer?.cancel();
    _followResumeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _followMe = true);
    });
  }

  /// 앱 시작 시 현재 GPS 위치로 카메라 이동.
  Future<void> _moveToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 17),
        ),
      );
    } catch (_) {
      // 위치 못 받으면 그냥 기본 위치 유지
    }
  }

  Future<void> _stopRun() async {
    final id = _runId;
    if (id == null) return;

    final confirmed = await _confirmStop();
    if (confirmed != true) return;

    await _posSub?.cancel();
    _ticker?.cancel();

    await RouteDBService.endRoute(id, distance: _distanceMeters);
    CloudSyncService.syncRouteCompleted(id);

    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RunningResultScreen(runId: id)),
    );
  }

  Future<bool?> _confirmStop() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(l10n.runEndTitle, style: AppTextStyles.h3),
        content: Text(
          l10n.runEndBody(RunMetrics.formatDistanceKmBig(_distanceMeters)),
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.runContinue),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.runEnd),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapLongPress(LatLng position) async {
    if (_runId == null) return;
    final pin = await Navigator.push<Pin?>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveFilesScreen(
          runId: _runId,
          lat: position.latitude,
          lng: position.longitude,
        ),
      ),
    );
    if (pin != null && mounted) _showSnack(l10n.pinAdded);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.gray900,
      ),
    );
  }

  /// 지나간 길 fade 효과.
  ///
  /// 전략: 경로를 4구간으로 균등 분할.
  ///   - 구간 3 (가장 최근) → alpha 1.0  진함
  ///   - 구간 2             → alpha 0.55
  ///   - 구간 1             → alpha 0.25
  ///   - 구간 0 (가장 오래) → alpha 0.08  거의 투명
  ///
  /// 점이 4개 미만이면 단일 polyline으로 표시.
  /// distanceFilter=5m 기준 → 점 4개 = 약 20m 이동 시부터 fade 시작.
  Set<Polyline> _buildFadedPolylines() {
    if (_path.length < 2) return {};

    // 점이 적을 때는 그냥 하나로
    if (_path.length < 4) {
      return {
        Polyline(
          polylineId: const PolylineId('live_single'),
          points: List.unmodifiable(_path),
          color: AppColors.primary,
          width: 12,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    }

    const segCount = 4;
    // alpha: 오래된 순 → 최근 순 (index 0이 가장 오래됨)
    const alphas = [0.08, 0.25, 0.55, 1.0];

    final polylines = <Polyline>{};
    final total = _path.length;
    final segSize = (total / segCount).ceil();

    for (int s = 0; s < segCount; s++) {
      final start = s * segSize;
      if (start >= total - 1) break;
      // 다음 구간과 1점 겹쳐서 끊김 없이 이어지게
      final end = ((s + 1) * segSize + 1).clamp(0, total);
      final pts = _path.sublist(start, end);
      if (pts.length < 2) continue;

      polylines.add(
        Polyline(
          polylineId: PolylineId('live_seg_$s'),
          points: List.unmodifiable(pts),
          color: AppColors.primary.withValues(alpha: alphas[s]),
          width: s == segCount - 1 ? 14 : 12,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state == _RunState.ready,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_state == _RunState.running) {
          final confirmed = await _confirmStop();
          if (confirmed == true && mounted) await _stopRun();
        }
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: SafeArea(
          child: switch (_state) {
            _RunState.ready => _buildReady(),
            _RunState.starting => _buildStarting(),
            _RunState.running => _buildLive(),
          },
        ),
      ),
    );
  }

  Widget _buildReady() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Spacer(),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_run_rounded,
              size: 52,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 28),
          Text(
            l10n.runStartTitle,
            style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            l10n.runStartHint,
            style: AppTextStyles.body.copyWith(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _onStartPressed,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      l10n.runStartButton,
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStarting() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(l10n.runGpsConnecting, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildLive() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(height: 16),
          Text(
            l10n.runDistance,
            style: AppTextStyles.smallBold.copyWith(
              letterSpacing: 1.5,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                RunMetrics.formatDistanceKmBig(_distanceMeters),
                style: AppTextStyles.display.copyWith(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'km',
                  style: AppTextStyles.h3.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 28),
          Row(
            children: [
              _StatColumn(
                label: l10n.runTime,
                value: RunMetrics.formatElapsed(_elapsed),
              ),
              _StatDivider(),
              _StatColumn(
                label: l10n.runPace,
                value: RunMetrics.formatPace(_currentPaceSecondsPerKm),
              ),
              _StatDivider(),
              _StatColumn(
                label: l10n.runCalories,
                value:
                    '${RunMetrics.estimateCalories(distanceMeters: _distanceMeters)}',
                suffix: 'kcal',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(37.5665, 126.978),
                      zoom: 16,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    onCameraMoveStarted: _onCameraMoveStarted,
                    onLongPress: _onMapLongPress,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    polylines: _buildFadedPolylines(),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: AppColors.primary.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardColor.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            l10n.runLongPressHint,
                            style: AppTextStyles.caption.copyWith(
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _stopRun,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  const _StatColumn({required this.label, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              letterSpacing: 1.2,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix!,
                    style: AppTextStyles.small.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}
