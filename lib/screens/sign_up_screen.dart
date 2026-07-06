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
    if (s.isEmpty) return '이름을 입력해주세요';
    if (s.length < 2) return '이름은 2자 이상이어야 해요';
    return null;
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이메일을 입력해주세요';
    // 간단한 정규식 — Firebase가 더 엄격히 검사함
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(s)) return '올바른 이메일 형식이 아니에요';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return '비밀번호를 입력해주세요';
    if (s.length < 6) return '비밀번호는 6자 이상이어야 해요';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v != _passwordController.text) return '비밀번호가 일치하지 않아요';
    return null;
  }

  // ─────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showSnack('약관에 동의해주세요');
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
      if (mounted) _showSnack('가입 중 오류가 발생했어요', isError: true);
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
                Text('계정 만들기', style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text('몇 가지 정보만 입력하면 끝나요', style: AppTextStyles.bodyMuted),

                const SizedBox(height: 36),

                // 이름
                _Label('이름'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  decoration: const InputDecoration(
                    hintText: '닉네임 또는 이름',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.gray400,
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 이메일
                _Label('이메일'),
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
                _Label('비밀번호'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    hintText: '6자 이상',
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
                _Label('비밀번호 확인'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: _validateConfirm,
                  decoration: InputDecoration(
                    hintText: '한 번 더 입력해주세요',
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
                        : const Text('가입 완료'),
                  ),
                ),

                const SizedBox(height: 16),

                // 로그인으로 돌아가기
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('이미 계정이 있으신가요?', style: AppTextStyles.small),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('로그인'),
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
                    const TextSpan(text: '서비스 '),
                    TextSpan(
                      text: '이용약관',
                      style: AppTextStyles.smallBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: ' 및 '),
                    TextSpan(
                      text: '개인정보처리방침',
                      style: AppTextStyles.smallBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const TextSpan(text: '에 동의합니다'),
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
