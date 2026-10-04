import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 구글 맵 마커용 커스텀 dot BitmapDescriptor 생성 유틸.
///
/// 기본 삼각형 핀 대신 깔끔한 원형 dot + 흰 테두리 + 그림자로 만들어
/// 지도 위에서 카테고리 색상이 정확히 보임.
class MarkerBitmapUtil {
  MarkerBitmapUtil._();

  /// 캐시 — 같은 색+크기 마커는 재생성하지 않음.
  static final Map<String, BitmapDescriptor> _cache = {};

  /// [color] 색상의 dot 마커 반환.
  /// [size]: 논리 픽셀 기준 지름 (기본 44)
  static Future<BitmapDescriptor> dotMarker(
    Color color, {
    double size = 44,
  }) async {
    final key = '${color.toARGB32()}_$size';
    if (_cache.containsKey(key)) return _cache[key]!;

    final descriptor = await _buildDot(color, size);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> _buildDot(Color color, double size) async {
    final dpr = 3.0; // 고해상도 렌더링 (레티나 대응)
    final px = (size * dpr).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(px / 2, px / 2);
    final radius = px / 2;

    // 그림자 (반투명 검정)
    canvas.drawCircle(
      center + const Offset(0, 2),
      radius * 0.72,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 흰 테두리
    canvas.drawCircle(center, radius * 0.78, Paint()..color = Colors.white);

    // 카테고리 색 dot
    canvas.drawCircle(center, radius * 0.62, Paint()..color = color);

    final picture = recorder.endRecording();
    final img = await picture.toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// 내 위치 전용 마커 — 안쪽 진한 dot + 바깥 반투명 큰 링.
  ///
  /// 일반 핀과 구별되는 디자인:
  ///   - 일반 카테고리 핀: 작은 dot + 흰 테두리 + 그림자 (정적)
  ///   - 내 위치 마커: 큰 반투명 링 + 안쪽 작은 dot ("지금 여기" 살아있는 느낌)
  ///
  /// 펄스 애니메이션은 Google Maps Marker의 한계로 안 됨 (정적 이미지만 가능).
  /// 대신 큰 외곽 링으로 "여기 있어요" 시각 신호 확실히.
  ///
  /// [color]: 보통 AppColors.primary (보라).
  /// [size]: 전체 마커 한 변 크기 (논리 픽셀).
  static Future<BitmapDescriptor> myLocationMarker(
    Color color, {
    double size = 56,
  }) async {
    final key = 'mylocation_${color.toARGB32()}_$size';
    if (_cache.containsKey(key)) return _cache[key]!;

    final descriptor = await _buildMyLocation(color, size);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> _buildMyLocation(
    Color color,
    double size,
  ) async {
    final dpr = 3.0; // 레티나 대응
    final px = (size * dpr).toInt();
    final center = Offset(px / 2, px / 2);
    final fullRadius = px / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1) 바깥 큰 반투명 링 (전체 영역의 95%)
    //    부드러운 가장자리를 위해 살짝 블러 처리.
    canvas.drawCircle(
      center,
      fullRadius * 0.95,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 2) 중간 진한 링 (전체 50%) — 안쪽 dot 강조
    canvas.drawCircle(
      center,
      fullRadius * 0.50,
      Paint()..color = color.withValues(alpha: 0.45),
    );

    // 3) 흰 외곽선 (안쪽 dot의 흰 테두리)
    canvas.drawCircle(center, fullRadius * 0.34, Paint()..color = Colors.white);

    // 4) 안쪽 진한 보라 dot
    canvas.drawCircle(center, fullRadius * 0.27, Paint()..color = color);

    final picture = recorder.endRecording();
    final img = await picture.toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// 카테고리 아이콘 + 색상을 합친 핀 마커. [dotMarker]와 같은 베이스
  /// (그림자 + 흰 테두리 + 색 원) 위에 흰색 아이콘 글리프를 얹는다.
  static Future<BitmapDescriptor> categoryMarker(
    IconData icon,
    Color color, {
    double size = 44,
  }) async {
    final key =
        'cat_${icon.codePoint}_${icon.fontFamily}_${color.toARGB32()}_$size';
    if (_cache.containsKey(key)) return _cache[key]!;

    final descriptor = await _buildCategoryMarker(icon, color, size);
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> _buildCategoryMarker(
    IconData icon,
    Color color,
    double size,
  ) async {
    final dpr = 3.0;
    final px = (size * dpr).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(px / 2, px / 2);
    final radius = px / 2;

    canvas.drawCircle(
      center + const Offset(0, 2),
      radius * 0.72,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius * 0.85, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius * 0.75, Paint()..color = color);

    // 아이콘 글리프 (흰색, 색 원 안에 중앙 정렬) — 마커 자체가 작아서
    // (size: 10) 색 원 대부분을 채울 만큼 크게 그려야 알아볼 수 있음.
    final textPainter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: radius * 0.75 * 1.3,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(px, px);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// 캐시 비우기 — 색상/아이콘 변경 시 호출.
  static void clearCache() => _cache.clear();
}
