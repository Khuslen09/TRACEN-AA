import '../../l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/place_recommend_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';

/// AI 장소 추천 결과 화면.
///
/// - 상단: Google Maps에 추천 장소 핀 표시
/// - 하단: AI 코멘트 + 장소 카드 리스트
class PlaceResultScreen extends StatefulWidget {
  final PlaceRecommendation recommendation;
  final LatLng origin;

  const PlaceResultScreen({
    super.key,
    required this.recommendation,
    required this.origin,
  });

  @override
  State<PlaceResultScreen> createState() => _PlaceResultScreenState();
}

class _PlaceResultScreenState extends State<PlaceResultScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  GoogleMapController? _mapController;
  int? _focusedIndex;

  Set<Marker> get _markers {
    final set = <Marker>{};

    // 현재 위치
    set.add(Marker(
      markerId: const MarkerId('me'),
      position: widget.origin,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: InfoWindow(title: l10n.currentLocation),
    ));

    // 추천 장소
    for (var i = 0; i < widget.recommendation.places.length; i++) {
      final p = widget.recommendation.places[i];
      final isFocused = _focusedIndex == i;
      set.add(Marker(
        markerId: MarkerId('place_$i'),
        position: p.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isFocused ? BitmapDescriptor.hueOrange : _hueForCategory(p.category),
        ),
        infoWindow: InfoWindow(title: p.name, snippet: p.reason),
        onTap: () {
          setState(() => _focusedIndex = i);
          _mapController?.animateCamera(CameraUpdate.newLatLng(p.position));
        },
      ));
    }

    return set;
  }

  double _hueForCategory(String cat) => switch (cat) {
    'cafe' => BitmapDescriptor.hueViolet,
    'restaurant' => BitmapDescriptor.hueRed,
    'bar' => BitmapDescriptor.hueBlue,
    'park' => BitmapDescriptor.hueGreen,
    _ => BitmapDescriptor.hueYellow,
  };

  IconData _iconForCategory(String cat) => switch (cat) {
    'cafe' => Icons.coffee_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'bar' => Icons.local_bar_rounded,
    'park' => Icons.park_rounded,
    'popup' => Icons.store_rounded,
    _ => Icons.place_rounded,
  };

  Color _colorForCategory(String cat) => switch (cat) {
    'cafe' => const Color(0xFF8B5CF6),
    'restaurant' => const Color(0xFFEF4444),
    'bar' => const Color(0xFF3B82F6),
    'park' => const Color(0xFF10B981),
    'popup' => const Color(0xFFF59E0B),
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          Column(
            children: [

              // ── 지도 ──
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.42,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.origin,
                    zoom: 14.5,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),

              // ── 결과 시트 ──
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xxl),
                    ),
                    boxShadow: AppShadows.lg,
                  ),
                  child: Column(
                    children: [
                      // 핸들
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: context.borderColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [

                            // AI 코멘트
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(Icons.auto_awesome, size: 15, color: AppColors.primary),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.placesRecommended(rec.places.length),
                                    style: AppTextStyles.h3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Text(
                                rec.summary,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.primary,
                                  height: 1.6,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // 요청 태그
                            Wrap(
                              spacing: 6,
                              children: rec.query
                                  .split(' ')
                                  .where((w) => w.isNotEmpty)
                                  .take(5)
                                  .map((w) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: context.cardColor,
                                          borderRadius: BorderRadius.circular(AppRadius.full),
                                          border: Border.all(color: context.borderColor),
                                        ),
                                        child: Text(w, style: AppTextStyles.small),
                                      ))
                                  .toList(),
                            ),

                            const SizedBox(height: 16),

                            // 장소 카드 리스트
                            ...List.generate(rec.places.length, (i) {
                              final place = rec.places[i];
                              final isFocused = _focusedIndex == i;
                              final catColor = _colorForCategory(place.category);

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _focusedIndex = i);
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(place.position, 16),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isFocused
                                        ? catColor.withValues(alpha: 0.06)
                                        : context.cardColor,
                                    borderRadius: BorderRadius.circular(AppRadius.xl),
                                    border: Border.all(
                                      color: isFocused ? catColor : context.borderColor,
                                      width: isFocused ? 1.5 : 1,
                                    ),
                                    boxShadow: isFocused
                                        ? [BoxShadow(color: catColor.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
                                        : AppShadows.sm,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 아이콘
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                          ),
                                          child: Icon(_iconForCategory(place.category), color: catColor, size: 22),
                                        ),
                                        const SizedBox(width: 14),

                                        // 정보
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(place.name, style: AppTextStyles.bodyBold),
                                                  ),
                                                  if (place.rating > 0) ...[
                                                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      place.rating.toStringAsFixed(1),
                                                      style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (place.address.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  place.address,
                                                  style: AppTextStyles.small,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 8),
                                              // AI 추천 이유
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: catColor.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(Icons.auto_awesome, size: 12, color: catColor),
                                                    const SizedBox(width: 5),
                                                    Expanded(
                                                      child: Text(
                                                        place.reason,
                                                        style: AppTextStyles.small.copyWith(
                                                          color: catColor,
                                                          height: 1.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── 상단 뒤로가기 ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.md,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              ),
            ),
          ),

          // ── 장소 수 배지 ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: AppShadows.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    l10n.placesCount(rec.places.length),
                    style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
