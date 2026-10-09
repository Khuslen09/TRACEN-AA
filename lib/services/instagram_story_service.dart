import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'env_service.dart';

/// 인스타그램 스토리 편집 화면으로 이미지를 바로 넘긴다 — 네이티브
/// `tracen/instagram_story` 채널(iOS AppDelegate / Android
/// InstagramStoryChannel) 사용.
///
/// - [backgroundPath]: 스토리 배경(9:16 PNG). 없으면 [topColor]→[bottomColor]
///   그라데이션이 배경.
/// - [stickerPath]: 배경 위 스티커(투명 PNG) — 인스타에서 옮기고 크기 조절 가능.
///
/// false면 인스타 미설치이거나 `.env`에 FACEBOOK_APP_ID가 없는 것 — 호출 측이
/// 공유 시트로 폴백한다.
class InstagramStoryService {
  InstagramStoryService._();

  static const _channel = MethodChannel('tracen/instagram_story');

  static Future<bool> share({
    String? backgroundPath,
    String? stickerPath,
    Color? topColor,
    Color? bottomColor,
  }) async {
    final appId = Env.facebookAppId;
    if (appId.isEmpty) return false;
    try {
      final opened = await _channel.invokeMethod<bool>('share', {
        'appId': appId,
        'backgroundPath': ?backgroundPath,
        'stickerPath': ?stickerPath,
        if (topColor != null) 'topColor': _hex(topColor),
        if (bottomColor != null) 'bottomColor': _hex(bottomColor),
      });
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('인스타 스토리 공유 실패: $e');
      return false;
    }
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
