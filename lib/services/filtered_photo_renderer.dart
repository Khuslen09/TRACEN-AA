import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Canvas, Paint, Rect, Size;
import 'package:image/image.dart' as img;

import '../models/camera_filter.dart';
import '../models/capture_ratio.dart';
import '../models/tracen_overlay_data.dart';
import '../utils/tracen_overlay_painter.dart';
import 'lut_shader_service.dart';
import 'photo_storage.dart';

/// 결과 화면의 오버레이 토글 3개. 전부 기본 켜짐.
class OverlayToggles {
  final bool stamp;
  final bool route;
  final bool watermark;

  const OverlayToggles({
    this.stamp = true,
    this.route = true,
    this.watermark = true,
  });

  static const none = OverlayToggles(stamp: false, route: false, watermark: false);
}

/// 촬영된 사진에 LUT 필터 + TRACEN 오버레이를 원본 해상도로 합성해 저장하는
/// 최종 내보내기 파이프라인.
///
/// UI 스레드를 막지 않는 이유: `dart:ui` 렌더링(셰이더로 그리기,
/// `Picture.toImage`)은 루트 isolate에서 picture를 "기록"만 하고 실제 GPU
/// 작업은 raster 스레드가 처리 — 이 과정 자체는 마이크로초 단위. 디코드/
/// 인코딩(`instantiateImageCodec`, `toByteData`)도 비동기. 유일하게 무거운
/// CPU 작업인 JPEG 인코딩만 별도 isolate(`Isolate.run`)에서 수행.
class FilteredPhotoRenderer {
  FilteredPhotoRenderer._();

  static Future<String> render({
    required String sourcePath,
    required TracenFilter filter,
    required double strength,
    required CaptureRatio ratio,
    TracenOverlayData? overlay,
    OverlayToggles toggles = const OverlayToggles(),
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;

    try {
      final cropUv = _centerCropUv(src.width, src.height, ratio.aspect);
      final outW = (src.width * cropUv.width).round().clamp(1, src.width);
      final outH = (src.height * cropUv.height).round().clamp(1, src.height);
      final outSize = Size(outW.toDouble(), outH.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final shader = await LutShaderService.configure(
        filter: filter,
        source: src,
        outSize: outSize,
        srcRectUv: cropUv,
        strength: strength,
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()), Paint()..shader = shader);
      shader.dispose();

      if (overlay != null) {
        TracenOverlayPainter.paint(
          canvas,
          outSize,
          overlay,
          stamp: toggles.stamp,
          route: toggles.route,
          watermark: toggles.watermark,
        );
      }

      final picture = recorder.endRecording();
      ui.Image rendered;
      try {
        rendered = await picture.toImage(outW, outH);
      } finally {
        picture.dispose();
      }

      Uint8List rgba;
      try {
        final byteData = await rendered.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        rgba = byteData!.buffer.asUint8List();
      } finally {
        rendered.dispose();
      }

      final transferable = TransferableTypedData.fromList([rgba]);
      final jpg = await Isolate.run(
        () => _encodeJpeg(transferable, outW, outH),
      );

      return PhotoStorage.persistBytes(jpg, subdir: 'photos/filtered');
    } finally {
      src.dispose();
    }
  }

  static Uint8List _encodeJpeg(
    TransferableTypedData transferable,
    int width,
    int height,
  ) {
    final rgba = transferable.materialize().asUint8List();
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
    );
    return img.encodeJpg(image, quality: 92);
  }

  /// 원본 [srcW]x[srcH] 안에서 [targetAspect](가로/세로)에 맞는 중앙 크롭
  /// 영역을 정규화 UV(0..1)로 반환. 리샘플 없이 크롭만 — 해상도 유지.
  static Rect _centerCropUv(int srcW, int srcH, double targetAspect) {
    final srcAspect = srcW / srcH;
    double w, h, x, y;
    if (srcAspect > targetAspect) {
      // 원본이 타겟보다 더 넓음 — 좌우를 자름.
      h = 1.0;
      w = targetAspect / srcAspect;
      x = (1.0 - w) / 2;
      y = 0.0;
    } else {
      w = 1.0;
      h = srcAspect / targetAspect;
      y = (1.0 - h) / 2;
      x = 0.0;
    }
    return Rect.fromLTWH(x, y, w, h);
  }
}
