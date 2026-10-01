import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// 실시간 기록 화면이 지원하는 활동 종류.
///
/// `PinCategory`와 같은 패턴: `key`는 나중에 DB/Firestore에 저장될 영속
/// 식별자(아직 미연결 — 이번 UI 단계에서는 화면 안 임시 토글로만 쓰임),
/// `label`은 [Strings.current] 기반이라 언어가 바뀌어도 안전.
enum ActivityType {
  running('running', Icons.directions_run_rounded),
  walking('walking', Icons.directions_walk_rounded),
  cycling('cycling', Icons.directions_bike_rounded);

  final String key;
  final IconData icon;

  const ActivityType(this.key, this.icon);

  String get label => switch (this) {
    ActivityType.running => Strings.current.activityRunning,
    ActivityType.walking => Strings.current.activityWalking,
    ActivityType.cycling => Strings.current.activityCycling,
  };

  /// 러닝/워킹은 "분당 몇 킬로(페이스)", 사이클링은 "시속 몇 킬로(속도)"가
  /// 자연스러운 주요 지표 단위 — 화면 쪽에서 이 한 값으로 분기.
  bool get usesPace => this != ActivityType.cycling;

  /// 러닝/워킹만 걸음 수 집계가 의미 있음.
  bool get tracksSteps => this != ActivityType.cycling;

  /// 자동 일시정지 판단 기준 속도(m/s). 이보다 느리게 8초 이상 유지되면
  /// 자동 일시정지([ActivityRecorder] 참고).
  double get autoPauseSpeedThreshold => switch (this) {
    ActivityType.walking => 0.5,
    ActivityType.running => 1.0,
    ActivityType.cycling => 1.5,
  };

  /// DB에서 읽은 문자열을 enum으로 변환. 알 수 없으면 running.
  static ActivityType fromKey(String? key) {
    for (final t in ActivityType.values) {
      if (t.key == key) return t;
    }
    return ActivityType.running;
  }
}
