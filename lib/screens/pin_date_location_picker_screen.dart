import '../l10n/generated/app_localizations.dart';
import '../l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../models/pin.dart';
import '../services/cloud_sync_service.dart';
import '../services/location_service.dart';
import '../services/route_db_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_extensions.dart';
import 'save_files_screen.dart';

/// 타임라인에서 + 버튼으로 진입. 날짜/시간 + 위치를 선택한 후
/// SaveFilesScreen으로 이동.
///
/// 사용 흐름:
///   1. 화면 진입: 오늘 날짜 + 현재 위치 기본값
///   2. 사용자가 상단 카드 탭 → 날짜/시간 picker
///   3. 사용자가 지도에서 핀을 끌어서 위치 조정 (또는 길게 눌러 새 위치)
///   4. 하단 l10n.onboardingNext 버튼 → SaveFilesScreen
///   5. SaveFilesScreen에서 사진/메모/카테고리 입력 → 저장 시 createdAt 덮어쓰기
///
/// **MVP v5 신규**: 과거 날짜에도 핀 추가 가능 (여행 후 회상 등 용도).
class PinDateLocationPickerScreen extends StatefulWidget {
  const PinDateLocationPickerScreen({super.key});

  @override
  State<PinDateLocationPickerScreen> createState() =>
      _PinDateLocationPickerScreenState();
}

class _PinDateLocationPickerScreenState
    extends State<PinDateLocationPickerScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);

  DateTime _selectedDateTime = DateTime.now();
  LatLng? _selectedPosition;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPosition();
  }

  Future<void> _loadInitialPosition() async {
    try {
      final pos = await LocationService.currentPosition();
      if (mounted) {
        setState(() {
          _selectedPosition = LatLng(pos.latitude, pos.longitude);
          _loading = false;
        });
      }
    } catch (_) {
      // 위치 못 가져오면 서울 시청 기본값
      if (mounted) {
        setState(() {
          _selectedPosition = const LatLng(37.5665, 126.978);
          _loading = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  // 날짜/시간 선택
  // ─────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    // 날짜 먼저
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null) return;

    if (!mounted) return;

    // 시간
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(
            ctx,
          ).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ─────────────────────────────────────────────
  // 위치 선택
  // ─────────────────────────────────────────────

  void _onMapTap(LatLng pos) {
    // 지도 탭하면 그 위치로 핀 이동
    setState(() => _selectedPosition = pos);
  }

  // ─────────────────────────────────────────────
  // 다음 → SaveFiles
  // ─────────────────────────────────────────────

  Future<void> _proceedToSave() async {
    final pos = _selectedPosition;
    if (pos == null) return;

    final pin = await Navigator.push<Pin?>(
      context,
      MaterialPageRoute(
        builder: (_) => SaveFilesScreen(lat: pos.latitude, lng: pos.longitude),
      ),
    );

    if (pin == null) return;

    // SaveFilesScreen이 createdAt = DateTime.now()로 만들었는데
    // 사용자가 과거 날짜 골랐을 수 있어서 덮어쓰기 필요.
    if (_isDifferentFromNow(_selectedDateTime)) {
      final updated = pin.copyWith(createdAt: _selectedDateTime);
      await RouteDBService.updatePin(updated);
      // 클라우드도 동기화
      CloudSyncService.syncPinAdded(updated);
    }

    if (mounted) {
      Navigator.pop(context, true); // true = 핀 추가됨, 타임라인 새로고침
    }
  }

  /// 사용자가 선택한 시각이 "지금"과 의미 있는 차이가 있는지 (1분 이내면 false).
  bool _isDifferentFromNow(DateTime dt) {
    final diff = DateTime.now().difference(dt).inMinutes.abs();
    return diff > 1;
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading || _selectedPosition == null) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(l10n.addPin),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 날짜/시간 카드
          Padding(
            padding: const EdgeInsets.all(16),
            child: _DateTimeCard(
              dateTime: _selectedDateTime,
              onTap: _pickDateTime,
            ),
          ),

          // 안내 텍스트
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: context.textSecondary,
                ),
                SizedBox(width: 6),
                Text(
                  l10n.pickerTapMapHint,
                  style: AppTextStyles.small.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 지도
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedPosition!,
                        zoom: 16,
                      ),
                      onTap: _onMapTap,
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected'),
                          position: _selectedPosition!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueViolet,
                          ),
                        ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),

                    // 지도 위 살짝 보라 톤 (HomeScreen 톤과 일관)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: AppColors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 다음 버튼
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.primary,
                  ),
                  child: ElevatedButton(
                    onPressed: _proceedToSave,
                    child: Text(l10n.onboardingNext),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _DateTimeCard extends StatelessWidget {
  final DateTime dateTime;
  final VoidCallback onTap;

  const _DateTimeCard({required this.dateTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isToday = _isSameDay(dateTime, DateTime.now());
    final dateStr = DateFormat.yMMMEd(Strings.current.localeName).format(dateTime);
    final timeStr = DateFormat.jm(Strings.current.localeName).format(dateTime);

    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(dateStr, style: AppTextStyles.bodyBold),
                        if (isToday) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.today,
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(timeStr, style: AppTextStyles.small),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
