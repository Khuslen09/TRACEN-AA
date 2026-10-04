import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tracen/l10n/generated/app_localizations.dart';
import 'package:tracen/models/tracen_overlay_data.dart';
import 'package:tracen/screens/camera/camera_filter_controller.dart';
import 'package:tracen/screens/camera/photo_edit_screen.dart';

/// 작은 실제 PNG 파일을 임시 디렉터리에 써서 돌려준다 — `PhotoEditScreen`이
/// `File(sourcePath).readAsBytes()`로 읽어 디코드하므로 진짜 파일이 필요함
/// (메모리상의 `ui.Image`만으로는 부족).
Future<String> _writeTinyPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 60), Paint()..color = Colors.blueGrey);
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 60);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await Directory.systemTemp.createTemp('photo_edit_test');
  final file = File('${dir.path}/source.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file.path;
}

void main() {
  late String sourcePath;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    sourcePath = await _writeTinyPng();
  });

  Widget buildScreen() {
    return MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<CameraFilterController>(
        future: CameraFilterController.load(),
        builder: (context, snapshot) {
          final controller = snapshot.data;
          if (controller == null) return const SizedBox.shrink();
          return PhotoEditScreen(
            sourcePath: sourcePath,
            filterController: controller,
            overlayFuture: Future.value(
              TracenOverlayData(date: DateTime(2026, 10, 4), city: null, distanceMeters: 0, path: const []),
            ),
          );
        },
      ),
    );
  }

  // 명시적으로 요청된 두 크기 — iPhone SE(1세대/2세대/3세대, 가장 작은
  // 화면)와 15 Pro Max(가장 큰 화면)에서 오버플로우가 없는지 확인.
  const sizes = {
    'iPhone SE': Size(375, 667),
    '15 Pro Max': Size(430, 932),
  };

  for (final entry in sizes.entries) {
    testWidgets('${entry.key} 크기에서 오버플로우 없이 렌더', (tester) async {
      tester.view.physicalSize = Size(entry.value.width * 3, entry.value.height * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildScreen());
      await tester.pump(const Duration(milliseconds: 100));
      // 위치 조회 실패(테스트 환경엔 플랫폼 채널 없음) → (0,0) 폴백 +
      // 이미지 디코드 + 나라/위치명 조회(오프라인 자산 + 지오코딩 폴백)가
      // 끝날 시간을 줌 — 실패해도 조용히 넘어가므로 길게 기다릴 필요 없음.
      await tester.pump(const Duration(seconds: 2));

      final e = tester.takeException();
      expect(e, isNull, reason: e is FlutterError ? e.toStringDeep() : '$e');
    });
  }
}
