import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tracen/l10n/generated/app_localizations.dart';
import 'package:tracen/screens/forgot_password_screen.dart';
import 'package:tracen/screens/login_screen.dart';
import 'package:tracen/screens/onboarding_screen.dart';
import 'package:tracen/screens/sign_up_screen.dart';

Widget _app(Locale locale, Widget home) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  const locales = [Locale('ko'), Locale('en'), Locale('mn')];
  final screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'SignUp': () => const SignUpScreen(),
    'ForgotPassword': () => const ForgotPasswordScreen(),
    'Onboarding': () => const OnboardingScreen(),
  };

  for (final locale in locales) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} renders without overflow in ${locale.languageCode}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(locale, entry.value()));
        await tester.pump(const Duration(milliseconds: 300));

        final e = tester.takeException();
        expect(
          e,
          isNull,
          reason: e is FlutterError ? e.toStringDeep() : '$e',
        );
      });
    }
  }

  test('every locale resolves a non-empty string for a sample of keys', () async {
    for (final locale in locales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.loginWelcome, isNotEmpty);
      expect(l10n.permissionTitle, isNotEmpty);
      expect(l10n.durationHM(1, 5), contains('5'));
      expect(l10n.placesRecommended(3), contains('3'));
      expect(l10n.categoryColorTitle('X'), contains('X'));
    }
    final mn = await AppLocalizations.delegate.load(const Locale('mn'));
    expect(mn.loginWelcome, 'Тавтай морил');
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.loginWelcome, 'Welcome');
    final ko = await AppLocalizations.delegate.load(const Locale('ko'));
    expect(ko.loginWelcome, '환영합니다');
  });
}
