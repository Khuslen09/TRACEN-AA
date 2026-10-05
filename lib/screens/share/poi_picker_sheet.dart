import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/pin.dart';
import '../../models/place_candidate.dart';
import '../../services/place_name_service.dart';
import '../../services/route_db_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';

/// 공유 카드 위치명 스티커(또는 "표시" 탭의 위치명 칩 옆 편집 아이콘)를
/// 탭하면 뜨는 바텀시트 — [Pin.placeCandidates] 목록 + 동네 이름 폴백 +
/// 직접 입력. 선택한 값을 그 핀의 `placeName`으로 즉시 저장하고 반환한다.
Future<String?> showPoiPickerSheet(BuildContext context, Pin pin) async {
  final chosen = await showPlaceNamePickerSheet(
    context,
    lat: pin.lat,
    lng: pin.lng,
    candidates: pin.placeCandidates,
  );
  if (chosen != null) {
    await RouteDBService.updatePin(pin.copyWith(placeName: chosen));
  }
  return chosen;
}

/// DB에 저장된 [Pin]이 아직 없는 상황(예: 촬영/선택 직후 편집 화면)에서도
/// 쓸 수 있는, 영속화를 하지 않는 순수 UI 버전. 호출 측이 선택 결과를
/// 직접 처리한다(메모리에만 반영하거나, 필요하면 직접 저장).
/// `PinPreviewSheet`와 같은 `showModalBottomSheet`+`DraggableScrollableSheet`
/// 패턴.
Future<String?> showPlaceNamePickerSheet(
  BuildContext context, {
  required double lat,
  required double lng,
  required List<PlaceCandidate> candidates,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _PoiPickerSheet(
        lat: lat,
        lng: lng,
        candidates: candidates,
        scrollController: scrollController,
      ),
    ),
  );
}

class _PoiPickerSheet extends StatefulWidget {
  final double lat;
  final double lng;
  final List<PlaceCandidate> candidates;
  final ScrollController scrollController;

  const _PoiPickerSheet({
    required this.lat,
    required this.lng,
    required this.candidates,
    required this.scrollController,
  });

  @override
  State<_PoiPickerSheet> createState() => _PoiPickerSheetState();
}

class _PoiPickerSheetState extends State<_PoiPickerSheet> {
  final _manualController = TextEditingController();
  String? _neighborhoodFallback;
  bool _loadingFallback = true;

  @override
  void initState() {
    super.initState();
    PlaceNameService.placeNameFor(widget.lat, widget.lng).then((name) {
      if (mounted) {
        setState(() {
          _neighborhoodFallback = name;
          _loadingFallback = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _choose(String name) => Navigator.pop(context, name);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidates = widget.candidates;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(l10n.poiPickerTitle, style: AppTextStyles.h3),
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.poiPickerNoCandidates,
                style: AppTextStyles.body.copyWith(color: context.textSecondary),
              ),
            )
          else
            for (final candidate in candidates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(candidate.name, style: AppTextStyles.bodyBold),
                trailing: Text(
                  l10n.poiPickerDistanceMeters(candidate.distanceM.round()),
                  style: AppTextStyles.small,
                ),
                onTap: () => _choose(candidate.name),
              ),
          const Divider(height: 24),
          if (_loadingFallback)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_neighborhoodFallback != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_city_rounded),
              title: Text(l10n.poiPickerNeighborhoodFallback),
              subtitle: Text(_neighborhoodFallback!),
              onTap: () => _choose(_neighborhoodFallback!),
            ),
          const SizedBox(height: 8),
          Text(l10n.poiPickerManualEntry, style: AppTextStyles.smallBold),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualController,
                  decoration: InputDecoration(hintText: l10n.poiPickerManualHint),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  final text = _manualController.text.trim();
                  if (text.isNotEmpty) _choose(text);
                },
                child: Text(l10n.poiPickerConfirm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
