import '../l10n/generated/app_localizations.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'env_service.dart';

/// 추천된 장소 하나.
class Place {
  final String name;
  final LatLng position;
  final String reason;
  final String category;
  final double rating;
  final String address;

  const Place({
    required this.name,
    required this.position,
    required this.reason,
    required this.category,
    this.rating = 0,
    this.address = '',
  });
}

/// AI 장소 추천 결과.
class PlaceRecommendation {
  final List<Place> places;
  final String summary;
  final String query;

  const PlaceRecommendation({
    required this.places,
    required this.summary,
    required this.query,
  });
}

/// 추천 진행 단계 — 화면이 로딩 중 무엇을 하고 있는지 보여주는 데 사용.
enum PlaceRecommendStage { searching, choosing }

/// 추천 실패 종류 — 화면은 [kind]로 사용자용 문구를 고르고,
/// 개발용 상세 내용([detail])은 로그에만 남긴다. (API 키, HTTP 본문 같은
/// 내부 정보가 사용자 화면에 그대로 노출되지 않도록)
enum PlaceRecommendErrorKind {
  /// API 키 미설정 / 권한 거부 — 사용자가 고칠 수 없는 설정 문제
  unavailable,

  /// 사용량 한도 초과
  busy,

  /// 네트워크 실패 / 타임아웃
  network,

  /// 주변 후보가 부족
  notEnough,

  /// AI 응답을 해석하지 못함 — 다시 시도하면 대개 해결
  aiFailed,
}

class PlaceRecommendException implements Exception {
  final PlaceRecommendErrorKind kind;
  final String detail;
  const PlaceRecommendException(this.kind, [this.detail = '']);

  @override
  String toString() => 'PlaceRecommendException($kind): $detail';
}

/// AI 장소 추천 서비스.
/// 1단계 Google Places로 주변 후보 검색 → 2단계 Gemini가 요청에 맞게 선별.
class PlaceRecommendService {
  PlaceRecommendService._();

  static const _placesEndpoint =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  // Gemini endpoint (API 키는 쿼리 파라미터로 전달)
  static const _geminiModel = 'gemini-2.5-flash-lite';
  static String get _geminiEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=${Env.geminiApiKey}';

  /// 칩 키 → Google Places 타입. (표시 이름은 [chipLabel] 로 현재 언어에 맞게 만든다.)
  static const _chipToType = {
    'restaurant': 'restaurant',
    'cafe': 'cafe',
    'popup': 'store',
    'bar': 'bar',
    'park': 'park',
    'shopping': 'shopping_mall',
    'culture': 'museum',
    'convenience': 'convenience_store',
  };

  static const chipKeys = [
    'restaurant',
    'cafe',
    'popup',
    'bar',
    'park',
    'shopping',
    'culture',
    'convenience',
  ];

  /// 칩 키의 현재 언어 표시 이름.
  static String chipLabel(AppLocalizations l10n, String key) => switch (key) {
    'restaurant' => l10n.chipRestaurant,
    'cafe' => l10n.chipCafe,
    'popup' => l10n.chipPopup,
    'bar' => l10n.chipBar,
    'park' => l10n.chipPark,
    'shopping' => l10n.chipShopping,
    'culture' => l10n.chipCulture,
    'convenience' => l10n.chipConvenience,
    _ => key,
  };

  static Future<PlaceRecommendation> recommend({
    required LatLng origin,
    required String userInput,
    required List<String> chips,
    required int people,
    void Function(PlaceRecommendStage stage)? onStage,
  }) async {
    if (!Env.hasGeminiKey) {
      throw const PlaceRecommendException(
        PlaceRecommendErrorKind.unavailable,
        'GEMINI_API_KEY missing',
      );
    }

    onStage?.call(PlaceRecommendStage.searching);
    final candidates = await _searchCandidates(origin, chips);
    if (candidates.length < 2) {
      throw PlaceRecommendException(
        PlaceRecommendErrorKind.notEnough,
        'candidates=${candidates.length}',
      );
    }

    onStage?.call(PlaceRecommendStage.choosing);
    return _askGemini(
      origin: origin,
      userInput: userInput,
      chips: chips,
      people: people,
      candidates: candidates,
    );
  }

