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
}
