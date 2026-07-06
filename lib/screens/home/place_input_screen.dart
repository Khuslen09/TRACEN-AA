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
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  final Set<String> _selectedChips = {};
  int _people = 2;
  LatLng? _origin;
  bool _locating = false;
  bool _loading = false;

  // 카테고리 칩 정의
  static const _categories = [
    _Chip('맛집', Icons.restaurant_rounded, Color(0xFFEF4444)),
    _Chip('카페', Icons.coffee_rounded, Color(0xFF8B5CF6)),
    _Chip('팝업스토어', Icons.store_rounded, Color(0xFFF59E0B)),
    _Chip('술집', Icons.local_bar_rounded, Color(0xFF3B82F6)),
    _Chip('공원', Icons.park_rounded, Color(0xFF10B981)),
    _Chip('쇼핑', Icons.shopping_bag_rounded, Color(0xFFEC4899)),
    _Chip('문화', Icons.museum_rounded, Color(0xFF6366F1)),
    _Chip('편의점', Icons.store_mall_directory_rounded, Color(0xFF14B8A6)),
  ];

  // 빠른 입력 예시
  static const _suggestions = [
    '힙한 분위기',
    '조용한 곳',
    '인스타 감성',
    '넓은 곳',
    '뷰 좋은 곳',
    '가성비',
    '야외 테라스',
    '24시간',
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
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
      setState(() => _origin = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한을 확인해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _onSearch() async {
    if (_origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치를 가져오는 중이에요.')),
      );
      return;
    }
    if (_selectedChips.isEmpty && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리나 원하는 것을 입력해주세요.')),
      );
      return;
    }

    _focusNode.unfocus();
    setState(() => _loading = true);

    try {
      final result = await PlaceRecommendService.recommend(
        origin: _origin!,
        userInput: _textController.text.trim(),
        chips: _selectedChips.toList(),
        people: _people,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaceResultScreen(recommendation: result, origin: _origin!)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        title: Text('AI 장소 추천', style: AppTextStyles.h3),
        centerTitle: true,
      ),
      body: GestureDetector(
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
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('지금 여기서 어디 갈까요?', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                          const SizedBox(height: 2),
                          Text(
                            '원하는 걸 자유롭게 말해주세요\nAI가 주변 최적 장소를 찾아드려요',
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

              const SizedBox(height: 24),

              // ── 인원 선택 ──
              Row(
                children: [
                  Text('인원', style: AppTextStyles.bodyBold),
                  const Spacer(),
                  _PeopleSelector(
                    value: _people,
                    onChanged: (v) => setState(() => _people = v),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── 카테고리 칩 ──
              Text('어디 가고 싶어요?', style: AppTextStyles.bodyBold),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final selected = _selectedChips.contains(cat.label);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedChips.remove(cat.label);
                      } else {
                        _selectedChips.add(cat.label);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? cat.color : context.cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: selected ? cat.color : context.borderColor,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: cat.color.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 15, color: selected ? Colors.white : cat.color),
                          const SizedBox(width: 6),
                          Text(
                            cat.label,
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
              Text('더 구체적으로 말해줘요', style: AppTextStyles.bodyBold),
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
                    hintText: '예) 친구 3명이랑 힙한 분위기 카페 가고 싶어\n예) 데이트하기 좋은 조용한 맛집',
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

              const SizedBox(height: 28),

              // ── 위치 표시 ──
              Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _locating
                          ? '위치 가져오는 중...'
                          : _origin != null
                              ? '현재 위치 기준 2km 반경'
                              : '위치를 가져올 수 없어요',
                      style: AppTextStyles.small,
                    ),
                  ),
                  if (_locating)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5))
                  else
                    GestureDetector(
                      onTap: _getLocation,
                      child: Text('새로고침', style: AppTextStyles.small.copyWith(color: AppColors.primary)),
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
                            const SizedBox(width: 10),
                            Text('AI가 장소 찾는 중...', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _selectedChips.isEmpty && _textController.text.isEmpty
                                  ? '장소 추천 받기'
                                  : '$_people명 · ${_selectedChips.join(' ')} 추천 받기',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 서브 위젯
// ─────────────────────────────────────────────────────────────

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
            '$value명',
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
  final String label;
  final IconData icon;
  final Color color;
  const _Chip(this.label, this.icon, this.color);
}