  // ── 1단계: Places 검색 ──

  static Future<List<Place>> _searchCandidates(
    LatLng origin,
    List<String> chips,
  ) async {
    final key = Env.googleMapsApiKey;
    if (key.isEmpty) {
      throw const PlaceRecommendException(
        PlaceRecommendErrorKind.unavailable,
        'GOOGLE_MAPS_API_KEY missing',
      );
    }

    final types = chips.isEmpty
        ? ['restaurant', 'cafe']
        : chips
            .map((c) => _chipToType[c])
            .whereType<String>()
            .toSet()
            .toList();

    debugPrint('[Place] 검색 시작 — 위치=(${origin.latitude}, ${origin.longitude}), '
        '타입=$types');

    final all = <Place>[];
    String? lastErrorStatus;

    for (final type in types.take(3)) {
      final uri = Uri.parse(_placesEndpoint).replace(queryParameters: {
        'location': '${origin.latitude},${origin.longitude}',
        'radius': '2000',
        'type': type,
        'language': Strings.current.localeName,
        'key': key,
      });

      try {
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        debugPrint('[Place] $type → HTTP ${res.statusCode}');

        if (res.statusCode != 200) {
          lastErrorStatus = 'HTTP ${res.statusCode}';
          continue;
        }

        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        debugPrint('[Place] $type → status=$status, '
            '결과=${(data['results'] as List?)?.length ?? 0}개');

        if (status != 'OK' && status != 'ZERO_RESULTS') {
          lastErrorStatus = status;
          final errMsg = data['error_message'] as String?;
          if (errMsg != null) debugPrint('[Place] ⚠️ $type 에러: $errMsg');
          continue;
        }

        for (final r in (data['results'] as List? ?? []).take(10)) {
          final m = r as Map<String, dynamic>;
          final loc = m['geometry']?['location'];
          final name = m['name'] as String?;
          if (loc == null || name == null) continue;
          all.add(Place(
            name: name,
            position: LatLng(
              (loc['lat'] as num).toDouble(),
              (loc['lng'] as num).toDouble(),
            ),
            reason: '',
            category: type,
            rating: (m['rating'] as num?)?.toDouble() ?? 0,
            address: m['vicinity'] as String? ?? '',
          ));
        }
      } catch (e) {
        debugPrint('[Place] $type → 예외: $e');
        lastErrorStatus = '$e';
        continue;
      }
    }

    debugPrint('[Place] 총 후보 ${all.length}개 (중복 제거 전)');

    if (all.isEmpty && lastErrorStatus != null) {
      throw _statusToMessage(lastErrorStatus);
    }

    final seen = <String>{};
    return all.where((p) => seen.add(p.name)).toList();
  }

