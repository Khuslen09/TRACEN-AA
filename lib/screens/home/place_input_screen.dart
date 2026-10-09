import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_service.dart';
import '../../services/place_recommend_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import 'place_result_screen.dart';

/// AI 장소 추천 입력 화면 — 혼합 스타일
///
/// 상단: 카테고리 칩 (빠른 선택)
/// 하단: 자유 텍스트 입력 + 인원 선택
class PlaceInputScreen extends StatefulWidget {
  const PlaceInputScreen({super.key});

  @override
  State<PlaceInputScreen> createState() => _PlaceInputScreenState();
}

class _PlaceInputScreenState extends State<PlaceInputScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  final Set<String> _selectedChips = {};
  int _people = 2;
  LatLng? _origin;
  bool _locating = false;
  bool _loading = false;
  PlaceRecommendStage? _stage;

  // 카테고리 칩 정의
  // 카테고리 칩 정의 — 색은 TRACEN 보라 하나로 통일 (무지개색은 산만함)
  static const _categories = [
    _Chip('restaurant', Icons.restaurant_rounded),
    _Chip('cafe', Icons.coffee_rounded),
    _Chip('popup', Icons.store_rounded),
    _Chip('bar', Icons.local_bar_rounded),
    _Chip('park', Icons.park_rounded),
    _Chip('shopping', Icons.shopping_bag_rounded),
    _Chip('culture', Icons.museum_rounded),
    _Chip('convenience', Icons.store_mall_directory_rounded),
  ];

  // 빠른 입력 예시
  List<String> get _suggestions => [
    l10n.sugHip,
    l10n.sugQuiet,
    l10n.sugInsta,
    l10n.sugSpacious,
    l10n.sugView,
    l10n.sugValue,
    l10n.sugTerrace,
    l10n.sug24h,
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
    // 입력할 때마다 하단 버튼 문구("2명 · 카페 추천 받기")가 갱신되도록
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      await LocationService.ensurePermission();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _origin = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.placeCheckLocationPermission)),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _onSearch() async {
    if (_origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.placeLocating)),
      );
      return;
    }
    if (_selectedChips.isEmpty && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.placeNeedInput)),
      );
      return;
    }

    _focusNode.unfocus();
    setState(() {
      _loading = true;
      _stage = PlaceRecommendStage.searching;
    });

    try {
      final result = await PlaceRecommendService.recommend(
        origin: _origin!,
        userInput: _textController.text.trim(),
        chips: _selectedChips.toList(),
        people: _people,
        onStage: (stage) {
          if (mounted) setState(() => _stage = stage);
        },
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        _stage = null;
      });
      final retry = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PlaceResultScreen(recommendation: result, origin: _origin!),
        ),
      );
      // 결과 화면에서 "다시 추천받기"를 누르면 같은 조건으로 바로 재검색
      if (retry == true && mounted) _onSearch();
    } on PlaceRecommendException catch (e) {
      debugPrint('[PlaceInput] 추천 실패: $e');
      _showError(_messageFor(e.kind));
    } catch (e) {
      debugPrint('[PlaceInput] 추천 실패(알 수 없음): $e');
      _showError(l10n.placeErrAi);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _stage = null;
        });
      }
    }
  }

  String _messageFor(PlaceRecommendErrorKind kind) => switch (kind) {
    PlaceRecommendErrorKind.unavailable => l10n.placeErrUnavailable,
    PlaceRecommendErrorKind.busy => l10n.placeErrBusy,
    PlaceRecommendErrorKind.network => l10n.placeErrNetwork,
    PlaceRecommendErrorKind.notEnough => l10n.placeErrFewPlaces,
    PlaceRecommendErrorKind.aiFailed => l10n.placeErrAi,
  };

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.commonRetry,
            textColor: AppColors.primaryLight,
            onPressed: _onSearch,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.placeTitle, style: AppTextStyles.h3),
        centerTitle: true,
      ),
      body: Stack(
        children: [
      GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── 헤더 카드 ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.placeHeroTitle, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                          SizedBox(height: 2),
                          Text(
                            l10n.placeHeroDesc,
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.primary.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // ── 인원 선택 ──
              Row(
                children: [
                  Text(l10n.placeParty, style: AppTextStyles.bodyBold),
                  const Spacer(),
                  _PeopleSelector(
                    value: _people,
                    onChanged: (v) => setState(() => _people = v),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 카테고리 칩 ──
              Text(l10n.placeWhere, style: AppTextStyles.bodyBold),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final selected = _selectedChips.contains(cat.key);
                  return GestureDetector(
                    onTap: _loading ? null : () => setState(() {
                      if (selected) {
                        _selectedChips.remove(cat.key);
                      } else {
                        _selectedChips.add(cat.key);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : context.cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: selected ? AppColors.primary : context.borderColor,
                        ),
                        boxShadow: selected ? AppShadows.primary : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 15, color: selected ? Colors.white : AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            PlaceRecommendService.chipLabel(l10n, cat.key),
                            style: AppTextStyles.small.copyWith(
                              color: selected ? Colors.white : context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── 자유 텍스트 입력 ──
              Text(l10n.placeBeSpecific, style: AppTextStyles.bodyBold),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: context.borderColor),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: l10n.placeInputHint,
                    hintStyle: AppTextStyles.small.copyWith(color: context.textTertiary, height: 1.6),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: AppTextStyles.body,
                ),
              ),

              const SizedBox(height: 12),

              // ── 빠른 입력 제안 ──
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _suggestions.map((s) => GestureDetector(
                    onTap: () {
                      final current = _textController.text;
                      _textController.text = current.isEmpty ? s : '$current $s';
                      _textController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _textController.text.length),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Text(
                        '+ $s',
                        style: AppTextStyles.small.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )).toList(),
                ),
              ),

              SizedBox(height: 28),

              // ── 위치 표시 ──
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _locating
                          ? l10n.placeLocatingShort
                          : _origin != null
                              ? l10n.placeRadius
                              : l10n.placeLocationUnavailable,
                      style: AppTextStyles.small,
                    ),
                  ),
                  if (_locating)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                  else
                    GestureDetector(
                      onTap: _getLocation,
                      child: Text(l10n.placeRefresh, style: AppTextStyles.small.copyWith(color: AppColors.primary)),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // ── 검색 버튼 ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _onSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text(l10n.placeSearching, style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              _selectedChips.isEmpty && _textController.text.isEmpty
                                  ? l10n.placeGetRecs
                                  : l10n.placeGetRecsWith(
                                      _people,
                                      _selectedChips
                                          .map((k) => PlaceRecommendService.chipLabel(l10n, k))
                                          .join(' '),
                                    ),
                              style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
          // ── AI 진행 단계 오버레이 ──
          if (_loading) _RecommendProgressOverlay(stage: _stage),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 서브 위젯
// ─────────────────────────────────────────────────────────────

/// 추천을 기다리는 동안 보여주는 단계 표시 — "주변 검색 → AI 선별".
/// Gemini 응답까지 수 초가 걸리므로 지금 무엇을 하는지 보여줘서 덜 지루하게.
class _RecommendProgressOverlay extends StatelessWidget {
  final PlaceRecommendStage? stage;
  const _RecommendProgressOverlay({required this.stage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = stage ?? PlaceRecommendStage.searching;
    final steps = [
      (PlaceRecommendStage.searching, Icons.travel_explore_rounded, l10n.placeStageSearching),
      (PlaceRecommendStage.choosing, Icons.auto_awesome, l10n.placeStageChoosing),
    ];

    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: context.bgColor.withValues(alpha: 0.86),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                boxShadow: AppShadows.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PulsingSparkle(),
                  const SizedBox(height: 22),
                  for (final (s, icon, label) in steps)
                    _StepRow(
                      icon: icon,
                      label: label,
                      done: s.index < current.index,
                      active: s == current,
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

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final bool active;
  const _StepRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = (done || active) ? AppColors.primary : context.textTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? const Icon(Icons.check_circle_rounded,
                    size: 22, color: AppColors.primary)
                : active
                    ? const Padding(
                        padding: EdgeInsets.all(3),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.body.copyWith(
                color: active ? context.textPrimary : color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

/// 은은하게 숨 쉬는 보라 스파클 아이콘.
class _PulsingSparkle extends StatefulWidget {
  const _PulsingSparkle();

  @override
  State<_PulsingSparkle> createState() => _PulsingSparkleState();
}

class _PulsingSparkleState extends State<_PulsingSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18 + 0.22 * t),
                blurRadius: 12 + 14 * t,
                spreadRadius: 2 * t,
              ),
            ],
          ),
          child: Transform.scale(scale: 0.9 + 0.15 * t, child: child),
        );
      },
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
    );
  }
}

class _PeopleSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PeopleSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _btn(Icons.remove_rounded, () { if (value > 1) onChanged(value - 1); }, context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            AppLocalizations.of(context).peopleCount(value),
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
          ),
        ),
        _btn(Icons.add_rounded, () { if (value < 10) onChanged(value + 1); }, context),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _Chip {
  final String key;
  final IconData icon;
  const _Chip(this.key, this.icon);
}
