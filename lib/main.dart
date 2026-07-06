import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/env_service.dart';
import 'services/tracking_service.dart';
import 'services/route_db_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'theme/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 (.env) — API 키. 실패해도 앱은 떠야 함.
  try {
    await Env.load();
  } catch (e) {
    debugPrint('[main] .env 로드 실패 (AI 기능 비활성화될 수 있음): $e');
  }

  // 날짜 포맷팅용 로케일 데이터
  try {
    await initializeDateFormatting('ko_KR', null);
    await initializeDateFormatting('en_US', null);
  } catch (e) {
    debugPrint('[main] 로케일 초기화 실패: $e');
  }

  // Firebase — iOS는 네이티브가 먼저 초기화할 수 있어 duplicate-app 가능 → 무시.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') debugPrint('[main] Firebase 실패: $e');
  } catch (e) {
    debugPrint('[main] Firebase 예외: $e');
  }

  // SQLite warm-up
  try {
    await RouteDBService.db;
  } catch (e) {
    debugPrint('[main] SQLite 초기화 실패: $e');
  }

  // 포그라운드 자동 추적 (설정에서 끈 경우 자동 skip)
  try {
    await TrackingService.init();
  } catch (e) {
    debugPrint('[main] TrackingService 초기화 실패: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const AAApp(),
    ),
  );
}

class AAApp extends StatelessWidget {
  const AAApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AA',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      locale: localeProvider.locale, // null이면 기기 언어 자동 감지
      supportedLocales: LocaleProvider.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Platform.isAndroid
          ? const WithForegroundTask(child: SplashScreen())
          : const SplashScreen(),
    );
  }
}