  static PlaceRecommendException _statusToMessage(String? status) {
    final detail = 'Places status=$status';
    switch (status) {
      case 'REQUEST_DENIED':
        return PlaceRecommendException(PlaceRecommendErrorKind.unavailable, detail);
      case 'OVER_QUERY_LIMIT':
        return PlaceRecommendException(PlaceRecommendErrorKind.busy, detail);
      case 'INVALID_REQUEST':
        return PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, detail);
      default:
        return PlaceRecommendException(PlaceRecommendErrorKind.network, detail);
    }
  }

  // ── 2단계: Gemini ──

  static Future<PlaceRecommendation> _askGemini({
    required LatLng origin,
    required String userInput,
    required List<String> chips,
    required int people,
    required List<Place> candidates,
  }) async {
    final candidateText = candidates
        .asMap()
        .entries
        .map((e) {
          final p = e.value;
          final rating = p.rating > 0 ? ' rating ${p.rating}' : '';
          return '${e.key}. ${p.name} [${p.category}]$rating ${p.address}';
        })
        .join('\n');

    final l10n = Strings.current;
    final chipText = chips.isEmpty
        ? '(none)'
        : chips.map((k) => chipLabel(l10n, k)).join(', ');
    final query = [
      chips.map((k) => chipLabel(l10n, k)).join(' '),
      userInput,
    ].where((s) => s.isNotEmpty).join(' ');
    final language = switch (l10n.localeName) {
      'en' => 'English',
      'mn' => 'Mongolian',
      _ => 'Korean',
    };

    final prompt = '''
You are a location-based place recommendation assistant.

User request:
- Party size: $people
- Selected categories: $chipText
- Free-form input: ${userInput.isEmpty ? '(none)' : userInput}

From the candidate places below, pick the 3 to 5 that best match the request.

Candidates (index. name [category] rating address):
$candidateText

Respond ONLY in the JSON format below, with no markdown code block:
{
  "selected": [array of chosen candidate indices],
  "summary": "a friendly 1-2 sentence comment about the overall recommendation, written in $language",
  "reasons": ["a one-line reason for each chosen place (same order as selected, reflecting party size and mood), written in $language"]
}''';

    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_geminiEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 2048,
                'temperature': 0.7,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw PlaceRecommendException(PlaceRecommendErrorKind.network, 'Gemini: $e');
    }

    debugPrint('[Place] Gemini → HTTP ${res.statusCode}');
    if (res.statusCode != 200) {
      debugPrint('[Place] Gemini 에러 본문: ${res.body}');
      throw PlaceRecommendException(
        res.statusCode == 429
            ? PlaceRecommendErrorKind.busy
            : (res.statusCode == 400 || res.statusCode == 403)
                ? PlaceRecommendErrorKind.unavailable
                : PlaceRecommendErrorKind.aiFailed,
        'Gemini HTTP ${res.statusCode}',
      );
    }

    final data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    // Gemini 응답 파싱: candidates[0].content.parts[0].text
    final geminiCandidates = data['candidates'] as List?;
    if (geminiCandidates == null || geminiCandidates.isEmpty) {
      throw const PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, 'no candidates');
    }

    final parts =
        geminiCandidates[0]['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, 'bad structure');
    }

    final text = parts[0]['text'] as String? ?? '';
    debugPrint('[Place] Gemini text길이=${text.length}자');
    debugPrint('[Place] Gemini 응답: ${text.substring(0, text.length.clamp(0, 200))}');

    return _parse(text, candidates, query);
  }

  static PlaceRecommendation _parse(
    String rawText,
    List<Place> candidates,
    String query,
  ) {
    // 마크다운 코드블록 제거 (```json ... ``` 형태 대응)
    final cleaned = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, 'unparsable: $rawText');
    }

    late final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      throw const PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, 'bad json');
    }

    final indices = (parsed['selected'] as List?)
            ?.map((e) => e is int ? e : int.tryParse('$e') ?? -1)
            .where((i) => i >= 0)
            .toList() ??
        <int>[];
    final summary = parsed['summary'] as String? ?? Strings.current.aiDefaultReason;
    final reasons = (parsed['reasons'] as List?)?.map((e) => '$e').toList() ?? <String>[];

    if (indices.isEmpty) {
      throw const PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, 'no pick');
    }

    final places = <Place>[];
    final usedIdx = <int>{};
    for (var i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (idx < 0 || idx >= candidates.length) continue;
      if (!usedIdx.add(idx)) continue; // AI가 같은 후보를 두 번 고른 경우
      final base = candidates[idx];
      places.add(Place(
        name: base.name,
        position: base.position,
        reason: i < reasons.length ? reasons[i] : Strings.current.aiDefaultReason,
        category: base.category,
        rating: base.rating,
        address: base.address,
      ));
    }

    if (places.isEmpty) {
      throw const PlaceRecommendException(PlaceRecommendErrorKind.aiFailed, 'no valid index');
    }

    return PlaceRecommendation(
      places: places,
      summary: summary,
      query: query,
    );
  }
}