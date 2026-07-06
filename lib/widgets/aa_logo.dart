import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// AA 브랜드 로고 위젯.
///
/// 모든 화면(Splash, Login, SignUp 등)에서 동일한 SVG 자산을 사용해
/// 브랜드 일관성을 유지합니다.
///
/// 사용 예:
///   ```dart
///   const AALogo(size: 88)         // 큰 로고 (Splash)
///   const AALogo(size: 64)         // 중간 로고 (Login 헤더)
///   const AALogo(size: 48)         // 작은 로고 (앱바 등)
///   ```
class AALogo extends StatelessWidget {
  const AALogo({super.key, this.size = 88, this.semanticsLabel = 'AA'});

  final double size;
  final String semanticsLabel;

  /// pubspec.yaml의 `assets:` 섹션에 등록된 경로.
  static const String _asset = 'assets/icon/tracen_logo.svg';

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        _asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
