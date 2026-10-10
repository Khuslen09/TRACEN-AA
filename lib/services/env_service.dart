import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경 변수 단일 접근점.
///
/// 모든 API 키는 프로젝트 루트의 `.env` 파일에서 런타임 로드합니다.
///   1. `cp .env.example .env`
///   2. .env 에 본인 키 채우기
///   3. main() 에서 `await Env.load()` 호출 (runApp 전에)
class Env {
  Env._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;

  /// 카카오 로컬 API(REST) — 한국 좌표의 POI(장소명) 검색용.
  static String get kakaoRestApiKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  static bool get hasKakaoKey => kakaoRestApiKey.isNotEmpty;

  /// Google REST API(Places·Gemini)를 http로 직접 부를 때 붙이는 헤더.
  ///
  /// 키에 "iOS 앱" 제한(com.khuslen.tracen)을 걸면 Google은 이 헤더로 요청
  /// 출처를 확인한다 — 네이티브 Maps SDK는 알아서 보내지만 Dart http는 안
  /// 보내서, 없으면 제한된 키로 부른 REST 요청이 403으로 막힌다.
  /// Android는 아직 키 제한을 안 걸어서 비워둠.
  static Map<String, String> get googleApiHeaders => Platform.isIOS
      ? const {'X-Ios-Bundle-Identifier': 'com.khuslen.tracen'}
      : const {};

  /// Meta(Facebook) 앱 ID — 인스타 스토리 공유의 source_application 값.
  /// 2023년부터 인스타가 이 값 없이는 스토리 공유를 거부한다.
  static String get facebookAppId => dotenv.env['FACEBOOK_APP_ID'] ?? '';
}
