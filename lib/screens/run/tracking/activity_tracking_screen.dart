import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../models/activity_type.dart';
import '../../../services/activity_recorder.dart';
import '../../../services/permission_service.dart';
import '../../../services/route_db_service.dart';
import '../../../services/run_metrics.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_extensions.dart';
import '../activity_result_screen.dart';
import 'split_tracking_layout.dart';
import 'widgets/tracking_controls_bar.dart';
import 'widgets/tracking_idle_widgets.dart';
import 'widgets/tracking_map_panel.dart';
import 'widgets/tracking_metrics_panel.dart';

enum _Phase { idle, countdown, recording }

/// 러닝/워킹/사이클링 기록 화면 — 위아래 2분할.
///
/// 상태 흐름: idle(활동 선택 + GPS 대기) → countdown(3·2·1) → recording
/// (⇄ 일시정지) → 길게 눌러 종료 → [ActivityResultScreen].
///
/// idle에서도 같은 [SplitTrackingLayout]을 쓰고 위쪽 카드만 바꾼다 —
/// 지도(GoogleMap 네이티브 뷰)가 시작 순간에 다시 만들어지지 않게 하기 위함.
///
/// [resumeRouteId]가 주어지면 (강제종료 등으로 끊긴) 기존 기록을
/// [ActivityRecorder.resumeExisting]으로 이어받아 곧장 기록 상태로 연다 —
/// `HomeScreen`의 복구 로직이 이 경로로 진입시킴.
class ActivityTrackingScreen extends StatefulWidget {
  /// 처음 선택돼 있을 활동. null이면 마지막으로 고른 활동(없으면 러닝).
  final ActivityType? activityType;
  final int? resumeRouteId;

  const ActivityTrackingScreen({
    super.key,
    this.activityType,
    this.resumeRouteId,
  });

