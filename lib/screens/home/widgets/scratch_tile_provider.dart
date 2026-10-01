import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_colors.dart';

/// 지도 위 보라 톤 오버레이 + 발자취 경로 마스킹 — **타일로 직접 그려서**
/// 지도 렌더링 파이프라인의 일부가 되게 함.
///
/// **목표**: "내가 간 길은 보라 막이 벗겨져서 원래 지도가 보이는" 스크래치
/// 카드 효과를, 팬/줌(그리고 회전) 중에도 지도와 한 치의 오차 없이 붙어있게.
///
/// **이전 방식과의 차이**: 화면 전체를 덮는 별도의 Flutter CustomPaint
/// 레이어로 그리면, 계산이 아무리 빨라도 "네이티브 지도 뷰"와 "Flutter가
/// 합성하는 레이어"가 별개로 합성되는 한계가 있었다. [TileOverlay]로 그리면
/// 위성사진·마커처럼 지도 SDK 자신의 렌더링 파이프라인 안에서 그려지므로
/// 구조적으로 어긋날 수가 없다.
///
/// **구현 방식**: GoogleMap이 화면에 필요한 타일(x, y, zoom)을 요청할 때마다
/// 1. 그 타일의 지리적 영역과 겹치는 발자취 경로만 빠르게 골라내고
///    (경로별 위경도 바운딩 박스로 1차 필터 — 점 하나하나 비교 안 함)
/// 2. 겹치는 게 하나도 없으면 [TileProvider.noTile]을 바로 반환 (제일 흔한
///    경우 — 발자취가 없는 지역은 이미지 생성 자체가 없음)
/// 3. 있으면 256x256(레티나는 더 큰 래스터) 타일 이미지에 보라 막을 깔고
///    경로를 두꺼운 stroke로 그려 `BlendMode.dstOut`으로 구멍을 뚫는다.
///
/// **좌표계**: 표준 웹 메르카토르. zoom z에서 전체 지도는 256 * 2^z 월드
/// 픽셀이고, 타일 (x, y)는 월드 픽셀 [x*256, (x+1)*256) × [y*256, (y+1)*256)
/// 영역을 담당한다 (Google Maps 타일 좌표계 정의 그대로).
class ScratchTileProvider implements TileProvider {
  ScratchTileProvider({this.strokeWidth = 72, this.overlayAlpha = 0.30});

  /// 발자취 stroke 두께 (논리 픽셀). 모든 zoom에서 같은 값을 쓰는 게 맞다 —
  /// 정수 zoom의 타일은 항상 화면에 1:1로 그려지므로, zoom별로 다르게 주면
  /// 오히려 화면상 두께가 zoom마다 달라져 버린다.
  final double strokeWidth;

  /// 보라 막 알파 (0.0~1.0).
  final double overlayAlpha;

  /// 타일을 선명하게 그리기 위한 레티나 배율. 선언하는 타일 크기는 항상
  /// 256(logical)이고, 실제 래스터는 이 배율만큼 더 크게 그려서 반환한다.
  static const int _rasterScale = 2;
  static const int _tileSize = 256;

  List<_ScratchPath> _paths = const [];

  /// 발자취 데이터가 바뀔 때마다 호출. 호출 뒤 지도 쪽에서
  /// `GoogleMapController.clearTileCache`도 같이 불러줘야 화면에 반영된다.
  void updatePaths(Iterable<List<LatLng>> rawPaths) {
    _paths = [
      for (final pts in rawPaths)
        if (pts.length >= 2) _ScratchPath(pts),
    ];
  }

  /// 발자취가 하나도 안 지나가는 타일 전용 — 보라 막만 깔린 이미지.
  /// 모든 "구멍 없는" 타일이 똑같이 생겼으니 한 번만 그려서 재사용한다.
  Uint8List? _blankTileBytes;

