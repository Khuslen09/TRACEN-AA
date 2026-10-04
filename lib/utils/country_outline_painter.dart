import 'package:flutter/material.dart';

import '../models/country_outline.dart';
import 'map_projection.dart';

/// 나라 외곽선(선 하나) + 핀 위치(점 하나)를 그리는 [CustomPainter].
/// 해상도 독립 스케일 관례(`unit = shortestSide/N`)를 따르는, 공유 카드의
/// "지도" 스티커로 재사용 가능한 독립 페인터.
class CountryOutlinePainter extends CustomPainter {
  final CountryOutline country;
  final double pinLat;
  final double pinLng;
  final Color strokeColor;
  final Color pinColor;
  final double padding;

  const CountryOutlinePainter({
    required this.country,
    required this.pinLat,
    required this.pinLng,
    required this.strokeColor,
    required this.pinColor,
    this.padding = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final unit = size.shortestSide / 100;
    final fit = fitBBoxToSize(country.bbox, size, padding: padding);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * unit
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = strokeColor;

    for (final ring in country.rings) {
      if (ring.length < 2) continue;
      final path = Path();
      final first = fit.applyLonLat(ring.first.lon, ring.first.lat);
      path.moveTo(first.dx, first.dy);
      for (final p in ring.skip(1)) {
        final screen = fit.applyLonLat(p.lon, p.lat);
        path.lineTo(screen.dx, screen.dy);
      }
      path.close();
      canvas.drawPath(path, strokePaint);
    }

    final pin = fit.applyLonLat(pinLng, pinLat);
    canvas.drawCircle(
      pin,
      8 * unit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * unit
        ..color = pinColor.withValues(alpha: 0.45),
    );
    canvas.drawCircle(pin, 3.4 * unit, Paint()..color = pinColor);
  }

  @override
  bool shouldRepaint(covariant CountryOutlinePainter oldDelegate) {
    return oldDelegate.country.iso != country.iso ||
        oldDelegate.pinLat != pinLat ||
        oldDelegate.pinLng != pinLng ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.pinColor != pinColor;
  }
}
