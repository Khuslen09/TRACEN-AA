import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../models/activity_type.dart';
import '../../../services/activity_recorder.dart';
import '../../../services/route_db_service.dart';
import '../../../theme/theme_extensions.dart';
import 'split_tracking_layout.dart';
import 'widgets/tracking_controls_bar.dart';
import 'widgets/tracking_map_panel.dart';
import 'widgets/tracking_metrics_panel.dart';

/// 러닝/워킹/사이클링 실시간 기록 화면 — 위아래 2분할.
///
/// [resumeRouteId]가 주어지면 (강제종료 등으로 끊긴) 기존 기록을
/// [ActivityRecorder.resumeExisting]으로 이어받아 곧장 기록 상태로 연다 —
/// `HomeScreen`의 복구 로직이 이 경로로 진입시킴.
///
/// AppBar의 활동 타입 전환 아이콘은 **아직 idle/countdown 상태가 없는
/// 과도기 전용 테스트용**이다. 다음 단계(시작 대기 화면)에서 제거되고,
/// 호출 측이 넘겨주는 [activityType] 하나로 고정될 예정.
class ActivityTrackingScreen extends StatefulWidget {
  final ActivityType activityType;
  final int? resumeRouteId;

  const ActivityTrackingScreen({
    super.key,
    required this.activityType,
    this.resumeRouteId,
  });

  @override
  State<ActivityTrackingScreen> createState() =>
      _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState extends State<ActivityTrackingScreen> {
  late ActivityType _activityType = widget.activityType;
  late ActivityRecorder _controller = ActivityRecorder(_activityType);
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    final resumeId = widget.resumeRouteId;
    if (resumeId != null) {
      _controller.resumeExisting(resumeId);
    } else {
      _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _onPauseResume() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _controller.pause();
      } else {
        _controller.resume();
      }
    });
  }

  Future<void> _onStop() async {
    await _controller.stop();
    // 결과 화면은 3단계에서 연결 — 지금은 종료만 하고 돌아감.
    if (mounted) Navigator.of(context).pop();
  }

  /// 테스트용 — 다음 단계에서 제거. 진행 중이던 기록은 버림(delete).
  Future<void> _cycleActivityType() async {
    final values = ActivityType.values;
    final next = values[(values.indexOf(_activityType) + 1) % values.length];
    final oldController = _controller;
    final oldRouteId = oldController.routeId;
    setState(() {
      _activityType = next;
      _controller = ActivityRecorder(next)..start();
    });
    oldController.dispose();
    await RouteDBService.deleteRoute(oldRouteId);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset =
        TrackingControlsBar.barHeight +
        TrackingControlsBar.bottomMargin +
        MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_activityType.label),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Switch activity type (test only)',
            icon: Icon(_activityType.icon),
            onPressed: _cycleActivityType,
          ),
        ],
      ),
      body: SplitTrackingLayout(
        metricsPanelBuilder: (context, height) => TrackingMetricsPanel(
          activityType: _activityType,
          metricsListenable: _controller.metrics,
          currentHeight: height,
        ),
        mapPanel: TrackingMapPanel(
          key: ValueKey(_controller),
          mapStateListenable: _controller.mapState,
          bottomPadding: bottomInset,
        ),
        controlsBar: TrackingControlsBar(
          isPaused: _isPaused,
          onPauseResume: _onPauseResume,
          onStop: _onStop,
          // TODO(다음 단계): 사진 촬영 플로우 연결.
          onCamera: null,
        ),
      ),
    );
  }
}
