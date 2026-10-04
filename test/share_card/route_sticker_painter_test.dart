import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/widgets/share_card/route_sticker_painter.dart';

void main() {
  group('RouteStickerPainter', () {
    test('포인트 0개 — 예외 없이 아무 것도 안 그림', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => RouteStickerPainter(path: const [], strokeColor: Colors.white)
            .paint(canvas, const Size(90, 90)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('포인트 1개(2개 미만) — 예외 없이 아무 것도 안 그림', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => RouteStickerPainter(
          path: const [(lat: 37.5, lng: 127.0)],
          strokeColor: Colors.white,
        ).paint(canvas, const Size(90, 90)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('포인트 2개 이상 — 정상적으로 그려짐(예외 없음)', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => RouteStickerPainter(
          path: const [
            (lat: 37.5, lng: 127.0),
            (lat: 37.51, lng: 127.01),
            (lat: 37.52, lng: 127.02),
          ],
          strokeColor: Colors.white,
        ).paint(canvas, const Size(90, 90)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('크기 0 — 예외 없이 아무 것도 안 그림', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(
        () => RouteStickerPainter(
          path: const [(lat: 37.5, lng: 127.0), (lat: 37.51, lng: 127.01)],
          strokeColor: Colors.white,
        ).paint(canvas, Size.zero),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });
  });
}
