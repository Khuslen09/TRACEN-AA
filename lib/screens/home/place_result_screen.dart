import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/pin.dart';
import '../../models/pin_category.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/place_recommend_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../save_files_screen.dart';

/// AI 장소 추천 결과 화면.
///
/// - 상단: 지도 — 번호가 붙은 보라 마커, 처음엔 모든 추천 장소가 보이게 맞춤
/// - 하단: AI 코멘트 + 번호 카드 리스트 (지도 마커 번호와 1:1)
///   - 카드 탭 → 지도 이동 / 마커 탭 → 해당 카드로 스크롤
///   - 카드마다 "길찾기"(지도 앱), "핀으로 저장"(내 지도에 저장)
/// - 맨 아래 "다시 추천받기" → `true`를 돌려주며 pop (입력 화면이 재검색)
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
  final Set<int> _savedIndexes = {};

  late final List<GlobalKey> _cardKeys = List.generate(
    widget.recommendation.places.length,
    (_) => GlobalKey(),
  );

  /// 번호 마커 이미지 캐시 — key: "번호_포커스여부"
  final Map<String, BitmapDescriptor> _markerIcons = {};

  List<Place> get _places => widget.recommendation.places;

  @override
  void initState() {
    super.initState();
    _buildMarkerIcons();
  }

  Future<void> _buildMarkerIcons() async {
    for (var i = 0; i < _places.length; i++) {
      _markerIcons['${i}_0'] = await _numberMarker(i + 1, focused: false);
      _markerIcons['${i}_1'] = await _numberMarker(i + 1, focused: true);
    }
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // 지도
  // ─────────────────────────────────────────────

  Set<Marker> get _markers {
    final set = <Marker>{};
    for (var i = 0; i < _places.length; i++) {
      final p = _places[i];
      final focused = _focusedIndex == i;
      set.add(Marker(
        markerId: MarkerId('place_$i'),
        position: p.position,
        zIndex: focused ? 2.0 : 1.0,
        icon: _markerIcons['${i}_${focused ? 1 : 0}'] ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        anchor: const Offset(0.5, 0.5),
        onTap: () => _focus(i, scrollToCard: true),
      ));
    }
    return set;
  }

  Future<void> _fitAll() async {
    final c = _mapController;
    if (c == null) return;
    final points = [widget.origin, ..._places.map((p) => p.position)];
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    try {
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          56,
        ),
      );
    } catch (_) {
      // 지도 레이아웃 전이면 실패할 수 있음 — 초기 카메라 위치 그대로 둔다
    }
  }

  void _focus(int i, {bool scrollToCard = false}) {
    setState(() => _focusedIndex = i);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_places[i].position, 16),
    );
    if (scrollToCard) {
      final ctx = _cardKeys[i].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  // 액션
  // ─────────────────────────────────────────────

  Future<void> _openDirections(Place p) async {
    final lat = p.position.latitude, lng = p.position.longitude;
    final name = Uri.encodeComponent(p.name);
    final uri = Platform.isIOS
        ? Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$name')
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
          );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorOpenUrl(l10n.placeDirections))),
      );
    }
  }

  PinCategory _pinCategoryFor(String placesType) => switch (placesType) {
    'cafe' => PinCategory.cafe,
    'restaurant' || 'bar' => PinCategory.food,
    'park' || 'museum' => PinCategory.scenery,
    _ => PinCategory.general,
  };

  Future<void> _saveAsPin(int i) async {
    final p = _places[i];
    final pin = await Navigator.push<Pin?>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveFilesScreen(
          lat: p.position.latitude,
          lng: p.position.longitude,
          initialPlaceName: p.name,
          initialCategory: _pinCategoryFor(p.category),
          initialMemo: p.reason,
        ),
      ),
    );
    if (pin == null || !mounted) return;
    CloudSyncService.syncPinAdded(pin);
    setState(() => _savedIndexes.add(i));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.placeSavedAsPin),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _distanceText(Place p) {
    final m = Geolocator.distanceBetween(
      widget.origin.latitude,
      widget.origin.longitude,
      p.position.latitude,
      p.position.longitude,
    );
    return m < 1000 ? '${m.round()}m' : '${(m / 1000).toStringAsFixed(1)}km';
  }

  IconData _iconForCategory(String cat) => switch (cat) {
    'cafe' => Icons.coffee_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'bar' => Icons.local_bar_rounded,
    'park' => Icons.park_rounded,
    'store' => Icons.store_rounded,
    'shopping_mall' => Icons.shopping_bag_rounded,
    'museum' => Icons.museum_rounded,
    'convenience_store' => Icons.store_mall_directory_rounded,
    _ => Icons.place_rounded,
  };

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              // ── 지도 ──
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.origin,
                    zoom: 14.5,
                  ),
                  onMapCreated: (c) {
                    _mapController = c;
                    Future.delayed(const Duration(milliseconds: 350), _fitAll);
                  },
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  padding: EdgeInsets.only(top: topInset + 40),
                ),
              ),

              // ── 결과 시트 ──
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    boxShadow: AppShadows.lg,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      // AI 코멘트
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.placesRecommended(rec.places.length),
                              style: AppTextStyles.h3.copyWith(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.isDark
                              ? AppColors.primary.withValues(alpha: 0.16)
                              : AppColors.primaryLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.summary,
                              style: AppTextStyles.body.copyWith(
                                color: context.isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.primaryDark,
                                height: 1.6,
                              ),
                            ),
                            if (rec.query.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 13,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '"${rec.query}"',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.small.copyWith(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 장소 카드
                      for (var i = 0; i < rec.places.length; i++)
                        _PlaceCard(
                          key: _cardKeys[i],
                          rank: i + 1,
                          place: rec.places[i],
                          icon: _iconForCategory(rec.places[i].category),
                          distance: _distanceText(rec.places[i]),
                          focused: _focusedIndex == i,
                          saved: _savedIndexes.contains(i),
                          onTap: () => _focus(i),
                          onDirections: () => _openDirections(rec.places[i]),
                          onSave: _savedIndexes.contains(i)
                              ? null
                              : () => _saveAsPin(i),
                        ),

                      const SizedBox(height: 8),

                      // 다시 추천받기
                      Center(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(l10n.placeRetryRecs),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: AppTextStyles.bodyBold,
                          ),
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
            top: topInset + 8,
            left: 12,
            child: Material(
              color: context.cardColor,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.md,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ),
          ),

          // ── 전체 보기 버튼 ──
          Positioned(
            top: topInset + 8,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() => _focusedIndex = null);
                _fitAll();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: AppShadows.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.placesCount(rec.places.length),
                      style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 장소 카드
// ─────────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  final int rank;
  final Place place;
  final IconData icon;
  final String distance;
  final bool focused;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onDirections;
  final VoidCallback? onSave;

  const _PlaceCard({
    super.key,
    required this.rank,
    required this.place,
    required this.icon,
    required this.distance,
    required this.focused,
    required this.saved,
    required this.onTap,
    required this.onDirections,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: focused ? AppColors.primary : context.borderColor,
            width: focused ? 1.5 : 1,
          ),
          boxShadow: focused ? AppShadows.primary : AppShadows.sm,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 번호 (지도 마커와 동일)
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: focused ? AppColors.primary : AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: focused ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // 메타: 아이콘 · 거리 · 평점
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 13, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text(distance, style: AppTextStyles.small),
                              ],
                            ),
                            if (place.rating > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    place.rating.toStringAsFixed(1),
                                    style: AppTextStyles.small.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (place.address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            place.address,
                            style: AppTextStyles.small.copyWith(
                              color: context.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // AI 추천 이유
              if (place.reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : AppColors.primaryLight.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place.reason,
                          semanticsLabel: '${l10n.placeAiPick}: ${place.reason}',
                          style: AppTextStyles.small.copyWith(
                            color: context.isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.primaryDark,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // 액션
              Row(
                children: [
                  Expanded(
                    child: _CardAction(
                      icon: Icons.directions_rounded,
                      label: l10n.placeDirections,
                      onTap: onDirections,
                    ),
                  ),
                  Container(width: 1, height: 18, color: context.borderColor),
                  Expanded(
                    child: _CardAction(
                      icon: saved
                          ? Icons.check_circle_rounded
                          : Icons.push_pin_outlined,
                      label: saved ? l10n.placeSavedShort : l10n.placeSaveAsPin,
                      onTap: onSave,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? context.textTertiary : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.smallBold.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 번호 마커
// ─────────────────────────────────────────────────────────────

/// 흰 테두리 + 보라 원 + 흰 숫자. 포커스되면 조금 더 크고 진하게.
Future<BitmapDescriptor> _numberMarker(int n, {required bool focused}) async {
  const dpr = 3.0;
  final logical = focused ? 40.0 : 32.0;
  final px = (logical * dpr).toInt();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(px / 2, px / 2);
  final r = px / 2;

  canvas.drawCircle(
    center + const Offset(0, 3),
    r * 0.8,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  canvas.drawCircle(center, r * 0.86, Paint()..color = Colors.white);
  canvas.drawCircle(
    center,
    r * 0.72,
    Paint()..color = focused ? AppColors.primaryDark : AppColors.primary,
  );

  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: '$n',
      style: TextStyle(
        color: Colors.white,
        fontSize: r * 0.8,
        fontWeight: FontWeight.w800,
      ),
    ),
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

  final img = await recorder.endRecording().toImage(px, px);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    imagePixelRatio: dpr,
  );
}
