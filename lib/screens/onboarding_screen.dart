import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'login_screen.dart';

/// 첫 실행 온보딩 — TRACEN의 핵심 기능 4가지를 소개.
///
///   1. 스크래치 지도 — 지나간 길만 보랏빛이 벗겨지는 지도
///   2. 활동 기록 — 러닝·워킹·사이클링 실시간 기록
///   3. 핀 & 공유 — 사진·메모 핀을 카드로 만들어 SNS 공유
///   4. AI 장소 추천 — 원하는 분위기로 주변 장소 추천
///
/// 디자인 결정:
///   - 이미지 에셋 없이 코드로 그린 미니 일러스트 — 앱 실제 화면의 톤
///     (보라 지도 + 베이지 발자취, 보라 카드)을 그대로 축소해 보여준다.
///   - 페이지가 보일 때마다 일러스트 애니메이션이 처음부터 재생된다.
///   - 우상단 "건너뛰기", 마지막 페이지에서만 "시작하기".
///
/// 완료 시 [OnboardingService.markCompleted] → LoginScreen으로 이동.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pageCount = 4;

  List<_OnboardingPageData> _pages(AppLocalizations l10n) => [
    _OnboardingPageData(
      title: l10n.onboarding1Title,
      description: l10n.onboarding1Desc,
      illustration: (active) => _ScratchMapIllustration(active: active),
    ),
    _OnboardingPageData(
      title: l10n.onboarding2Title,
      description: l10n.onboarding2Desc,
      illustration: (active) => _ActivityIllustration(active: active),
    ),
    _OnboardingPageData(
      title: l10n.onboarding3Title,
      description: l10n.onboarding3Desc,
      illustration: (active) => _PinShareIllustration(active: active),
    ),
    _OnboardingPageData(
      title: l10n.onboarding4Title,
      description: l10n.onboarding4Desc,
      illustration: (active) => _AiPickIllustration(active: active),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pageCount - 1;

  Future<void> _finish() async {
    await OnboardingService.markCompleted();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = _pages(l10n);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단: 워드마크 + 건너뛰기 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: Row(
                children: [
                  Text(
                    'TRACEN',
                    style: AppTextStyles.smallBold.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: _isLast ? null : _finish,
                      child: Text(
                        l10n.onboardingSkip,
                        style: AppTextStyles.smallBold.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 본문 슬라이드 ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) =>
                    _OnboardingPage(data: pages[i], active: i == _index),
              ),
            ),

            // ── 인디케이터 + 버튼 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                children: [
                  _PageIndicator(count: pages.length, current: _index),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppShadows.primary,
                      ),
                      child: ElevatedButton(
                        onPressed: _next,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _isLast ? l10n.onboardingStart : l10n.onboardingNext,
                            key: ValueKey(_isLast),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 페이지
// ──────────────────────────────────────────────────────────────

class _OnboardingPageData {
  final String title;
  final String description;
  final Widget Function(bool active) illustration;

  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.illustration,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final bool active;
  const _OnboardingPage({required this.data, required this.active});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 작은 화면(SE 등)에서도 글자가 잘리지 않도록 일러스트 크기를 높이에 맞춤
        final side = math
            .min(constraints.maxWidth - 64, constraints.maxHeight * 0.56)
            .clamp(170.0, 320.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: side,
                height: side,
                child: data.illustration(active),
              ),
              SizedBox(height: side * 0.13),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(
                  height: 1.3,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMuted.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 페이지 인디케이터 — 작은 점들, 현재 페이지는 길쭉한 알약 형태.
class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : context.borderColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 일러스트 공통 — 페이지가 활성화될 때마다 처음부터 재생
// ──────────────────────────────────────────────────────────────

abstract class _AnimatedIllustration extends StatefulWidget {
  final bool active;
  const _AnimatedIllustration({required this.active});

  Duration get duration;

  /// [t]: 0 → 1 진행도
  Widget buildFrame(BuildContext context, double t);

  @override
  State<_AnimatedIllustration> createState() => _AnimatedIllustrationState();
}

class _AnimatedIllustrationState extends State<_AnimatedIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedIllustration old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => widget.buildFrame(context, _c.value),
    );
  }
}

/// [t]를 [begin]~[end] 구간으로 잘라 0~1로 다시 매핑하고 커브 적용.
double _seg(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeOutCubic,
]) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return curve.transform((t - begin) / (end - begin));
}

/// 일러스트 바탕 카드 (둥근 사각형, 은은한 보라 그라데이션).
class _IllustrationFrame extends StatelessWidget {
  final Widget child;
  const _IllustrationFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.22),
                  AppColors.darkSurface,
                ]
              : [AppColors.primaryLight, Colors.white],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// 1. 스크래치 지도
// ──────────────────────────────────────────────────────────────

class _ScratchMapIllustration extends _AnimatedIllustration {
  const _ScratchMapIllustration({required super.active});

