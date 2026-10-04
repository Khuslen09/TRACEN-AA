import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// 핀 공유 카드의 나라 외곽선 지도용 — Web Mercator 투영 + bbox를 주어진
/// [Size] 안에 비율 유지하며 맞추는 순수 Dart 수학. Flutter 위젯/페인터에
/// 의존하지 않아 바로 단위 테스트 가능 (`map_projection_test.dart`).

const double _degToRad = math.pi / 180;

/// 위도를 ±85.05°(표준 Web Mercator 한계)로 clamp — 극지방 근처에서
/// `tan`이 발산하는 것을 막는다. 나라 외곽선 데이터엔 보통 해당 없음
/// (남극 등 일부 예외), 방어적으로만 적용.
const double kMercatorLatLimit = 85.05112878;

/// `(x, y) = (lon·π/180, ln(tan(π/4 + lat·π/360)))` — x/y 둘 다 "라디안과
/// 같은 스케일"이라, 이후 단일 scale factor로 늘리면 종횡비가 그대로 보존됨.
/// y는 위도가 커질수록(북쪽) 커짐 — 화면 좌표로 바꿀 땐 [MapFit.apply]가 뒤집는다.
Offset mercatorProject(double lonDeg, double latDeg) {
  final lat = latDeg.clamp(-kMercatorLatLimit, kMercatorLatLimit);
  final x = lonDeg * _degToRad;
  final y = math.log(math.tan(math.pi / 4 + lat * _degToRad / 2));
  return Offset(x, y);
}

/// bbox를 [target] 크기 안에 [padding]을 두고 비율 유지하며 맞추는 변환.
/// 가로로 긴 나라(몽골 등)와 세로로 긴 나라(한국 등) 모두 짧은 변 기준으로
/// 자연스럽게 들어맞음(= `min(scaleX, scaleY)`).
class MapFit {
  final double scale;
  final double centerX;
  final double centerY;
  final Size target;

  const MapFit({
    required this.scale,
    required this.centerX,
    required this.centerY,
    required this.target,
  });

  /// 이미 [mercatorProject]로 투영된 평면 좌표 → 화면 좌표.
  Offset apply(Offset projected) {
    return Offset(
      target.width / 2 + (projected.dx - centerX) * scale,
      // y는 위도 증가 = 북쪽 = 화면에선 "위"(작은 y) 여야 하므로 부호 반전.
      target.height / 2 - (projected.dy - centerY) * scale,
    );
  }

  /// lon/lat 쌍을 한 번에 화면 좌표로.
  Offset applyLonLat(double lonDeg, double latDeg) => apply(mercatorProject(lonDeg, latDeg));
}

/// [minLon, minLat, maxLon, maxLat] bbox를 [target] 안에 맞추는 [MapFit]을 계산.
/// bbox가 선(면적 0)이거나 너무 작으면 1.0 scale로 안전하게 폴백.
MapFit fitBBoxToSize(
  List<double> bbox,
  Size target, {
  double padding = 0,
}) {
  final pMin = mercatorProject(bbox[0], bbox[1]);
  final pMax = mercatorProject(bbox[2], bbox[3]);

  final spanX = (pMax.dx - pMin.dx).abs();
  final spanY = (pMax.dy - pMin.dy).abs();
  final availW = math.max(1.0, target.width - 2 * padding);
  final availH = math.max(1.0, target.height - 2 * padding);

  double scale;
  if (spanX < 1e-9 && spanY < 1e-9) {
    scale = 1.0;
  } else if (spanX < 1e-9) {
    scale = availH / spanY;
  } else if (spanY < 1e-9) {
    scale = availW / spanX;
  } else {
    scale = math.min(availW / spanX, availH / spanY);
  }

  return MapFit(
    scale: scale,
    centerX: (pMin.dx + pMax.dx) / 2,
    centerY: (pMin.dy + pMax.dy) / 2,
    target: target,
  );
}
