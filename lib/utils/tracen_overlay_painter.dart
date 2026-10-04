import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/tracen_overlay_data.dart';
import '../services/tracen_overlay_service.dart';
import '../theme/app_colors.dart';

/// 촬영 사진 위에 TRACEN 오버레이(날짜/도시/거리 스탬프, 오늘의 경로,
/// 워터마크)를 그리는 순수 Canvas 유틸 — [MarkerBitmapUtil]과 같은
/// PictureRecorder/Canvas 스타일로, 위젯이 아니라 [FilteredPhotoRenderer]
/// (셰이더 패스 다음)와 미리보기 `CustomPainter`가 둘 다 공유해서 쓴다.
class TracenOverlayPainter {
  TracenOverlayPainter._();

  static PictureInfo? _logoPicture;

  /// 로고 SVG를 미리 래스터화해 캐시 — 촬영 화면 진입 시 한 번 호출해두면
  /// 결과 화면에서 바로 쓸 수 있음. 호출 안 해도 [paint]가 필요할 때 그려줄
  /// 그림이 없으면 워터마크만 생략하고 나머지는 정상 동작.
  static Future<void> ensureAssets() async {
    _logoPicture ??= await vg.loadPicture(
      const SvgAssetLoader('assets/icon/tracen_logo.svg'),
      null,
    );
  }

  static void paint(
    Canvas canvas,
    Size size,
    TracenOverlayData data, {
    required bool stamp,
    required bool route,
    required bool watermark,
  }) {
    final unit = size.shortestSide / 1000;
    if (stamp) _paintStamp(canvas, size, unit, data);
    if (route && data.path.length >= 2) {
      _paintRoute(canvas, size, unit, data.path);
    }
    if (watermark && _logoPicture != null) {
      _paintWatermark(canvas, size, unit, _logoPicture!);
    }
  }

  static void _paintStamp(
    Canvas canvas,
    Size size,
    double unit,
    TracenOverlayData data,
  ) {
    final text = TracenOverlayService.buildStampText(data);
    final style = TextStyle(
      color: AppColors.trackPath,
      fontSize: 13 * unit,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.0 * unit,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.5),
          blurRadius: 5 * unit,
          offset: Offset(0, 1 * unit),
        ),
      ],
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final margin = 24 * unit;
    tp.paint(
      canvas,
      Offset(size.width - tp.width - margin, size.height - tp.height - margin),
    );
  }

  static void _paintRoute(
    Canvas canvas,
    Size size,
    double unit,
    List<({double lat, double lng})> path,
  ) {
    var minLat = path.first.lat, maxLat = path.first.lat;
    var minLng = path.first.lng, maxLng = path.first.lng;
    for (final p in path) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    // 평면(등장방형) 투영 — 지도 배경 없이 선 모양만 필요하므로 이 정도
    // 근사로 충분. 위도로 경도 폭을 보정해 종횡비가 덜 왜곡되게 함.
    final lat0Rad = (minLat + maxLat) / 2 * (math.pi / 180);
    final cosLat0 = math.cos(lat0Rad).abs().clamp(0.2, 1.0);
    final projected = [
      for (final p in path) Offset(p.lng * cosLat0, -p.lat),
    ];

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

    final margin = 24 * unit;
    final boxSize = size.shortestSide * 0.22;
    final rect = Rect.fromLTWH(
      size.width - boxSize - margin,
      margin,
      boxSize,
      boxSize,
    );
    final pad = boxSize * 0.18;
    final scale = math.min(
      (rect.width - 2 * pad) / spanX,
      (rect.height - 2 * pad) / spanY,
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
        ..color = AppColors.trackPath.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      screenPts.last,
      3 * unit,
      Paint()..color = AppColors.trackPath,
    );
  }

  static void _paintWatermark(
    Canvas canvas,
    Size size,
    double unit,
    PictureInfo logo,
  ) {
    final targetWidth = size.shortestSide * 0.12;
    final scale = logo.size.width <= 0 ? 1.0 : targetWidth / logo.size.width;
    final margin = 24 * unit;

    canvas.save();
    canvas.translate(margin, size.height - margin - logo.size.height * scale);
    canvas.scale(scale);
    // 로고를 흰색으로 리컬러(srcIn) 후, 바깥 레이어에서 전체 70% 투명도.
    canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.7));
    canvas.saveLayer(
      null,
      Paint()..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn),
    );
    canvas.drawPicture(logo.picture);
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }
}