  @override
  Duration get duration => const Duration(milliseconds: 2600);

  @override
  Widget buildFrame(BuildContext context, double t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: CustomPaint(
        painter: _ScratchMapPainter(
          progress: _seg(t, 0.1, 1, Curves.easeInOut),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ScratchMapPainter extends CustomPainter {
  final double progress;
  _ScratchMapPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 보라 오버레이가 깔린 지도
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A5FFF), Color(0xFF4B32D6)],
        ).createShader(Offset.zero & size),
    );

    // 도로망 (희미한 선)
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    final minor = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.01;
    for (final f in const [0.22, 0.5, 0.78]) {
      canvas.drawLine(Offset(0, h * f), Offset(w, h * (f - 0.08)), road);
      canvas.drawLine(Offset(w * f, 0), Offset(w * (f + 0.06), h), road);
    }
    for (final f in const [0.1, 0.36, 0.64, 0.9]) {
      canvas.drawLine(Offset(0, h * f), Offset(w, h * f), minor);
      canvas.drawLine(Offset(w * f, 0), Offset(w * f, h), minor);
    }

    // 걸은 길 — 베이지 라인이 그려지며 지도가 "벗겨지는" 효과
    final path = Path()
      ..moveTo(w * 0.14, h * 0.84)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.24, h * 0.58, w * 0.42, h * 0.56)
      ..cubicTo(w * 0.62, h * 0.54, w * 0.52, h * 0.32, w * 0.68, h * 0.28)
      ..cubicTo(w * 0.80, h * 0.25, w * 0.84, h * 0.40, w * 0.86, h * 0.16);

    final metric = path.computeMetrics().first;
    final len = metric.length * progress;
    if (len <= 0) return;
    final drawn = metric.extractPath(0, len);

    // 벗겨진 영역(넓은 반투명) + 실제 경로
    canvas.drawPath(
      drawn,
      Paint()
        ..color = AppColors.trackPath.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..color = AppColors.trackPath
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 현재 위치 점
    final head = metric.getTangentForOffset(len)?.position;
    if (head != null) {
      canvas.drawCircle(
        head,
        w * 0.06,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      canvas.drawCircle(head, w * 0.034, Paint()..color = Colors.white);
      canvas.drawCircle(head, w * 0.022, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(_ScratchMapPainter old) => old.progress != progress;
}

// ──────────────────────────────────────────────────────────────
// 2. 활동 기록
// ──────────────────────────────────────────────────────────────

class _ActivityIllustration extends _AnimatedIllustration {
  const _ActivityIllustration({required super.active});

  @override
  Duration get duration => const Duration(milliseconds: 2200);

  static const _icons = [
    Icons.directions_run_rounded,
    Icons.directions_walk_rounded,
    Icons.directions_bike_rounded,
  ];

  @override
  Widget buildFrame(BuildContext context, double t) {
    final count = _seg(t, 0.05, 0.85);
    final km = 3.21 * count;
    final secs = (1104 * count).round(); // 18:24
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');

    return _IllustrationFrame(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // 활동 종류
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _icons.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Opacity(
                      opacity: _seg(t, 0.05 * i, 0.3 + 0.05 * i),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: i == 0 ? AppColors.primary : context.cardColor,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.sm,
                        ),
                        child: Icon(
                          _icons[i],
                          size: 20,
                          color: i == 0 ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 메트릭 카드
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: km.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            TextSpan(
                              text: ' km',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MiniMetric(icon: Icons.timer_outlined, value: '$mm:$ss'),
                        const SizedBox(width: 16),
                        const _MiniMetric(icon: Icons.speed_rounded, value: "5'44\""),
                      ],
                    ),
                    const Spacer(),
                    // 페이스 그래프
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _SparklinePainter(
                          progress: _seg(t, 0.15, 0.95),
                          color: AppColors.primary,
                        ),
                      ),
                    ),
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

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MiniMetric({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTextStyles.smallBold.copyWith(
            color: context.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final double progress;
  final Color color;
  _SparklinePainter({required this.progress, required this.color});

  static const _values = [
    0.5, 0.62, 0.45, 0.7, 0.66, 0.82, 0.58, 0.74, 0.9, 0.7, 0.8,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path();
    for (var i = 0; i < _values.length; i++) {
      final x = size.width * i / (_values.length - 1);
      final y = size.height * (1 - _values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = size.width * (i - 1) / (_values.length - 1);
        final py = size.height * (1 - _values[i - 1]);
        path.cubicTo((px + x) / 2, py, (px + x) / 2, y, x, y);
      }
    }
    final metric = path.computeMetrics().first;
    final len = metric.length * progress;
    final drawn = metric.extractPath(0, len);

    // 아래 채움
    final end = metric.getTangentForOffset(len)?.position;
    if (end != null) {
      final fill = Path.from(drawn)
        ..lineTo(end.dx, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.progress != progress;
}

// ──────────────────────────────────────────────────────────────
// 3. 핀 & 공유
// ──────────────────────────────────────────────────────────────

class _PinShareIllustration extends _AnimatedIllustration {
  const _PinShareIllustration({required super.active});

  @override
  Duration get duration => const Duration(milliseconds: 2000);

  @override
  Widget buildFrame(BuildContext context, double t) {
    final card = _seg(t, 0, 0.55);
    final pin = _seg(t, 0.35, 0.85, Curves.elasticOut);
    final share = _seg(t, 0.65, 1, Curves.easeOutBack);

    return _IllustrationFrame(
      child: LayoutBuilder(
        builder: (context, c) {
          final cw = c.maxWidth * 0.6;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 공유 카드 (폴라로이드)
              Transform.translate(
                offset: Offset(0, 40 * (1 - card)),
                child: Transform.rotate(
                  angle: -0.07 * card,
                  child: Opacity(
                    opacity: card,
                    child: Container(
                      width: cw,
                      padding: EdgeInsets.fromLTRB(
                        cw * 0.06,
                        cw * 0.06,
                        cw * 0.06,
                        cw * 0.1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppShadows.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: const CustomPaint(
                                painter: _SunsetPainter(),
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                          SizedBox(height: cw * 0.06),
                          Row(
                            children: [
                              Icon(
                                Icons.place_rounded,
                                size: cw * 0.08,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: cw * 0.04,
                                  decoration: BoxDecoration(
                                    color: AppColors.gray200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              SizedBox(width: cw * 0.2),
                            ],
                          ),
                          SizedBox(height: cw * 0.03),
                          Container(
                            width: cw * 0.4,
                            height: cw * 0.035,
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 핀 (위에서 떨어짐)
              Positioned(
                top: c.maxHeight * 0.08 + 30 * (1 - pin),
                right: c.maxWidth * 0.15,
                child: Opacity(
                  opacity: pin.clamp(0.0, 1.0),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: AppShadows.primary,
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // 공유 버튼
              Positioned(
                bottom: c.maxHeight * 0.1,
                left: c.maxWidth * 0.1,
                child: Transform.scale(
                  scale: share,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      boxShadow: AppShadows.md,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: Color(0xFFFF5A79),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 공유 카드 안의 "사진" — 노을 지는 언덕.
class _SunsetPainter extends CustomPainter {
  const _SunsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8E7BFF), Color(0xFFFFB3A7)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.5),
      w * 0.13,
      Paint()..color = const Color(0xFFFFE6B8),
    );
    final back = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.3, h * 0.48, w * 0.6, h * 0.68)
      ..quadraticBezierTo(w * 0.82, h * 0.58, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      back,
      Paint()..color = AppColors.primary.withValues(alpha: 0.75),
    );
    final front = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.45, h * 0.7, w, h * 0.84)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = const Color(0xFF3D2A9E));
  }

  @override
  bool shouldRepaint(_SunsetPainter old) => false;
}

// ──────────────────────────────────────────────────────────────
// 4. AI 장소 추천
// ──────────────────────────────────────────────────────────────

class _AiPickIllustration extends _AnimatedIllustration {
  const _AiPickIllustration({required super.active});

  @override
  Duration get duration => const Duration(milliseconds: 2200);

  static const _icons = [
    Icons.local_cafe_rounded,
    Icons.restaurant_rounded,
    Icons.park_rounded,
  ];
  static const _barWidths = [0.62, 0.48, 0.55];
  static const _ratings = ['4.8', '4.6', '4.7'];

  @override
  Widget buildFrame(BuildContext context, double t) {
    final bubble = _seg(t, 0, 0.35, Curves.easeOutBack);

    return _IllustrationFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          children: [
            // 요청 말풍선
            Transform.scale(
              scale: bubble,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: AppShadows.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    for (final w in const [28.0, 18.0, 36.0])
                      Container(
                        width: w,
                        height: 7,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 추천 카드 3장 — 순서대로 등장
            for (var i = 0; i < 3; i++)
              Expanded(
                child: _AiCard(
                  progress: _seg(t, 0.3 + i * 0.15, 0.7 + i * 0.1),
                  rank: i + 1,
                  icon: _icons[i],
                  barWidth: _barWidths[i],
                  rating: _ratings[i],
                  highlighted: i == 0,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  final double progress;
  final int rank;
  final IconData icon;
  final double barWidth;
  final String rating;
  final bool highlighted;

  const _AiCard({
    required this.progress,
    required this.rank,
    required this.icon,
    required this.barWidth,
    required this.rating,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - progress)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: highlighted ? AppColors.primary : context.borderColor,
              width: highlighted ? 1.5 : 1,
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: barWidth,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 2),
              Text(
                rating,
                style: AppTextStyles.caption.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
