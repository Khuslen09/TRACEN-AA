import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// BuildContext가 없는 서비스/모델 계층에서 현재 앱 언어의 번역에 접근하기 위한 홀더.
///
/// TracenApp의 MaterialApp.builder가 로케일이 바뀔 때마다 [update]를 호출한다.
/// 화면(위젯)에서는 그냥 `AppLocalizations.of(context)`를 쓰면 된다.
class Strings {
  Strings._();

  static AppLocalizations? _current;

  static AppLocalizations get current =>
      _current ?? lookupAppLocalizations(const Locale('ko'));

  static void update(AppLocalizations l10n) => _current = l10n;
}