  Future<Tile> _blankTile() async {
    final cached = _blankTileBytes;
    if (cached != null) return Tile(_tileSize, _tileSize, cached);

    final raster = _tileSize * _rasterScale;
    final rasterD = raster.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, rasterD, rasterD));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rasterD, rasterD),
      Paint()..color = AppColors.primary.withValues(alpha: overlayAlpha),
    );
    final image = await recorder.endRecording().toImage(raster, raster);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return TileProvider.noTile;

    final data = bytes.buffer.asUint8List();
    _blankTileBytes = data;
    return Tile(_tileSize, _tileSize, data);
  }

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    // 발자취가 하나도 지나가지 않는 타일도 보라 막은 그대로 덮여있어야 함
    // ("아직 안 가본 곳"이 원래 지도로 비쳐 보이면 안 됨) — 그래서 여기서
    // noTile로 건너뛰지 않고 [_blankTile]을 깐다.
    final z = (zoom ?? 0).toDouble();
    final mapSize = _tileSize * math.pow(2, z).toDouble();

    // stroke 두께 절반 + 여유만큼 타일 경계를 확장 — 경로의 중심선이 타일
    // 밖에 있어도 두꺼운 선이 타일 안으로 삐져나오는 경우를 놓치지 않게.
    final margin = strokeWidth / 2 + 4;
    final tileLeft = x * _tileSize - margin;
    final tileRight = (x + 1) * _tileSize + margin;
    final tileTop = y * _tileSize - margin;
    final tileBottom = (y + 1) * _tileSize + margin;

    final hits = <_ScratchPath>[];
    for (final path in _paths) {
      final pxMin = _lngToWorldX(path.west, mapSize);
      final pxMax = _lngToWorldX(path.east, mapSize);
      // 북쪽(위도가 높을수록)일수록 월드 Y가 작다.
      final pyMin = _latToWorldY(path.north, mapSize);
      final pyMax = _latToWorldY(path.south, mapSize);
      final overlaps =
          pxMax >= tileLeft &&
          pxMin <= tileRight &&
          pyMax >= tileTop &&
          pyMin <= tileBottom;
      if (overlaps) hits.add(path);
    }
    if (hits.isEmpty) return _blankTile();

    final raster = _tileSize * _rasterScale;
    final rasterD = raster.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, rasterD, rasterD));

    canvas.saveLayer(Rect.fromLTWH(0, 0, rasterD, rasterD), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, rasterD, rasterD),
      Paint()..color = AppColors.primary.withValues(alpha: overlayAlpha),
    );

    final scratchPaint = Paint()
      ..color = Colors.black // dstOut 모드에선 색은 무관, alpha만 사용
      ..strokeWidth = strokeWidth * _rasterScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.dstOut;

    final originX = x * _tileSize;
    final originY = y * _tileSize;
    for (final path in hits) {
      final p = Path();
      var first = true;
      for (final latLng in path.points) {
        final px =
            (_lngToWorldX(latLng.longitude, mapSize) - originX) *
            _rasterScale;
        final py =
            (_latToWorldY(latLng.latitude, mapSize) - originY) * _rasterScale;
        if (first) {
          p.moveTo(px, py);
          first = false;
        } else {
          p.lineTo(px, py);
        }
      }
      // Canvas가 타일 밖으로 나가는 선분도 알아서 잘라주므로, 타일 안에
      // 들어오는 부분만 미리 잘라낼 필요 없음.
      canvas.drawPath(p, scratchPaint);
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(raster, raster);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return TileProvider.noTile;

    // width/height는 "논리 픽셀" 선언값 — 실제 래스터는 _rasterScale배 더
    // 커서 레티나 화면에서 더 선명하게 보인다(흔한 "@2x 타일" 패턴).
    return Tile(_tileSize, _tileSize, bytes.buffer.asUint8List());
  }

  static double _lngToWorldX(double lng, double mapSize) =>
      (lng + 180) / 360 * mapSize;

  static double _latToWorldY(double lat, double mapSize) {
    final latRad = lat * math.pi / 180;
    final mercN = math.log(math.tan(math.pi / 4 + latRad / 2));
    return (0.5 - mercN / (2 * math.pi)) * mapSize;
  }
}

/// 경로 하나 + 빠른 1차 필터용 위경도 바운딩 박스.
///
/// [points]는 GPS 원본이 아니라 [_smooth]를 거친 값 — 매 타일마다 다시
/// 스무딩하면 낭비라 경로 데이터가 바뀔 때([updatePaths]) 한 번만 계산해
/// 캐싱해둔다. DB에 저장되는 원본 좌표는 건드리지 않고, 화면에 "긋는" 선만
/// 부드럽게 만드는 것.
class _ScratchPath {
  _ScratchPath(List<LatLng> raw)
    : points = _smooth(raw),
      north = raw.map((p) => p.latitude).reduce(math.max),
      south = raw.map((p) => p.latitude).reduce(math.min),
      east = raw.map((p) => p.longitude).reduce(math.max),
      west = raw.map((p) => p.longitude).reduce(math.min);

  final List<LatLng> points;
  final double north;
  final double south;
  final double east;
  final double west;

  /// 단순 이동평균 — GPS 신호가 흔들려서 생기는 작은 지그재그를 완화한다.
  /// 전체적인 경로 모양(큰 꺾임, 코너)은 유지하고 고주파 노이즈만 깎아냄.
  static List<LatLng> _smooth(List<LatLng> raw, {int window = 2}) {
    if (raw.length <= 2) return raw;
    return [
      for (var i = 0; i < raw.length; i++)
        _average(raw, math.max(0, i - window), math.min(raw.length - 1, i + window)),
    ];
  }

  static LatLng _average(List<LatLng> raw, int lo, int hi) {
    var latSum = 0.0;
    var lngSum = 0.0;
    for (var j = lo; j <= hi; j++) {
      latSum += raw[j].latitude;
      lngSum += raw[j].longitude;
    }
    final n = hi - lo + 1;
    return LatLng(latSum / n, lngSum / n);
  }
}
