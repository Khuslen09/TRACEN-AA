import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/activity_type.dart';
import '../../models/pin.dart';
import '../../models/route.dart';
import '../../models/route_point.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/route_db_service.dart';
import '../../services/run_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';
import '../share/activity_share_screen.dart';

/// 러닝/워킹/사이클링 종료 후 결과 화면 — "오늘의 여정 한 페이지".
///
/// 위에서 아래로: 경로 지도 → 제목(자동 생성, 탭해서 수정) + 핵심 지표 →
/// 구간 기록 → 여정 속 사진 → 한 줄 메모. 하단에 공유 / 여정 저장.
///
/// 이 화면에 들어온 route는 `pending_review` 상태다. "여정 저장"을 눌러야
/// `completed`가 되고 그때 처음 클라우드 동기화가 큐에 들어간다. 저장 없이
/// 나가려 하면 버릴지 묻고, 버리면 route를 삭제한다. 앱이 이 화면에서
/// 종료되면 다음 실행 때 `HomeScreen`이 이 화면을 다시 열어준다.
class ActivityResultScreen extends StatefulWidget {
  final int routeId;

  const ActivityResultScreen({super.key, required this.routeId});

  @override
  State<ActivityResultScreen> createState() => _ActivityResultScreenState();
}

class _ActivityResultScreenState extends State<ActivityResultScreen> {
  final _titleController = TextEditingController();
  final _memoController = TextEditingController();
  late final Future<ActivityResultData> _future = _load();

  GoogleMapController? _mapController;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<ActivityResultData> _load() async {
    final route = await RouteDBService.getRoute(widget.routeId);
    if (route == null) throw StateError('route ${widget.routeId} not found');
    final points = await RouteDBService.getPoints(widget.routeId);
    final pauses = await RouteDBService.getPauses(widget.routeId);
    final pins = await RouteDBService.getPins(widget.routeId);

    final end = route.endedAt ?? route.lastActiveAt ?? DateTime.now();
    final moving = RunMetrics.movingDurationAt(
      startedAt: route.startedAt,
      at: end,
      pauses: pauses,
    );
    final splits = RunMetrics.computeSplits(
      points: points,
      pauses: pauses,
      startedAt: route.startedAt,
      splitMeters: route.activityType == ActivityType.cycling ? 5000 : 1000,
    );
    final photos = [
      for (final p in pins)
        if (p.photoPath != null &&
            p.photoPath!.isNotEmpty &&
            File(p.photoPath!).existsSync())
          p,
    ];

    final data = ActivityResultData(
      route: route,
      points: points,
      movingTime: moving,
      elevationGain: RunMetrics.elevationGain(points),
      splits: splits,
      photoPins: photos,
    );

    _titleController.text = route.status == RouteStatus.completed
        ? route.title
        : _autoTitle(route);
    _memoController.text = route.memo ?? '';
    return data;
  }

  /// "10월 9일 저녁 러닝" — 날짜 + 시간대 + 활동.
  String _autoTitle(TraceRoute route) {
    final l10n = AppLocalizations.of(context);
    final t = route.startedAt;
    final date = DateFormat.MMMd(l10n.localeName).format(t);
    final h = t.hour;
    final timeOfDay = h >= 5 && h < 12
        ? l10n.resultTimeMorning
        : h >= 12 && h < 17
        ? l10n.resultTimeAfternoon
        : h >= 17 && h < 21
        ? l10n.resultTimeEvening
        : l10n.resultTimeNight;
    return l10n.resultAutoTitle(date, timeOfDay, route.activityType.label);
  }

  // ─────────────────────────────────────────────
  // 저장 / 버리기 / 공유
  // ─────────────────────────────────────────────

