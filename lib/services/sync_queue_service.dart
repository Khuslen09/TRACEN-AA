import 'package:sqflite/sqflite.dart';

import 'route_db_service.dart';

/// 클라우드 동기화 작업의 종류.
///
/// 각 enum 값이 sync_queue.action 컬럼에 저장됩니다.
enum SyncAction {
  uploadRoute,
  deleteRoute,
  uploadPin,
  deletePin,
  uploadDayTrack,
}

extension SyncActionX on SyncAction {
  String get key {
    switch (this) {
      case SyncAction.uploadRoute:
        return 'upload_route';
      case SyncAction.deleteRoute:
        return 'delete_route';
      case SyncAction.uploadPin:
        return 'upload_pin';
      case SyncAction.deletePin:
        return 'delete_pin';
      case SyncAction.uploadDayTrack:
        return 'upload_day_track';
    }
  }

  static SyncAction fromKey(String s) {
    switch (s) {
      case 'upload_route':
        return SyncAction.uploadRoute;
      case 'delete_route':
        return SyncAction.deleteRoute;
      case 'upload_pin':
        return SyncAction.uploadPin;
      case 'delete_pin':
        return SyncAction.deletePin;
      case 'upload_day_track':
        return SyncAction.uploadDayTrack;
      default:
        throw ArgumentError('Unknown sync action: $s');
    }
  }
}

/// 큐에 들어있는 한 작업.
class SyncJob {
  final int id;
  final SyncAction action;
  final String entityUuid;

  /// 추가 정보 (예: 삭제 시 photo_storage_path).
  /// 핀 삭제할 때 핀이 이미 로컬에서 사라졌어도 사진을 지울 수 있도록 보존.
  final String? payload;

  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  SyncJob({
    required this.id,
    required this.action,
    required this.entityUuid,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    required this.lastError,
  });

  factory SyncJob.fromMap(Map<String, dynamic> map) => SyncJob(
        id: map['id'] as int,
        action: SyncActionX.fromKey(map['action'] as String),
        entityUuid: map['entity_uuid'] as String,
        payload: map['payload'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        attempts: map['attempts'] as int,
        lastError: map['last_error'] as String?,
      );
}

/// sync_queue 테이블에 대한 thin wrapper.
///
/// CloudSyncService가 이 큐를 읽고 처리합니다.
class SyncQueueService {
  SyncQueueService._();

  static const _table = 'sync_queue';

  /// 작업 큐에 추가. 같은 entity의 같은 action이 이미 있으면 덮어쓰기.
  /// (예: route 업로드 큐가 이미 있는데 또 추가되면 중복 무의미)
  static Future<void> enqueue({
    required SyncAction action,
    required String entityUuid,
    String? payload,
  }) async {
    final db = await RouteDBService.db;
    await db.transaction((txn) async {
      // 동일 작업이 이미 있으면 한 번만 쌓이도록 중복 제거
      await txn.delete(
        _table,
        where: 'action = ? AND entity_uuid = ?',
        whereArgs: [action.key, entityUuid],
      );
      await txn.insert(_table, {
        'action': action.key,
        'entity': _entityFor(action),
        'entity_uuid': entityUuid,
        'payload': payload,
        'created_at': DateTime.now().toIso8601String(),
        'attempts': 0,
      });
    });
  }

  /// 처리 대기 작업 N개 가져오기 (오래된 순).
  static Future<List<SyncJob>> peek({int limit = 20}) async {
    final db = await RouteDBService.db;
    final rows = await db.query(
      _table,
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(SyncJob.fromMap).toList();
  }

  /// 작업 성공 → 큐에서 제거.
  static Future<void> markDone(int jobId) async {
    final db = await RouteDBService.db;
    await db.delete(_table, where: 'id = ?', whereArgs: [jobId]);
  }

  /// 작업 실패 → attempts++, lastError 기록. 큐에 남겨서 다음 기회에 재시도.
  static Future<void> markFailed(int jobId, String error) async {
    final db = await RouteDBService.db;
    await db.rawUpdate(
      'UPDATE $_table SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [_truncate(error, 500), jobId],
    );
  }

  /// 영구 실패한 작업 정리 — 5번 이상 실패 시 그냥 버림.
  /// 사용자에게 안 보이는 백그라운드 작업이라 무한 재시도하면 배터리 낭비.
  static Future<void> reapDeadJobs({int maxAttempts = 5}) async {
    final db = await RouteDBService.db;
    await db.delete(
      _table,
      where: 'attempts >= ?',
      whereArgs: [maxAttempts],
    );
  }

  /// 큐에 대기 중인 작업 수 (디버깅 / 사용자 알림용).
  static Future<int> pendingCount() async {
    final db = await RouteDBService.db;
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM $_table');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  static Future<void> clearAll() async {
    final db = await RouteDBService.db;
    await db.delete(_table);
  }

  // ─────────────────────────────────────────────
  // 내부
  // ─────────────────────────────────────────────

  static String _entityFor(SyncAction action) {
    switch (action) {
      case SyncAction.uploadRoute:
      case SyncAction.deleteRoute:
        return 'route';
      case SyncAction.uploadPin:
      case SyncAction.deletePin:
        return 'pin';
      case SyncAction.uploadDayTrack:
        return 'day_track';
    }
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : s.substring(0, max);
}
