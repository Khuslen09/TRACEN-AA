import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';

/// 비밀번호 재설정 화면.
///
/// 흐름:
///   1. 이메일 입력
///   2. "재설정 메일 보내기" 누르면 Firebase가 메일 발송
///   3. 성공 시 같은 화면을 success state로 전환 — 메일함 안내 + "로그인으로"
///
/// 디자인 결정:
///   - 간단한 단일 폼 — UX 단순함 우선
///   - 발송 성공 시 화면 전환 대신 같은 화면을 success view로 — 사용자가 어디로 갔는지 헷갈리지 않음
///   - 보안상 "이 이메일 가입자 없음"은 노출하지 않음 (Firebase가 알아서 처리)
class ForgotPasswordScreen extends StatefulWidget {
  /// 호출 측에서 미리 알고 있는 이메일 (LoginScreen에서 이미 입력했다면 자동 채움)
  final String? prefilledEmail;

  const ForgotPasswordScreen({super.key, this.prefilledEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.prefilledEmail ?? '');
  final _formKey = GlobalKey<FormState>();

  bool _sending = false;
  String? _sentToEmail; // 발송 성공 후 화면 전환용

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '이메일을 입력해주세요';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(s)) return '올바른 이메일 형식이 아니에요';
    return null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _sending = true);

    try {
      await AuthService.sendPasswordResetEmail(email);
      if (mounted) setState(() => _sentToEmail = email);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _sentToEmail == null
              ? _buildFormView()
              : _buildSuccessView(_sentToEmail!),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // 헤더 아이콘
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            Text('비밀번호를 잊으셨나요?', style: AppTextStyles.h1),
            const SizedBox(height: 10),
            Text(
              '가입하신 이메일을 입력하시면\n비밀번호 재설정 링크를 보내드려요.',
              style: AppTextStyles.bodyMuted,
            ),

            const SizedBox(height: 32),

            // 이메일 입력
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('이메일', style: AppTextStyles.smallBold),
            ),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              autofocus: widget.prefilledEmail == null,
              onFieldSubmitted: (_) => _send(),
              validator: _validateEmail,
              decoration: const InputDecoration(
                hintText: 'aa@gmail.com',
                prefixIcon: Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.gray400,
                  size: 20,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 발송 버튼
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.primary,
              ),
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('재설정 메일 보내기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView(String email) {
    return Padding(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 60),

          // 성공 아이콘 (초록 동그라미)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: AppColors.success,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),

          Text('메일을 보냈어요',
              style: AppTextStyles.h1, textAlign: TextAlign.center),
          const SizedBox(height: 12),

          Text(
            email,
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '받은편지함에서 재설정 메일을 확인해주세요.\n메일이 안 보이면 스팸함도 확인해보세요.',
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // 로그인으로 돌아가기
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.primary,
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('로그인 화면으로'),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 다시 보내기 — 메일이 안 도착했을 때
          TextButton(
            onPressed: () => setState(() => _sentToEmail = null),
            child: const Text('다른 이메일로 다시 시도'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
