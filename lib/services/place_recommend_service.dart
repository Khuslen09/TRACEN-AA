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

/// AI 장소 추천 서비스.
/// Claude → Gemini 1.5 Flash로 교체 (무료, 하루 1500회)
class PlaceRecommendService {
  PlaceRecommendService._();

  static const _placesEndpoint =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  // Gemini endpoint (API 키는 쿼리 파라미터로 전달)
  static const _geminiModel = 'gemini-2.5-flash-lite';
  static String get _geminiEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=${Env.geminiApiKey}';

  static const _chipToType = {
    '맛집': 'restaurant',
    '카페': 'cafe',
    '팝업스토어': 'store',
    '술집': 'bar',
    '공원': 'park',
    '쇼핑': 'shopping_mall',
    '문화': 'museum',
    '편의점': 'convenience_store',
  };

  static Future<PlaceRecommendation> recommend({
    required LatLng origin,
    required String userInput,
    required List<String> chips,
    required int people,
  }) async {
    if (!Env.hasGeminiKey) {
      throw 'AI 기능을 쓰려면 .env에 GEMINI_API_KEY가 필요해요.\n'
          'aistudio.google.com 에서 무료로 발급받을 수 있어요.';
    }

    final candidates = await _searchCandidates(origin, chips);
    if (candidates.length < 2) {
      throw '주변에 추천할 장소가 충분하지 않아요. (검색된 후보: ${candidates.length}개)\n'
          'Places API 활성화 / 결제 계정 / 위치를 확인해주세요.';
    }

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
    if (key.isEmpty) throw 'Google Maps API 키가 없어요. (.env 확인)';

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
        'language': 'ko',
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

  static String _statusToMessage(String? status) {
    switch (status) {
      case 'REQUEST_DENIED':
        return 'Places API가 거부됐어요.\n'
            'Google Cloud에서 "Places API"를 활성화하고, '
            'API 키 제한에 Places를 추가했는지 확인해주세요.';
      case 'OVER_QUERY_LIMIT':
        return 'API 사용 한도를 초과했어요. 결제 계정을 확인해주세요.';
      case 'INVALID_REQUEST':
        return '검색 요청이 잘못됐어요. 위치 정보를 확인해주세요.';
      default:
        return '장소 검색 실패: $status';
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
          final rating = p.rating > 0 ? ' 평점${p.rating}' : '';
          return '${e.key}. ${p.name} [${p.category}]$rating ${p.address}';
        })
        .join('\n');

    final chipText = chips.isEmpty ? '(없음)' : chips.join(', ');
    final query =
        [chips.join(' '), userInput].where((s) => s.isNotEmpty).join(' ');

    final prompt = '''
당신은 위치 기반 장소 추천 도우미입니다.

사용자 요청:
- 인원: $people명
- 선택한 카테고리: $chipText
- 자유 입력: ${userInput.isEmpty ? '(없음)' : userInput}

아래 후보 장소들 중에서 사용자 요청에 가장 잘 맞는 3~5곳을 골라주세요.

후보 (번호. 이름 [카테고리] 평점 주소):
$candidateText

반드시 아래 JSON 형식으로만 응답하세요. 마크다운 코드블록 없이 JSON만:
{
  "selected": [선택한 후보 번호 배열],
  "summary": "전체 추천에 대한 1~2문장 친근한 한국어 코멘트",
  "reasons": ["각 선택 장소의 추천 이유 한 줄 (선택 순서대로, 인원/분위기 반영)"]
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
      throw 'AI 호출 중 네트워크 오류가 났어요: $e';
    }

    debugPrint('[Place] Gemini → HTTP ${res.statusCode}');
    if (res.statusCode != 200) {
      debugPrint('[Place] Gemini 에러 본문: ${res.body}');
      throw 'AI 응답 오류 (${res.statusCode})\n${res.body}';
    }

    final data =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    // Gemini 응답 파싱: candidates[0].content.parts[0].text
    final geminiCandidates = data['candidates'] as List?;
    if (geminiCandidates == null || geminiCandidates.isEmpty) {
      throw 'Gemini 응답에서 내용을 찾지 못했어요.';
    }

    final parts =
        geminiCandidates[0]['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw 'Gemini 응답 구조가 올바르지 않아요.';
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
      throw 'AI 응답을 이해하지 못했어요. 다시 시도해주세요.\n응답: $rawText';
    }

    late final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(cleaned.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      throw 'AI 응답 형식이 올바르지 않아요. 다시 시도해주세요.';
    }

    final indices = (parsed['selected'] as List?)
            ?.map((e) => e is int ? e : int.tryParse('$e') ?? -1)
            .where((i) => i >= 0)
            .toList() ??
        <int>[];
    final summary = parsed['summary'] as String? ?? '추천 장소예요.';
    final reasons = (parsed['reasons'] as List?)?.cast<String>() ?? [];

    if (indices.isEmpty) throw 'AI가 장소를 고르지 못했어요. 다시 시도해주세요.';

    final places = <Place>[];
    for (var i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (idx < 0 || idx >= candidates.length) continue;
      final base = candidates[idx];
      places.add(Place(
        name: base.name,
        position: base.position,
        reason: i < reasons.length ? reasons[i] : '추천 장소예요.',
        category: base.category,
        rating: base.rating,
        address: base.address,
      ));
    }

    if (places.isEmpty) throw '유효한 장소가 부족해요. 다시 시도해주세요.';

    return PlaceRecommendation(
      places: places,
      summary: summary,
      query: query,
    );
  }
}