import 'activity_type.dart';

/// 여정(route)의 생명주기 상태.
///
/// - [recording]: 진행 중. 앱이 죽어도 재실행 시 [ActivityRecorder]가
///   이 상태의 route를 이어받아 기록을 재개한다.
/// - [pendingReview]: 기록은 끝났지만 아직 저장/삭제를 선택하지 않음.
///   재실행 시 결과 화면으로 다시 열린다.
/// - [completed]: 저장 완료 — 평소 화면(지도/목록)에 정식으로 노출.
enum RouteStatus {
  recording('recording'),
  pendingReview('pending_review'),
  completed('completed');

  final String key;
  const RouteStatus(this.key);

  static RouteStatus fromKey(String? key) {
    for (final s in RouteStatus.values) {
      if (s.key == key) return s;
    }
    return RouteStatus.completed;
  }
}

/// 명시적 시작/종료가 있는 한 번의 러닝/산책 세션.
///
/// **MVP 변경 메모 (DB v5)**: 기존엔 모든 이동 기록의 단위였지만, 24시간
/// 백그라운드 추적이 도입되면서 **명시적 러닝 세션 전용**으로 의미 변경.
/// 클래스 이름은 호환성을 위해 TraceRoute로 유지하되, 의미는 "Run"입니다.
/// 새 코드는 [Run] typedef를 사용해 의도를 명확히 표현하세요.
///
/// - [id]: 로컬 SQLite의 INTEGER PRIMARY KEY (오프라인 즉시 사용)
/// - [uuid]: 클라우드 동기화용 영구 식별자 (Firestore 문서 ID로 사용)
/// - [startedAt]: 기록 시작 시각
/// - [endedAt]: 기록 종료 시각 (진행 중이면 null)
/// - [distance]: 총 이동 거리 (미터). 매 GPS 점마다 갱신되어 저장.
/// - [userId]: Firebase 연동 시 사용자 식별자
/// - [activityType]: 러닝/워킹/사이클링 (DB v6 신규, 기본 running)
/// - [memo]: 결과 화면에서 입력하는 한 줄 메모 (DB v6 신규)
/// - [status]: 생명주기 상태 (DB v6 신규, 기본 completed — 과거 기록 호환)
/// - [lastActiveAt]: 마지막으로 유효 GPS 점을 받은 시각. 강제종료 뒤
///   재실행 시 "죽어있던 시간"을 일시정지로 환산하는 기준 (DB v6 신규)
class TraceRoute {
  final int? id;
  final String uuid;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distance; // meters
  final String? userId;
  final ActivityType activityType;
  final String? memo;
  final RouteStatus status;
  final DateTime? lastActiveAt;

  TraceRoute({
    this.id,
    required this.uuid,
    required this.title,
    required this.startedAt,
    this.endedAt,
    this.distance = 0.0,
    this.userId,
    this.activityType = ActivityType.running,
    this.memo,
    this.status = RouteStatus.completed,
    this.lastActiveAt,
  });

  /// 진행 중인 여정인지 여부
  bool get isActive => endedAt == null;

  /// 여정 소요 시간 (진행 중이면 현재까지)
  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  /// SQLite 저장용 Map 변환
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'uuid': uuid,
    'title': title,
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'distance': distance,
    'user_id': userId,
    'activity_type': activityType.key,
    'memo': memo,
    'status': status.key,
    'last_active_at': lastActiveAt?.toIso8601String(),
  };

  /// SQLite 조회 결과를 객체로 변환
  factory TraceRoute.fromMap(Map<String, dynamic> map) => TraceRoute(
    id: map['id'] as int?,
    uuid: map['uuid'] as String,
    title: map['title'] as String,
    startedAt: DateTime.parse(map['started_at'] as String),
    endedAt: map['ended_at'] != null
        ? DateTime.parse(map['ended_at'] as String)
        : null,
    distance: (map['distance'] as num?)?.toDouble() ?? 0.0,
    userId: map['user_id'] as String?,
    activityType: ActivityType.fromKey(map['activity_type'] as String?),
    memo: map['memo'] as String?,
    status: RouteStatus.fromKey(map['status'] as String?),
    lastActiveAt: map['last_active_at'] != null
        ? DateTime.parse(map['last_active_at'] as String)
        : null,
  );

  /// 일부 필드만 변경한 새 객체 반환 (불변 패턴)
  TraceRoute copyWith({
    int? id,
    String? uuid,
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    double? distance,
    String? userId,
    ActivityType? activityType,
    String? memo,
    RouteStatus? status,
    DateTime? lastActiveAt,
  }) => TraceRoute(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    title: title ?? this.title,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    distance: distance ?? this.distance,
    userId: userId ?? this.userId,
    activityType: activityType ?? this.activityType,
    memo: memo ?? this.memo,
    status: status ?? this.status,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
  );
}

/// 의미 명확한 별칭. 새 코드는 이 이름을 사용하세요.
/// 내부 구현은 [TraceRoute]와 동일.
typedef Run = TraceRoute;
