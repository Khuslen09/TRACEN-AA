import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 공유 카드의 "경로" 스티커 — 오늘(또는 핀이 찍힌 날)의 GPS 경로를 작은
/// 박스 안에 그린다. `TracenOverlayPainter._paintRoute`의 등장방형 투영 +
/// 코사인 보정 알고리즘을 그대로 포팅한 것 — 카메라 오버레이 파일과
/// 얽히지 않게 `share_card/` 안에 독립적으로 둔다(색상은 고정된
/// `AppColors.trackPath`가 아니라 카드의 잉크 색을 그대로 받음).
///
/// 포인트가 2개 미만이면 아무 것도 안 그림 — `CountryOutlinePainter`가
/// 나라 매칭 안 될 때 빈 채로 두는 것과 같은 패턴(에러 아님).
class RouteStickerPainter extends CustomPainter {
  final List<({double lat, double lng})> path;
  final Color strokeColor;
  final double padding;

  const RouteStickerPainter({
    required this.path,
    required this.strokeColor,
    this.padding = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2 || size.width <= 0 || size.height <= 0) return;
    final unit = size.shortestSide / 100;

    var minLat = path.first.lat, maxLat = path.first.lat;
    var minLng = path.first.lng, maxLng = path.first.lng;
    for (final p in path) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final lat0Rad = (minLat + maxLat) / 2 * (math.pi / 180);
    final cosLat0 = math.cos(lat0Rad).abs().clamp(0.2, 1.0);
    final projected = [for (final p in path) Offset(p.lng * cosLat0, -p.lat)];

    var minX = projected.first.dx, maxX = projected.first.dx;
    var minY = projected.first.dy, maxY = projected.first.dy;
    for (final p in projected) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final spanX = (maxX - minX).abs() < 1e-9 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1e-9 ? 1.0 : maxY - minY;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final scale = math.min(
      (rect.width - 2 * padding) / spanX,
      (rect.height - 2 * padding) / spanY,
    );
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    Offset toScreen(Offset p) => Offset(
      rect.center.dx + (p.dx - cx) * scale,
      rect.center.dy + (p.dy - cy) * scale,
    );

    final screenPts = projected.map(toScreen).toList();
    final routePath = Path()..moveTo(screenPts.first.dx, screenPts.first.dy);
    for (final p in screenPts.skip(1)) {
      routePath.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(
      routePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4 * unit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.drawPath(
      routePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * unit
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = strokeColor.withValues(alpha: 0.9),
    );
    canvas.drawCircle(screenPts.last, 3 * unit, Paint()..color = strokeColor);
  }

  @override
  bool shouldRepaint(covariant RouteStickerPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.strokeColor != strokeColor;
  }
}
