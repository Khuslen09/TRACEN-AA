import 'dart:io';

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
/// [share]가 false면(인스타 미설치 / `.env`에 FACEBOOK_APP_ID 없음) 호출 측이
/// [shareToApp] → 공유 시트 순으로 폴백한다.
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

  /// 인스타 앱으로 일반 이미지 공유 — 인스타가 피드/스토리/릴스/메시지
  /// 선택 화면을 띄운다(Android 전용, 앱 ID 불필요). iOS는 다른 앱의 공유
  /// 확장을 직접 호출할 수 없어 false — 호출 측이 공유 시트를 연다.
  static Future<bool> shareToApp(String path) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('shareToApp', {'path': path}) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('인스타 공유 실패: $e');
      return false;
    }
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
