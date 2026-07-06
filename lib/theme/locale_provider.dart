import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 언어(로케일) 관리.
///
/// 지원 언어: 한국어(ko), 영어(en), 몽골어(mn)
/// 기본값: 기기 언어가 지원 목록에 있으면 그걸, 아니면 한국어.
class LocaleProvider extends ChangeNotifier {
  static const _key = 'app_locale';

  static const supportedLocales = [
    Locale('ko'),
    Locale('en'),
    Locale('mn'),
  ];

  Locale? _locale; // null = 기기 언어 자동 감지
  Locale? get locale => _locale;

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _locale = Locale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }

  String labelFor(Locale locale) => switch (locale.languageCode) {
        'ko' => '한국어',
        'en' => 'English',
        'mn' => 'Монгол',
        _ => locale.languageCode,
      };
}
