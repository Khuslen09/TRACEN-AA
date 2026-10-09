import 'dart:io';

import '../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import '../widgets/tracen_logo.dart';
import 'auth_gate.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// 로그인 화면.
///
/// 디자인 결정:
///   - SplashScreen 톤과 일관된 보라 그라데이션 로고
///   - Email/Password 폼 + 그림자 강조 보라 버튼
///   - Google 로그인, Apple 로그인 (iOS, 가이드라인 4.8)
///   - 가입 화면으로 이동하는 명확한 CTA
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────

  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack(l10n.loginEnterCredentials);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.signInWithEmail(email: email, password: password);
      if (!mounted) return;
      _goToHome();
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack(l10n.loginError, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _loading = true);
    try {
      await AuthService.signInWithGoogle();
      if (!mounted) return;
      _goToHome();
    } on AuthException catch (e) {
      // 사용자가 취소한 경우는 조용히 (에러 메시지로 보여주면 거슬림)
      if (!e.cancelled && mounted) {
        _showSnack(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.googleLoginFailed, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() => _loading = true);
    try {
      await AuthService.signInWithApple();
      if (!mounted) return;
      _goToHome();
    } on AuthException catch (e) {
      if (!e.cancelled && mounted) {
        _showSnack(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.appleLoginFailed, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          // 이미 입력한 이메일이 있으면 자동 채움 — 한 번 더 안 적게
          prefilledEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        ),
      ),
    );
  }

  void _goToHome() {
    AuthGate.proceedAfterLogin(context);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.gray900,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  48,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  Center(child: const TracenLogo(size: 80)),
                  const SizedBox(height: 28),
                  Text(
                    l10n.loginWelcome,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display.copyWith(height: 1.2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMuted,
                  ),

                  const SizedBox(height: 44),

                  // 이메일
                  _Label(l10n.commonEmail),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'tracen@gmail.com',
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.gray400,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 비밀번호
                  _Label(l10n.commonPassword),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleEmailLogin(),
                    decoration: InputDecoration(
                      hintText: l10n.passwordHint,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.gray400,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.gray400,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: Text(l10n.forgotPasswordLink),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 로그인 버튼
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppShadows.primary,
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleEmailLogin,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(l10n.commonLogin),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 구분선
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l10n.commonOr, style: AppTextStyles.small),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Google
                  _SocialButton(
                    label: l10n.continueWithGoogle,
                    icon: Icons.g_mobiledata_rounded,
                    iconColor: const Color(0xFFEA4335),
                    iconSize: 22,
                    imagePath: 'assets/icon/google_logo.png',
                    onPressed: _loading ? null : _handleGoogleLogin,
                  ),
                  // Apple — iOS 전용 (App Store 가이드라인 4.8)
                  if (Platform.isIOS) ...[
                    const SizedBox(height: 10),
                    _SocialButton(
                      label: l10n.continueWithApple,
                      icon: Icons.apple,
                      iconColor: isDark ? Colors.black : Colors.white,
                      iconSize: 24,
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      onPressed: _loading ? null : _handleAppleLogin,
                    ),
                  ],

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l10n.noAccountYet, style: AppTextStyles.small),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: Text(l10n.signUpAction),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub Widgets ─────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: AppTextStyles.smallBold),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final VoidCallback? onPressed;
  final String? imagePath; // 있으면 아이콘 대신 이미지 사용 (Google 로고 등)
  final Color? backgroundColor; // Apple 버튼처럼 브랜드 색이 정해진 경우
  final Color? foregroundColor;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.iconSize = 22,
    this.imagePath,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: backgroundColor ?? context.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: backgroundColor != null
                ? null
                : Border.all(color: context.borderColor, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: imagePath != null
                    ? Image.asset(
                        imagePath!,
                        width: iconSize,
                        height: iconSize,
                        // 로고 로드 실패 시 기본 아이콘으로 폴백
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, color: iconColor, size: iconSize),
                      )
                    : Icon(icon, color: iconColor, size: iconSize),
              ),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: disabled
                        ? AppColors.gray400
                        : (foregroundColor ?? context.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ),
      ),
    );
  }
}
