import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// [ShareCard]를 PNG로 내보내고 공유/저장하는 서비스.
///
/// `RepaintBoundary.toImage(pixelRatio:)`로 캡처해 임시 디렉토리에 쓴다 —
/// `PhotoStorage`(영구 저장)는 안 씀, 이건 공유 한 번 쓰고 버리는 임시
/// 파일이라서. 공유/저장 호출 형태는 `photo_edit_screen.dart`의
/// `_share`/`_save`와 동일(`SharePlus.instance.share`, `Gal.putImage`).
class ShareCardExporter {
  ShareCardExporter._();

  /// [boundaryKey]가 가리키는 [RepaintBoundary]를 PNG로 캡처해 임시 파일로
  /// 저장하고 경로를 반환.
  static Future<String> exportToTempFile(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('ShareCard RepaintBoundary가 아직 렌더되지 않았어요.');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('공유 카드를 PNG로 인코딩하지 못했어요.');
    }

    final bytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/share_card_${DateTime.now().microsecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  static Future<void> shareFile(String path, {Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'image/png')],
        sharePositionOrigin: origin,
      ),
    );
  }

  static Future<void> saveToGallery(String path) async {
    if (!await Gal.hasAccess(toAlbum: false)) {
      await Gal.requestAccess(toAlbum: false);
    }
    await Gal.putImage(path);
  }
}
