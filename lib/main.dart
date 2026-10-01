import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'firebase_options.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/strings.dart';
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
    // 지원 언어(ko/en/mn) 날짜 데이터를 모두 초기화.
    await initializeDateFormatting();
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
      child: const TracenApp(),
    ),
  );
}

class TracenApp extends StatefulWidget {
  const TracenApp({super.key});

  @override
  State<TracenApp> createState() => _TracenAppState();
}

class _TracenAppState extends State<TracenApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 프레임 이후 — 시스템 권한 다이얼로그가 UI 위에 안전하게 뜰 수 있는 시점.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrackingService.ensureBackgroundLocation();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 앱에서 위치 권한을 "항상"으로 바꾸고 돌아온 경우 바로 반영.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      TrackingService.ensureBackgroundLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tracen',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.mode,
      locale: localeProvider.locale, // null이면 기기 언어 자동 감지
      builder: (context, child) {
        // 서비스 계층(BuildContext 없음)이 현재 언어의 번역을 쓸 수 있게 갱신.
        Strings.update(AppLocalizations.of(context));
        return child ?? const SizedBox.shrink();
      },
      supportedLocales: LocaleProvider.supportedLocales,
      // "기기 언어 사용"일 때: 기기 언어가 지원 목록(ko/en/mn)에 있으면 그대로,
      // 없는 언어(일본어 등)면 영어로.
      localeResolutionCallback: (deviceLocale, supported) {
        for (final l in supported) {
          if (l.languageCode == deviceLocale?.languageCode) return l;
        }
        return const Locale('en');
      },
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