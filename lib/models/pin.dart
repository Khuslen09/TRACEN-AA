import 'dart:convert';

import 'pin_category.dart';
import 'place_candidate.dart';

/// 사용자가 지도에 남긴 지점 (사진/메모 + 카테고리).
///
/// **MVP 변경 메모 (DB v5)**: 24시간 백그라운드 추적 도입으로 핀이
/// "여정의 자식"에서 **독립 엔티티**로 승격. 사용자가 언제 어디서든 핀 가능.
/// 러닝 중 만든 핀이면 [runId]가 채워지고, 평소 핀이면 null.
///
/// - [id]: 로컬 SQLite의 INTEGER PRIMARY KEY
/// - [uuid]: 클라우드 동기화용 영구 식별자 (Firestore 문서 ID)
/// - [runId]: 러닝 세션 중 만든 핀이면 그 러닝의 로컬 id (없으면 null = 일반 핀)
/// - [category]: 카테고리 (음식/명소/카페 등) — 마커 색상 결정
/// - [photoPath]: 로컬 파일 경로 (앱 documents 디렉토리)
/// - [photoUrl]: 클라우드 업로드 후 받은 다운로드 URL
/// - [photoStoragePath]: 클라우드 삭제용 Storage 경로
/// - [memo]: 사용자 메모 (선택)
/// - [userId]: 사용자 격리용 (DB 단위에서 user 별 분리)
/// - [placeName]/[placeCity]: 공유 카드용 POI 위치명 — 핀 저장 시 1회만
///   조회해서 캐시(공유 카드를 열 때마다 재조회하지 않음). [placeCandidates]
///   는 그때 같이 받아온 다른 후보들(최대 5개) — 사용자가 나중에 바꿀 수 있게.
class Pin {
  final int? id;
  final String uuid;
  final int? runId; // 러닝 세션 중이면 그 세션 id, 아니면 null
  final String? userId;
  final double lat;
  final double lng;
  final PinCategory category;
  final String? photoPath;
  final String? photoUrl;
  final String? photoStoragePath;
  final String? memo;
  final DateTime createdAt;
  final String? placeName;
  final String? placeCity;
  final List<PlaceCandidate> placeCandidates;

  Pin({
    this.id,
    required this.uuid,
    this.runId,
    this.userId,
    required this.lat,
    required this.lng,
    this.category = PinCategory.general,
    this.photoPath,
    this.photoUrl,
    this.photoStoragePath,
    this.memo,
    required this.createdAt,
    this.placeName,
    this.placeCity,
    this.placeCandidates = const [],
  });

  /// 적어도 사진이나 메모 중 하나는 있어야 의미 있는 핀
  bool get hasContent =>
      (photoPath != null && photoPath!.isNotEmpty) ||
      (photoUrl != null && photoUrl!.isNotEmpty) ||
      (memo != null && memo!.isNotEmpty);

  /// 러닝 중 만든 핀인지
  bool get isFromRun => runId != null;

  static List<PlaceCandidate> _decodeCandidates(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => PlaceCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 손상된 로컬 데이터 — 조용히 빈 리스트로 (CountryOutlineService와
      // 같은 "로컬 JSON은 신뢰하되 안 죽는다" 관례).
      return const [];
    }
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'uuid': uuid,
    'run_id': runId,
    'user_id': userId,
    'lat': lat,
    'lng': lng,
    'category': category.key,
    'photo_path': photoPath,
    'photo_url': photoUrl,
    'photo_storage_path': photoStoragePath,
    'memo': memo,
    'created_at': createdAt.toIso8601String(),
    'place_name': placeName,
    'place_city': placeCity,
    'place_candidates': placeCandidates.isEmpty
        ? null
        : jsonEncode(placeCandidates.map((c) => c.toJson()).toList()),
  };

  factory Pin.fromMap(Map<String, dynamic> map) => Pin(
    id: map['id'] as int?,
    uuid: map['uuid'] as String,
    runId: map['run_id'] as int?,
    userId: map['user_id'] as String?,
    lat: (map['lat'] as num).toDouble(),
    lng: (map['lng'] as num).toDouble(),
    category: PinCategory.fromKey(map['category'] as String?),
    photoPath: map['photo_path'] as String?,
    photoUrl: map['photo_url'] as String?,
    photoStoragePath: map['photo_storage_path'] as String?,
    memo: map['memo'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    placeName: map['place_name'] as String?,
    placeCity: map['place_city'] as String?,
    placeCandidates: _decodeCandidates(map['place_candidates'] as String?),
  );

  Pin copyWith({
    int? id,
    String? uuid,
    int? runId,
    String? userId,
    double? lat,
    double? lng,
    PinCategory? category,
    String? photoPath,
    String? photoUrl,
    String? photoStoragePath,
    String? memo,
    DateTime? createdAt,
    String? placeName,
    String? placeCity,
    List<PlaceCandidate>? placeCandidates,
  }) => Pin(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    runId: runId ?? this.runId,
    userId: userId ?? this.userId,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    category: category ?? this.category,
    photoPath: photoPath ?? this.photoPath,
    photoUrl: photoUrl ?? this.photoUrl,
    photoStoragePath: photoStoragePath ?? this.photoStoragePath,
    memo: memo ?? this.memo,
    createdAt: createdAt ?? this.createdAt,
    placeName: placeName ?? this.placeName,
    placeCity: placeCity ?? this.placeCity,
    placeCandidates: placeCandidates ?? this.placeCandidates,
  );
}
