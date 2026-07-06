import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import '../models/route.dart';
import '../models/route_point.dart';
import '../models/pin.dart';

/// SQLite 기반 여정 데이터 저장소.
///
/// 테이블 구조 (v3):
///   routes        - 여정 메타데이터. uuid 컬럼으로 클라우드 동기화 지원.
///   route_points  - 여정 안의 GPS 점들 (Polyline용)
///   pins          - 여정 안의 사진/메모 핀. uuid + photo_url + photo_storage_path.
///   sync_queue    - 클라우드 동기화 작업 큐 (오프라인 → 온라인 재시도용)
///
/// 모든 메서드는 static — 앱 어디서든 RouteDBService.xxx 로 호출.
class RouteDBService {
  static Database? _db;
  static const _dbName = 'aa.db';
  static const _dbVersion = 5; // v4 → v5 (pins.run_id, day_tracks 신규)

  static const _uuidGen = Uuid();

  // ─────────────────────────────────────────────────────────
  // DB 초기화
  // ─────────────────────────────────────────────────────────

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// 새 설치: 처음부터 v5 스키마로 생성
  static Future<void> _onCreate(Database db, int version) async {
    await _createV5Tables(db);
  }

  /// 마이그레이션 (각 단계는 다음 단계의 출발점이 된 스키마를 만든다):
  ///   v1 → v2: route_points만 있던 초기 → routes/pins 추가 + Legacy 여정 보존
  ///   v2 → v3: uuid + sync_queue 추가
  ///   v3 → v4: pins.category 추가
  ///   v4 → v5: pins에 run_id 추가 (route_id는 호환성 위해 유지),
  ///            day_tracks 테이블 신규 (24시간 백그라운드 추적)
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _migrateV1ToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateV2ToV3(db);
    }
    if (oldVersion < 4) {
      await _migrateV3ToV4(db);
    }
    if (oldVersion < 5) {
      await _migrateV4ToV5(db);
    }
  }

  // ─────────────────────────────────────────────────────────
  // 마이그레이션 헬퍼
  // ─────────────────────────────────────────────────────────

  static Future<void> _migrateV1ToV2(Database db) async {
    List<Map<String, dynamic>> legacyPoints = [];
    try {
      legacyPoints = await db.query('route_points', orderBy: 'id ASC');
    } catch (_) {}

    await db.execute('DROP TABLE IF EXISTS route_points');
    // v2 스키마 (uuid 없는 옛 형태)로 일단 만들기 — v2→v3에서 컬럼 추가됨
    await db.execute('''
      CREATE TABLE routes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT    NOT NULL,
        started_at  TEXT    NOT NULL,
        ended_at    TEXT,
        distance    REAL    NOT NULL DEFAULT 0,
        user_id     TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE route_points (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id  INTEGER NOT NULL,
        lat       REAL    NOT NULL,
        lng       REAL    NOT NULL,
        time      TEXT    NOT NULL,
        FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE pins (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id    INTEGER NOT NULL,
        lat         REAL    NOT NULL,
        lng         REAL    NOT NULL,
        photo_path  TEXT,
        memo        TEXT,
        created_at  TEXT    NOT NULL,
        FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
      )
    ''');

    if (legacyPoints.isNotEmpty) {
      final firstTime =
          legacyPoints.first['time'] as String? ??
          DateTime.now().toIso8601String();
      final lastTime = legacyPoints.last['time'] as String? ?? firstTime;

      final legacyRouteId = await db.insert('routes', {
        'title': '이전 기록 (자동 복구)',
        'started_at': firstTime,
        'ended_at': lastTime,
        'distance': 0.0,
        'user_id': null,
      });

      final batch = db.batch();
      for (final p in legacyPoints) {
        batch.insert('route_points', {
          'route_id': legacyRouteId,
          'lat': p['lat'],
          'lng': p['lng'],
          'time': p['time'] ?? firstTime,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  /// v2 → v3:
  ///   - routes에 uuid 컬럼 추가, 기존 행에 UUID 채워넣기
  ///   - pins에 uuid, photo_url, photo_storage_path 추가
  ///   - sync_queue 테이블 신규 생성
  static Future<void> _migrateV2ToV3(Database db) async {
    // routes.uuid
    await db.execute('ALTER TABLE routes ADD COLUMN uuid TEXT');
    final existingRoutes = await db.query('routes');
    for (final r in existingRoutes) {
      await db.update(
        'routes',
        {'uuid': _uuidGen.v4()},
        where: 'id = ?',
        whereArgs: [r['id']],
      );
    }
    // SQLite는 ALTER TABLE로 NOT NULL 강제할 수 없음 — 인덱스로 대체
    await db.execute('CREATE UNIQUE INDEX idx_routes_uuid ON routes(uuid)');

    // pins.uuid + 사진 URL/경로
    await db.execute('ALTER TABLE pins ADD COLUMN uuid TEXT');
    await db.execute('ALTER TABLE pins ADD COLUMN photo_url TEXT');
    await db.execute('ALTER TABLE pins ADD COLUMN photo_storage_path TEXT');
    final existingPins = await db.query('pins');
    for (final p in existingPins) {
      await db.update(
        'pins',
        {'uuid': _uuidGen.v4()},
        where: 'id = ?',
        whereArgs: [p['id']],
      );
    }
    await db.execute('CREATE UNIQUE INDEX idx_pins_uuid ON pins(uuid)');

    // sync_queue
    await _createSyncQueueTable(db);
  }

  static Future<void> _createV5Tables(Database db) async {
    // 'routes' 테이블 — 의미상 'runs' (러닝 세션). 호환성 위해 이름 유지.
    await db.execute('''
      CREATE TABLE routes (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid        TEXT    NOT NULL UNIQUE,
        title       TEXT    NOT NULL,
        started_at  TEXT    NOT NULL,
        ended_at    TEXT,
        distance    REAL    NOT NULL DEFAULT 0,
        user_id     TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE route_points (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id  INTEGER NOT NULL,
        lat       REAL    NOT NULL,
        lng       REAL    NOT NULL,
        time      TEXT    NOT NULL,
        FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
      )
    ''');

    // pins — v5: route_id 제거(NULLABLE이지만 보존), run_id 추가, user_id 추가
    await db.execute('''
      CREATE TABLE pins (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid               TEXT    NOT NULL UNIQUE,
        route_id           INTEGER,
        run_id             INTEGER,
        user_id            TEXT,
        lat                REAL    NOT NULL,
        lng                REAL    NOT NULL,
        category           TEXT    NOT NULL DEFAULT 'general',
        photo_path         TEXT,
        photo_url          TEXT,
        photo_storage_path TEXT,
        memo               TEXT,
        created_at         TEXT    NOT NULL,
        FOREIGN KEY (run_id) REFERENCES routes(id) ON DELETE SET NULL
      )
    ''');

    // day_tracks — 24시간 백그라운드 추적의 일별 점들.
    // dayId는 'YYYY-MM-DD' 형식. user_id와 함께 UNIQUE 제약.
    await db.execute('''
      CREATE TABLE day_tracks (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        day_id    TEXT    NOT NULL,
        user_id   TEXT,
        lat       REAL    NOT NULL,
        lng       REAL    NOT NULL,
        time      TEXT    NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_route_points_route_id ON route_points(route_id)',
    );
    await db.execute('CREATE INDEX idx_pins_run_id ON pins(run_id)');
    await db.execute('CREATE INDEX idx_pins_user ON pins(user_id, created_at)');
    await db.execute('CREATE INDEX idx_routes_started ON routes(started_at)');
    await db.execute(
      'CREATE INDEX idx_day_tracks ON day_tracks(user_id, day_id, time)',
    );

    await _createSyncQueueTable(db);
  }

  /// v3 → v4: pins 테이블에 category 컬럼 추가.
  /// 기존 핀들은 모두 'general' 카테고리로 자동 분류.
  static Future<void> _migrateV3ToV4(Database db) async {
    await db.execute(
      "ALTER TABLE pins ADD COLUMN category TEXT NOT NULL DEFAULT 'general'",
    );
  }

  /// v4 → v5: 핀을 독립 엔티티로 승격 (run 자식 → 독립).
  ///
  /// 변경:
  ///   - pins에 run_id 추가 (기존 route_id 값으로 채움 — 이전 핀은 그 러닝의 자식)
  ///   - pins에 user_id 추가 (해당 route의 user_id 값으로 채움)
  ///   - day_tracks 테이블 신규
  ///
  /// SQLite는 기존 컬럼 삭제가 어려워 route_id는 그냥 둠. 새 코드는 무시.
  static Future<void> _migrateV4ToV5(Database db) async {
    // pins.run_id 추가 — 기존 route_id 값을 복사해 보존
    await db.execute('ALTER TABLE pins ADD COLUMN run_id INTEGER');
    await db.execute('UPDATE pins SET run_id = route_id');

    // pins.user_id 추가 — 해당 run의 user_id를 채움
    await db.execute('ALTER TABLE pins ADD COLUMN user_id TEXT');
    await db.execute('''
      UPDATE pins
      SET user_id = (
        SELECT user_id FROM routes WHERE routes.id = pins.run_id
      )
    ''');

    // day_tracks 테이블 신규
    await db.execute('''
      CREATE TABLE day_tracks (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        day_id    TEXT    NOT NULL,
        user_id   TEXT,
        lat       REAL    NOT NULL,
        lng       REAL    NOT NULL,
        time      TEXT    NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_pins_run_id ON pins(run_id)');
    await db.execute('CREATE INDEX idx_pins_user ON pins(user_id, created_at)');
    await db.execute(
      'CREATE INDEX idx_day_tracks ON day_tracks(user_id, day_id, time)',
    );
  }

  static Future<void> _createSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        entity      TEXT    NOT NULL,
        entity_uuid TEXT    NOT NULL,
        action      TEXT    NOT NULL,
        payload     TEXT,
        created_at  TEXT    NOT NULL,
        attempts    INTEGER NOT NULL DEFAULT 0,
        last_error  TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_sync_queue_created ON sync_queue(created_at)',
    );
  }

  // ─────────────────────────────────────────────────────────
  // ROUTES
  // ─────────────────────────────────────────────────────────

  /// 새 여정 시작. UUID 자동 생성.
  static Future<int> startRoute({String? title, String? userId}) async {
    final database = await db;
    final now = DateTime.now();
    final route = TraceRoute(
      uuid: _uuidGen.v4(),
      title: title ?? _defaultTitle(now),
      startedAt: now,
      userId: userId,
    );
    return database.insert('routes', route.toMap());
  }

  static Future<void> endRoute(int routeId, {double? distance}) async {
    final database = await db;
    await database.update(
      'routes',
      {
        'ended_at': DateTime.now().toIso8601String(),
        if (distance != null) 'distance': distance,
      },
      where: 'id = ?',
      whereArgs: [routeId],
    );
  }

  static Future<void> updateRoute(TraceRoute route) async {
    if (route.id == null) {
      throw ArgumentError('Cannot update a route without id');
    }
    final database = await db;
    await database.update(
      'routes',
      route.toMap(),
      where: 'id = ?',
      whereArgs: [route.id],
    );
  }

  static Future<TraceRoute?> getRoute(int id) async {
    final database = await db;
    final rows = await database.query(
      'routes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TraceRoute.fromMap(rows.first);
  }

  /// UUID로 여정 조회 — Firestore에서 다운로드한 데이터를 로컬에서 찾을 때 사용.
  static Future<TraceRoute?> getRouteByUuid(String uuid) async {
    final database = await db;
    final rows = await database.query(
      'routes',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TraceRoute.fromMap(rows.first);
  }

  static Future<List<TraceRoute>> getAllRoutes() async {
    final database = await db;
    final rows = await database.query('routes', orderBy: 'started_at DESC');
    return rows.map(TraceRoute.fromMap).toList();
  }

  /// 특정 사용자(userId)의 여정만 조회 — 다른 계정 데이터 격리용.
  static Future<List<TraceRoute>> getRoutesForUser(String userId) async {
    final database = await db;
    final rows = await database.query(
      'routes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'started_at DESC',
    );
    return rows.map(TraceRoute.fromMap).toList();
  }

  static Future<TraceRoute?> getActiveRoute() async {
    final database = await db;
    final rows = await database.query(
      'routes',
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TraceRoute.fromMap(rows.first);
  }

  static Future<void> deleteRoute(int routeId) async {
    final database = await db;
    await database.delete('routes', where: 'id = ?', whereArgs: [routeId]);
  }

  /// Firestore 다운로드용: 로컬에 같은 uuid가 없으면 INSERT, 있으면 UPDATE.
  static Future<int> upsertRouteFromCloud(TraceRoute route) async {
    final database = await db;
    final existing = await getRouteByUuid(route.uuid);
    if (existing == null) {
      // id 빼고 INSERT
      final map = route.toMap()..remove('id');
      return database.insert('routes', map);
    } else {
      final merged = route.copyWith(id: existing.id);
      await database.update(
        'routes',
        merged.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
  }

  // ─────────────────────────────────────────────────────────
  // ROUTE POINTS
  // ─────────────────────────────────────────────────────────

  static Future<void> insertPoint({
    required int routeId,
    required double lat,
    required double lng,
    DateTime? time,
  }) async {
    final database = await db;
    await database.insert('route_points', {
      'route_id': routeId,
      'lat': lat,
      'lng': lng,
      'time': (time ?? DateTime.now()).toIso8601String(),
    });
  }

  static Future<List<RoutePoint>> getPoints(int routeId) async {
    final database = await db;
    final rows = await database.query(
      'route_points',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'time ASC',
    );
    return rows.map(RoutePoint.fromMap).toList();
  }

  /// 다운로드한 polyline을 로컬에 채워넣을 때 사용.
  /// 기존 점들 모두 삭제 후 일괄 삽입.
  static Future<void> replacePoints(
    int routeId,
    List<({double lat, double lng})> latLngs,
  ) async {
    final database = await db;
    await database.transaction((txn) async {
      await txn.delete(
        'route_points',
        where: 'route_id = ?',
        whereArgs: [routeId],
      );
      final batch = txn.batch();
      final now = DateTime.now().toIso8601String();
      for (final p in latLngs) {
        batch.insert('route_points', {
          'route_id': routeId,
          'lat': p.lat,
          'lng': p.lng,
          'time': now, // 시간 정보 손실 — 설계 문서 3.1 참조
        });
      }
      await batch.commit(noResult: true);
    });
  }

  // ─────────────────────────────────────────────────────────
  // PINS
  // ─────────────────────────────────────────────────────────

  /// 핀 추가 → 생성된 id 반환. uuid가 없으면 자동 생성.
  static Future<int> insertPin(Pin pin) async {
    final database = await db;
    final pinWithUuid = pin.uuid.isEmpty
        ? pin.copyWith(uuid: _uuidGen.v4())
        : pin;
    return database.insert('pins', pinWithUuid.toMap());
  }

  /// 특정 러닝(run)에 속한 핀들 조회.
  ///
  /// 인자 이름은 호환성 위해 routeId지만 의미는 run의 id.
  static Future<List<Pin>> getPins(int runId) async {
    final database = await db;
    final rows = await database.query(
      'pins',
      where: 'run_id = ?',
      whereArgs: [runId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Pin.fromMap).toList();
  }

  static Future<Pin?> getPinByUuid(String uuid) async {
    final database = await db;
    final rows = await database.query(
      'pins',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Pin.fromMap(rows.first);
  }

  static Future<void> updatePin(Pin pin) async {
    if (pin.id == null) {
      throw ArgumentError('Cannot update a pin without id');
    }
    final database = await db;
    await database.update(
      'pins',
      pin.toMap(),
      where: 'id = ?',
      whereArgs: [pin.id],
    );
  }

  static Future<void> deletePin(int pinId) async {
    final database = await db;
    await database.delete('pins', where: 'id = ?', whereArgs: [pinId]);
  }

  static Future<int> upsertPinFromCloud(Pin pin) async {
    final database = await db;
    final existing = await getPinByUuid(pin.uuid);
    if (existing == null) {
      final map = pin.toMap()..remove('id');
      return database.insert('pins', map);
    } else {
      final merged = pin.copyWith(id: existing.id);
      await database.update(
        'pins',
        merged.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return existing.id!;
    }
  }

  // ─────────────────────────────────────────────────────────
  // 타임라인용 — 모든 핀 + 여정 정보 일괄 조회
  // ─────────────────────────────────────────────────────────

  /// 모든 핀과 그 핀이 속한 여정의 일부 정보를 한 번에 조회.
  ///
  /// Picture Timeline / Memo Timeline 화면에서 N+1 쿼리 회피용.
  /// 모든 핀 + (있다면) 그 핀이 속한 러닝의 정보를 한 번에 조회.
  ///
  /// **MVP 변경 (v5)**: 핀이 독립 엔티티라 LEFT JOIN 사용 — 러닝에 속하지 않은
  /// 일반 핀도 모두 포함. 러닝 정보는 nullable로 들어옴.
  ///
  /// Picture Timeline / Memo Timeline 화면에서 N+1 쿼리 회피용.
  ///
  /// 정렬: 핀의 createdAt 내림차순 (최신 순)
  static Future<List<Map<String, dynamic>>> getAllPinsWithRoute({
    String? userId,
    bool photoOnly = false,
    bool memoOnly = false,
  }) async {
    final database = await db;
    final whereClauses = <String>[];
    final args = <Object>[];

    if (userId != null) {
      // pins.user_id 우선, fallback으로 r.user_id (마이그레이션 데이터 호환)
      whereClauses.add('(p.user_id = ? OR r.user_id = ?)');
      args.add(userId);
      args.add(userId);
    }
    if (photoOnly) {
      whereClauses.add('(p.photo_path IS NOT NULL OR p.photo_url IS NOT NULL)');
    }
    if (memoOnly) {
      whereClauses.add("p.memo IS NOT NULL AND p.memo != ''");
    }

    final whereSQL = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';

    final rows = await database.rawQuery('''
      SELECT
        p.id, p.uuid, p.run_id, p.user_id, p.lat, p.lng, p.category,
        p.photo_path, p.photo_url, p.photo_storage_path,
        p.memo, p.created_at,
        r.title AS route_title,
        r.started_at AS route_started_at
      FROM pins p
      LEFT JOIN routes r ON r.id = p.run_id
      $whereSQL
      ORDER BY p.created_at DESC
    ''', args);

    return rows;
  }

  // ─────────────────────────────────────────────────────────
  // 새 UUID 생성 헬퍼 (외부에서 호출 가능)
  // ─────────────────────────────────────────────────────────

  static String generateUuid() => _uuidGen.v4();

  // ─────────────────────────────────────────────────────────
  // 지도 오버레이용 — 모든 여정의 점을 일괄 조회
  // ─────────────────────────────────────────────────────────

  /// 사용자의 모든 종료된 여정의 점들을 routeId별로 묶어 반환.
  ///
  /// HomeScreen이 "지나간 길" 표시할 때 사용. 진행 중 여정은 별도로
  /// 그리니까 제외 (ended_at IS NOT NULL).
  ///
  /// N+1 회피를 위해 한 번의 JOIN 쿼리로 가져옴. 점이 매우 많아질 수 있으니
  /// (수만 개) 메모리 부담 주의 — MVP 범위에선 OK.
  static Future<Map<int, List<RoutePoint>>> getCompletedRoutePoints(
    String? userId,
  ) async {
    final database = await db;
    final args = <Object>[];
    String userClause = '';
    if (userId != null) {
      userClause = 'AND r.user_id = ?';
      args.add(userId);
    }

    final rows = await database.rawQuery('''
      SELECT
        rp.id, rp.route_id, rp.lat, rp.lng, rp.time
      FROM route_points rp
      INNER JOIN routes r ON r.id = rp.route_id
      WHERE r.ended_at IS NOT NULL
        $userClause
      ORDER BY rp.route_id ASC, rp.time ASC
    ''', args);

    final grouped = <int, List<RoutePoint>>{};
    for (final row in rows) {
      final point = RoutePoint.fromMap(row);
      grouped.putIfAbsent(point.routeId, () => []).add(point);
    }
    return grouped;
  }

  // ─────────────────────────────────────────────────────────
  // DAY TRACKS — 포그라운드 자동 추적
  // ─────────────────────────────────────────────────────────

  /// GPS 점 하나를 day_tracks에 저장.
  static Future<void> insertDayTrackPoint({
    required String dayId,
    required String? userId,
    required double lat,
    required double lng,
  }) async {
    final database = await db;
    await database.insert('day_tracks', {
      'day_id': dayId,
      'user_id': userId,
      'lat': lat,
      'lng': lng,
      'time': DateTime.now().toIso8601String(),
    });
  }

  /// 이 기기에 해당 dayId의 로컬 기록이 이미 있는지 확인.
  /// (풀 다운로드 시 중복 삽입 방지용 — 있으면 이 기기가 그날의 "출처"이므로 건너뜀)
  static Future<bool> hasDayTrack(String dayId, {String? userId}) async {
    final database = await db;
    final where = userId != null
        ? 'day_id = ? AND (user_id = ? OR user_id IS NULL)'
        : 'day_id = ?';
    final args = userId != null ? [dayId, userId] : [dayId];
    final rows = await database.query(
      'day_tracks',
      columns: ['1'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 클라우드에서 받아온 day_track 점들을 로컬에 일괄 삽입.
  /// (다른 기기에서 기록된 점들을 병합할 때 사용 — 시간 정보는 폴리라인에 없어서 근사치로 채움)
  static Future<void> bulkInsertDayTrackPoints({
    required String dayId,
    required String? userId,
    required List<({double lat, double lng})> points,
  }) async {
    if (points.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    final baseTime = DateTime.now();
    for (final p in points) {
      batch.insert('day_tracks', {
        'day_id': dayId,
        'user_id': userId,
        'lat': p.lat,
        'lng': p.lng,
        'time': baseTime.toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  /// 최근 N일간의 day_tracks를 dayId별로 묶어 반환.
  static Future<Map<String, List<({double lat, double lng})>>>
  getDayTrackPoints({String? userId, int days = 7}) async {
    final database = await db;

    final now = DateTime.now();
    final dayIds = List.generate(days, (i) {
      final d = now.subtract(Duration(days: i));
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd';
    });

    final placeholders = dayIds.map((_) => '?').join(', ');
    final args = <Object>[...dayIds];
    String userClause = '';
    if (userId != null) {
      userClause = 'AND (user_id = ? OR user_id IS NULL)';
      args.add(userId);
    }

    final rows = await database.rawQuery(
      'SELECT day_id, lat, lng FROM day_tracks '
      'WHERE day_id IN ($placeholders) $userClause '
      'ORDER BY day_id DESC, time ASC',
      args,
    );

    final grouped = <String, List<({double lat, double lng})>>{};
    for (final row in rows) {
      final dayId = row['day_id'] as String;
      final pt = (
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
      );
      grouped.putIfAbsent(dayId, () => []).add(pt);
    }
    return grouped;
  }

  /// 특정 날(dayId)의 모든 GPS 점을 시간순으로 반환.
  /// (클라우드 업로드/폴리라인 인코딩용 — [getDayTrackPoints]와 달리 단일 날짜만, 원본 좌표 그대로)
  static Future<List<({double lat, double lng})>> getDayTrackRawPoints(
    String dayId, {
    String? userId,
  }) async {
    final database = await db;
    final where = userId != null
        ? 'day_id = ? AND (user_id = ? OR user_id IS NULL)'
        : 'day_id = ?';
    final args = userId != null ? [dayId, userId] : [dayId];

    final rows = await database.query(
      'day_tracks',
      columns: ['lat', 'lng'],
      where: where,
      whereArgs: args,
      orderBy: 'time ASC',
    );
    return [
      for (final row in rows)
        (lat: (row['lat'] as num).toDouble(), lng: (row['lng'] as num).toDouble()),
    ];
  }

  /// 특정 날의 day_tracks 삭제.
  static Future<void> deleteDayTrack(String dayId, {String? userId}) async {
    final database = await db;
    await database.delete(
      'day_tracks',
      where: userId != null ? 'day_id = ? AND user_id = ?' : 'day_id = ?',
      whereArgs: userId != null ? [dayId, userId] : [dayId],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 통계 — Profile 화면용
  // ─────────────────────────────────────────────────────────

  /// 사용자의 누적 통계: 여정 수, 총 거리(m), 총 핀 수.
  ///
  /// 단일 SQL 호출로 가져와 N+1 회피.
  /// userId가 null이면 전체(개발용 fallback).
  static Future<UserStats> getUserStats(String? userId) async {
    final database = await db;
    final args = <Object>[];
    final whereSQL = userId == null ? '' : 'WHERE user_id = ?';
    if (userId != null) args.add(userId);

    final routeRows = await database.rawQuery('''
      SELECT
        COUNT(*) AS route_count,
        COALESCE(SUM(distance), 0) AS total_distance
      FROM routes
      $whereSQL
    ''', args);

    final pinRows = await database.rawQuery('''
      SELECT COUNT(*) AS pin_count
      FROM pins p
      INNER JOIN routes r ON r.id = p.route_id
      ${userId == null ? '' : 'WHERE r.user_id = ?'}
    ''', args);

    return UserStats(
      routeCount: (routeRows.first['route_count'] as int?) ?? 0,
      totalDistanceMeters: ((routeRows.first['total_distance'] as num?) ?? 0)
          .toDouble(),
      pinCount: (pinRows.first['pin_count'] as int?) ?? 0,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 유틸
  // ─────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final database = await db;
    await database.delete('pins');
    await database.delete('route_points');
    await database.delete('routes');
    await database.delete('sync_queue');
  }

  static String _defaultTitle(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}.${two(t.month)}.${two(t.day)} 여정';
  }
}

/// 사용자 누적 통계 — Profile 화면 표시용.
class UserStats {
  final int routeCount;
  final double totalDistanceMeters;
  final int pinCount;

  const UserStats({
    required this.routeCount,
    required this.totalDistanceMeters,
    required this.pinCount,
  });

  /// "12.34 km" 형태로 포맷.
  String get formattedDistance {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.toStringAsFixed(0)} m';
    }
    return '${(totalDistanceMeters / 1000).toStringAsFixed(2)} km';
  }
}
