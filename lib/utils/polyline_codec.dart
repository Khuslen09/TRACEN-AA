import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Google Polyline Algorithm encode/decode.
///
/// 참조: https://developers.google.com/maps/documentation/utilities/polylinealgorithmformat
///
/// 사용 목적:
///   - GPS 점 수백 개를 단일 문자열로 압축해 Firestore 저장 비용/용량 절감
///   - 800개 점이 약 5KB 문자열로 압축됨 (배열 형태 대비 ~95% 절감)
///
/// 한계:
///   - 시간 정보(timestamp)는 손실됨. AA MVP는 점별 시간이 필요 없으므로 OK.
///   - 정밀도 5자리 (약 1.1m) — 도보/산책에 충분.
class PolylineCodec {
  PolylineCodec._();

  /// 좌표 리스트 → 인코딩된 문자열.
  static String encode(List<LatLng> points) {
    if (points.isEmpty) return '';

    final result = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final p in points) {
      final lat = (p.latitude * 1e5).round();
      final lng = (p.longitude * 1e5).round();
      _encodeValue(lat - prevLat, result);
      _encodeValue(lng - prevLng, result);
      prevLat = lat;
      prevLng = lng;
    }
    return result.toString();
  }

  /// 인코딩된 문자열 → 좌표 리스트.
  static List<LatLng> decode(String encoded) {
    if (encoded.isEmpty) return const [];

    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;
    final len = encoded.length;

    while (index < len) {
      final dLat = _decodeValue(encoded, index);
      lat += dLat.value;
      index = dLat.nextIndex;

      final dLng = _decodeValue(encoded, index);
      lng += dLng.value;
      index = dLng.nextIndex;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ─────────────────────────────────────────────
  // 내부
  // ─────────────────────────────────────────────

  static void _encodeValue(int value, StringBuffer out) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  static _DecodedValue _decodeValue(String encoded, int index) {
    int result = 0;
    int shift = 0;
    int b;
    int i = index;
    do {
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final v = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return _DecodedValue(value: v, nextIndex: i);
  }
}

class _DecodedValue {
  final int value;
  final int nextIndex;
  _DecodedValue({required this.value, required this.nextIndex});
}