  Future<void> _save(ActivityResultData data) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final title = _titleController.text.trim();
      final memo = _memoController.text.trim();
      final updated = TraceRoute(
        id: data.route.id,
        uuid: data.route.uuid,
        title: title.isEmpty ? _autoTitle(data.route) : title,
        startedAt: data.route.startedAt,
        endedAt: data.route.endedAt,
        distance: data.route.distance,
        userId: data.route.userId,
        activityType: data.route.activityType,
        memo: memo.isEmpty ? null : memo,
        status: RouteStatus.completed,
        lastActiveAt: data.route.lastActiveAt,
      );
      await RouteDBService.updateRoute(updated);
      unawaited(CloudSyncService.syncRouteCompleted(widget.routeId));
      _saved = true;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.resultSaved)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.saveFailedWith('$e')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saved) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.resultDiscardTitle),
        content: Text(l10n.resultDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.resultCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.resultDiscard),
          ),
        ],
      ),
    );
    if (discard != true) return;
    await RouteDBService.deleteRoute(widget.routeId);
    if (mounted) Navigator.of(context).pop(false);
  }

  void _openShare(ActivityResultData data) {
    final title = _titleController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityShareScreen(
          data: ActivityShareData(
            activityType: data.route.activityType,
            title: title.isEmpty ? _autoTitle(data.route) : title,
            startedAt: data.route.startedAt,
            distanceMeters: data.route.distance,
            movingTime: data.movingTime,
            elevationGain: data.elevationGain,
            path: [for (final p in data.points) (lat: p.lat, lng: p.lng)],
            photoPaths: [for (final p in data.photoPins) p.photoPath!],
          ),
        ),
      ),
    );
  }

  void _fitCamera(List<RoutePoint> points) {
    final c = _mapController;
    if (points.length < 2 || c == null) return;
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    try {
      c.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          48,
        ),
      );
    } catch (_) {
      // 지도 크기가 아직 0인 프레임 등 — 초기 카메라(시작점)로 둔다.
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: FutureBuilder<ActivityResultData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final data = snap.data;
            if (snap.hasError || data == null) {
              return SafeArea(
                child: Column(
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).pop()),
                    Expanded(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).resultLoadFailed,
                          style: AppTextStyles.body.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return _buildContent(data);
          },
        ),
      ),
    );
  }

  Widget _buildContent(ActivityResultData data) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(onBack: _confirmDiscard),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 110 + bottomPad),
                  children: [
                    _RouteMapCard(
                      data: data,
                      onMapCreated: (c) {
                        _mapController = c;
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _fitCamera(data.points),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _SummaryCard(data: data, titleController: _titleController),
                    if (data.splits.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SplitsCard(data: data),
                    ],
                    if (data.photoPins.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _PhotosCard(pins: data.photoPins),
                    ],
                    const SizedBox(height: 10),
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(title: l10n.resultMemo),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _memoController,
                            maxLines: 2,
                            minLines: 2,
                            maxLength: 100,
                            textInputAction: TextInputAction.done,
                            style: AppTextStyles.body.copyWith(
                              color: context.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.resultMemoHint,
                              counterText: '',
                              filled: true,
                              fillColor: context.bgColor,
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
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
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomActions(
            saving: _saving,
            onShare: () => _openShare(data),
            onSave: () => _save(data),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Data
// ──────────────────────────────────────────────────────────────

class ActivityResultData {
  final TraceRoute route;
  final List<RoutePoint> points;
  final Duration movingTime;
  final double elevationGain;
  final List<Split> splits;
  final List<Pin> photoPins;

  const ActivityResultData({
    required this.route,
    required this.points,
    required this.movingTime,
    required this.elevationGain,
    required this.splits,
    required this.photoPins,
  });

  ActivityType get type => route.activityType;
}

// ──────────────────────────────────────────────────────────────
// Sub widgets
// ──────────────────────────────────────────────────────────────

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          Material(
            color: context.cardColor,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context).resultDone,
              textAlign: TextAlign.center,
              style: AppTextStyles.smallBold.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? hint;
  const _SectionTitle({required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.bodyBold.copyWith(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        const Spacer(),
        if (hint != null)
          Text(
            hint!,
            style: AppTextStyles.caption.copyWith(color: context.textSecondary),
          ),
      ],
    );
  }
}

class _RouteMapCard extends StatelessWidget {
  final ActivityResultData data;
  final void Function(GoogleMapController) onMapCreated;

  const _RouteMapCard({required this.data, required this.onMapCreated});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pts = [for (final p in data.points) LatLng(p.lat, p.lng)];
    return SizedBox(
      height: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Stack(
          children: [
            if (pts.length >= 2)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: pts.first,
                  zoom: 15,
                ),
                onMapCreated: onMapCreated,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route_glow'),
                    points: pts,
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 12,
                  ),
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: pts,
                    color: AppColors.primary,
                    width: 5,
                  ),
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('start'),
                    position: pts.first,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                    infoWindow: InfoWindow(title: l10n.mapStart),
                  ),
                  Marker(
                    markerId: const MarkerId('end'),
                    position: pts.last,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueViolet,
                    ),
                    infoWindow: InfoWindow(title: l10n.mapEnd),
                  ),
                  for (final pin in data.photoPins)
                    Marker(
                      markerId: MarkerId('pin_${pin.id}'),
                      position: LatLng(pin.lat, pin.lng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        pin.category.markerHue,
                      ),
                    ),
                },
              )
            else
              Container(
                color: context.cardColor,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 36,
                      color: context.textTertiary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.routeTooShort,
                      style: AppTextStyles.small.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(data.type.icon, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      data.type.label,
                      style: AppTextStyles.smallBold.copyWith(
                        color: context.textPrimary,
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

class _SummaryCard extends StatelessWidget {
  final ActivityResultData data;
  final TextEditingController titleController;

  const _SummaryCard({required this.data, required this.titleController});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = data.route;
    final fmt = DateFormat.Hm(l10n.localeName);
    final timeRange = route.endedAt != null
        ? '${fmt.format(route.startedAt)} – ${fmt.format(route.endedAt!)}'
        : fmt.format(route.startedAt);

    final avg = data.type.usesPace
        ? (
            l10n.runAvgPace,
            RunMetrics.formatPace(
              RunMetrics.averagePaceSecondsPerKm(
                distanceMeters: route.distance,
                elapsed: data.movingTime,
              ),
            ),
            '/km',
          )
        : (
            l10n.metricAvgSpeed,
            RunMetrics.formatSpeedKmh(
              RunMetrics.averageSpeedKmh(
                distanceMeters: route.distance,
                elapsed: data.movingTime,
              ),
            ),
            'km/h',
          );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: titleController,
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.h2.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Icon(
                Icons.edit_rounded,
                size: 16,
                color: context.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            timeRange,
            style: AppTextStyles.small.copyWith(color: context.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.runDistance,
                  value: RunMetrics.formatDistanceKmBig(route.distance),
                  unit: 'km',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: l10n.resultMovingTime,
                  value: RunMetrics.formatElapsed(data.movingTime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatTile(label: avg.$1, value: avg.$2, unit: avg.$3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: l10n.resultElevationGain,
                  value: data.elevationGain.round().toString(),
                  unit: 'm',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;

  const _StatTile({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h2
                      .copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                        height: 1.2,
                      )
                      .merge(_tabular),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit!,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitsCard extends StatelessWidget {
  final ActivityResultData data;
  const _SplitsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usesPace = data.type.usesPace;
    final full = data.splits.where((s) => !s.isPartial).toList();

    // 페이스는 작을수록, 속도는 클수록 빠름.
    double score(Split s) => usesPace ? s.paceSecondsPerKm : -s.speedKmh;
    Split? fastest;
    for (final s in full) {
      if (s.duration <= Duration.zero) continue;
      if (fastest == null || score(s) < score(fastest)) fastest = s;
    }

    double ratio(Split s) {
      final f = fastest;
      if (f == null || s.duration <= Duration.zero) return 0.05;
      final r = usesPace
          ? f.paceSecondsPerKm / s.paceSecondsPerKm
          : s.speedKmh / f.speedKmh;
      return r.clamp(0.05, 1.0);
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: data.type == ActivityType.cycling
                ? l10n.resultSplits5Km
                : l10n.resultSplitsKm,
            hint: fastest != null ? l10n.resultFastestHint : null,
          ),
          const SizedBox(height: 8),
          for (final s in data.splits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Opacity(
                opacity: s.isPartial ? 0.6 : 1,
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        s.isPartial
                            ? (s.distanceMeters / 1000).toStringAsFixed(2)
                            : '${s.index}',
                        style: AppTextStyles.smallBold
                            .copyWith(color: context.textSecondary)
                            .merge(_tabular),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 12,
                          color: context.bgColor,
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio(s),
                            heightFactor: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: identical(s, fastest)
                                    ? AppColors.primary
                                    : AppColors.gray300,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        usesPace
                            ? RunMetrics.formatPace(s.paceSecondsPerKm)
                            : RunMetrics.formatSpeedKmh(s.speedKmh),
                        textAlign: TextAlign.right,
                        style: AppTextStyles.smallBold
                            .copyWith(
                              color: identical(s, fastest)
                                  ? AppColors.primary
                                  : context.textPrimary,
                            )
                            .merge(_tabular),
                      ),
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

class _PhotosCard extends StatelessWidget {
  final List<Pin> pins;
  const _PhotosCard({required this.pins});

  void _openPhoto(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          child: Center(child: Image.file(File(path))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat.Hm(l10n.localeName);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.resultPhotos, hint: '${pins.length}'),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pins.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final pin = pins[i];
                return GestureDetector(
                  onTap: () => _openPhoto(context, pin.photoPath!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Stack(
                      children: [
                        Image.file(
                          File(pin.photoPath!),
                          width: 96,
                          height: 120,
                          fit: BoxFit.cover,
                          cacheWidth: 288,
                        ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                            ),
                            child: Text(
                              fmt.format(pin.createdAt),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool saving;
  final VoidCallback onShare;
  final VoidCallback onSave;

  const _BottomActions({
    required this.saving,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            context.bgColor,
            context.bgColor,
            context.bgColor.withValues(alpha: 0),
          ],
          stops: const [0, 0.7, 1],
        ),
      ),
      child: Row(
        children: [
          Material(
            color: context.cardColor,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onShare,
              child: SizedBox(
                width: 54,
                height: 54,
                child: Icon(
                  Icons.ios_share_rounded,
                  color: context.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: AppShadows.primary,
              ),
              child: Material(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  onTap: saving ? null : onSave,
                  child: Center(
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.resultSave,
                            style: AppTextStyles.button.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
