import '../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'auth_gate.dart';

/// 회원가입 화면.
///
/// 디자인 결정:
///   - LoginScreen과 동일한 톤 (로고 + 헤딩 + 입력 + 보라 버튼)
///   - 이름 → 이메일 → 비밀번호 → 비밀번호 확인 4단계 폼
///   - 실시간 유효성 검사는 onChanged가 아닌 제출 시 한 번에 (UX: 입력 중 빨간색 거슬림)
///   - 약관 동의 체크박스 — 졸업프로젝트 수준에서 필요. 미체크 시 가입 버튼 비활성.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Validators
  // ─────────────────────────────────────────────

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return l10n.nameRequired;
    if (s.length < 2) return l10n.nameTooShort;
    return null;
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return l10n.emailRequired;
    // 간단한 정규식 — Firebase가 더 엄격히 검사함
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(s)) return l10n.emailInvalid;
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return l10n.passwordRequired;
    if (s.length < 6) return l10n.passwordTooShort;
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v != _passwordController.text) return l10n.passwordMismatch;
    return null;
  }

  // ─────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showSnack(l10n.agreeTermsRequired);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      AuthGate.proceedAfterLogin(context);
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnack(l10n.signUpError, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(l10n.signUpTitle, style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text(l10n.signUpSubtitle, style: AppTextStyles.bodyMuted),

                const SizedBox(height: 36),

                // 이름
                _Label(l10n.nameLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  decoration: InputDecoration(
                    hintText: l10n.nameHint,
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.gray400,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 이메일
                _Label(l10n.commonEmail),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'aa@gmail.com',
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
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    hintText: l10n.passwordHintMin6,
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
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 비밀번호 확인
                _Label(l10n.confirmPasswordLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validateConfirm,
                  decoration: InputDecoration(
                    hintText: l10n.confirmPasswordHint,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.gray400,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.gray400,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 약관 동의
                _TermsCheckbox(
                  checked: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v),
                ),

                const SizedBox(height: 24),

                // 가입 버튼
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _agreedToTerms ? AppShadows.primary : null,
                  ),
                  child: ElevatedButton(
                    onPressed: (_loading || !_agreedToTerms) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: AppColors.gray300,
                      disabledForegroundColor: Colors.white,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(l10n.signUpComplete),
                  ),
                ),

                const SizedBox(height: 16),

                // 로그인으로 돌아가기
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.alreadyHaveAccount, style: AppTextStyles.small),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonLogin),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

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

class _TermsCheckbox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({required this.checked, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: checked ? AppColors.primary : AppColors.gray400,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.small,
                  children: [
                    TextSpan(text: l10n.termsAgreePrefix),
                    TextSpan(
                      text: l10n.termsAgreeTermsLink,
                      style: AppTextStyles.smallBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(text: l10n.termsAgreeMiddle),
                    TextSpan(
                      text: l10n.termsAgreePrivacyLink,
                      style: AppTextStyles.smallBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(text: l10n.termsAgreeSuffix),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