  @override
  State<ActivityTrackingScreen> createState() =>
      _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState extends State<ActivityTrackingScreen>
    with WidgetsBindingObserver {
  static const _lastTypeKey = 'tracking_last_activity_type';

  /// 이보다 짧거나(이동 시간) 가까운(거리) 기록은 저장 전에 한 번 묻는다.
  static const _shortMovingTime = Duration(minutes: 1);
  static const _shortDistanceMeters = 50.0;

  late final ActivityRecorder _recorder = ActivityRecorder(
    widget.activityType ?? ActivityType.running,
  );

  late _Phase _phase = widget.resumeRouteId != null
      ? _Phase.recording
      : _Phase.idle;
  bool _isPaused = false;
  bool _stopping = false;
  AppPermissionStatus? _locationStatus;
  bool _warmedUp = false;

  ActivityType get _type => _recorder.activityType;
  bool get _isIdle => _phase == _Phase.idle || _phase == _Phase.countdown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    final resumeId = widget.resumeRouteId;
    if (resumeId != null) {
      _recorder.resumeExisting(resumeId);
    } else {
      _initIdle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정 앱에서 권한을 켜고 돌아온 경우 다시 확인.
    if (state == AppLifecycleState.resumed &&
        _phase == _Phase.idle &&
        _locationStatus != AppPermissionStatus.granted) {
      _refreshPermission();
    }
  }

  // ─────────────────────────────────────────────
  // idle
  // ─────────────────────────────────────────────

  Future<void> _initIdle() async {
    if (widget.activityType == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_lastTypeKey);
        if (saved != null && mounted && _phase == _Phase.idle) {
          setState(() => _recorder.activityType = ActivityType.fromKey(saved));
        }
      } catch (_) {
        // 기억된 선택을 못 읽어도 기본값(러닝)으로 진행.
      }
    }
    await _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final status = await PermissionService.locationStatus();
    if (!mounted) return;
    setState(() => _locationStatus = status);
    if (status == AppPermissionStatus.granted && !_warmedUp) {
      _warmedUp = true;
      await _recorder.warmUp();
    }
  }

  Future<void> _selectType(ActivityType type) async {
    if (_phase != _Phase.idle) return;
    setState(() => _recorder.activityType = type);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastTypeKey, type.key);
    } catch (_) {}
  }

  Future<void> _requestWhileUsing() async {
    await PermissionService.requestLocation();
    await _refreshPermission();
  }

  Future<void> _requestAlways() async {
    // iOS는 "사용 중"을 먼저 받아야 "항상"으로 올릴 수 있다.
    final whenInUse = await PermissionService.requestLocation();
    if (whenInUse == AppPermissionStatus.granted) {
      await PermissionService.requestLocationAlways();
    }
    await _refreshPermission();
  }

  Future<void> _onStartPressed() async {
    final acc = _recorder.lastAccuracy.value;
    final ready = acc != null && acc <= ActivityRecorder.readyAccuracyMeters;
    if (!ready) {
      final l10n = AppLocalizations.of(context);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.trackingWeakGpsTitle),
          content: Text(l10n.trackingWeakGpsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.trackingWait),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.trackingStartAnyway),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _phase = _Phase.countdown);
  }

  Future<void> _onCountdownFinished() async {
    if (_phase != _Phase.countdown) return;
    setState(() => _phase = _Phase.recording);
    await _recorder.start();
  }

  // ─────────────────────────────────────────────
  // recording
  // ─────────────────────────────────────────────

  void _onPauseResume() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _recorder.pause();
      } else {
        _recorder.resume();
      }
    });
  }

  Future<void> _onStop() async {
    if (_stopping || !_recorder.hasRoute) return;
    _stopping = true;
    final l10n = AppLocalizations.of(context);
    await _recorder.stop();
    final routeId = _recorder.routeId;
    final m = _recorder.metrics.value;

    if (m.elapsed < _shortMovingTime ||
        m.distanceMeters < _shortDistanceMeters) {
      if (!mounted) return;
      final summary =
          '${RunMetrics.formatElapsed(m.elapsed)} · '
          '${RunMetrics.formatDistance(m.distanceMeters)}';
      final save = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.trackingShortTitle),
          content: Text(l10n.trackingShortBody(summary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(l10n.commonDelete),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.resultSaveShort),
            ),
          ],
        ),
      );
      if (save != true) {
        await RouteDBService.deleteRoute(routeId);
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ActivityResultScreen(routeId: routeId)),
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset =
        TrackingControlsBar.barHeight +
        TrackingControlsBar.bottomMargin +
        MediaQuery.of(context).padding.bottom;

    return PopScope(
      // 기록 중에는 뒤로가기로 실수로 나가지 않게 — 길게 눌러 종료만 허용.
      canPop: _phase == _Phase.idle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.recording) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.trackingHoldToStop)));
        }
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: _phase == _Phase.idle
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(_type.label),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            SplitTrackingLayout(
              lockedMetricsHeight: _isIdle
                  ? TrackingIdlePanel.panelHeight
                  : null,
              metricsPanelBuilder: (context, height) => _isIdle
                  ? TrackingIdlePanel(
                      selected: _type,
                      onSelected: _selectType,
                      accuracyListenable: _recorder.lastAccuracy,
                    )
                  : TrackingMetricsPanel(
                      activityType: _type,
                      metricsListenable: _recorder.metrics,
                      currentHeight: height,
                    ),
              mapPanel: TrackingMapPanel(
                mapStateListenable: _recorder.mapState,
                bottomPadding: bottomInset,
                debugInfoListenable: _recorder.debugGpsInfo,
                accuracyStatusListenable: _recorder.accuracyStatus,
                onRequestFullAccuracy: _recorder.requestFullAccuracy,
              ),
              controlsBar: _buildBottom(),
            ),
            if (_phase == _Phase.countdown)
              Positioned.fill(
                child: TrackingCountdownOverlay(
                  onFinished: _onCountdownFinished,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottom() {
    if (!_isIdle) {
      return TrackingControlsBar(
        isPaused: _isPaused,
        onPauseResume: _onPauseResume,
        onStop: _onStop,
        // 사진 촬영 플로우는 다음 단계에서 연결.
        onCamera: null,
      );
    }
    final status = _locationStatus;
    if (status == null) return const SizedBox.shrink();
    if (status != AppPermissionStatus.granted) {
      return TrackingPermissionCard(
        status: status,
        onAllowWhileUsing: _requestWhileUsing,
        onAllowAlways: _requestAlways,
        onOpenSettings: PermissionService.openSettings,
      );
    }
    return ValueListenableBuilder<double?>(
      valueListenable: _recorder.lastAccuracy,
      builder: (context, acc, _) => TrackingStartButton(
        activityType: _type,
        gpsReady: acc != null && acc <= ActivityRecorder.readyAccuracyMeters,
        onPressed: _onStartPressed,
      ),
    );
  }
}
