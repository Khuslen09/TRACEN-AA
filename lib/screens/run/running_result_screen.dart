import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/pin.dart';
import '../../models/route.dart';
import '../../models/route_point.dart';
import '../../services/route_db_service.dart';
import '../../services/run_metrics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_extensions.dart';

/// 러닝 완료 후 결과 화면.
///
/// 구성:
///   - 상단: 축하 메시지 + 큰 거리
///   - 통계 카드 4분할: 시간 / 페이스 / 칼로리 / 핀 수
///   - 경로 미니맵 (스크롤 가능, 줌은 자동 fit)
///   - 하단: 닫기 버튼 → HomeScreen 복귀
///
/// 동작:
///   - RouteDBService.getRoute + getRoutePoints + getPins 모두 로드
///   - 사용자가 "확인" 누르면 HomeScreen으로 pop
///
/// **MVP v5 / Week 7**: 시연 임팩트 큰 화면. 발표용 폴리시.
class RunningResultScreen extends StatefulWidget {
  /// 방금 종료한 러닝의 로컬 id
  final int runId;

  const RunningResultScreen({super.key, required this.runId});

  @override
  State<RunningResultScreen> createState() => _RunningResultScreenState();
}

class _RunningResultScreenState extends State<RunningResultScreen> {
  GoogleMapController? _mapController;

  Future<_RunResult>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<_RunResult> _load() async {
    final run = await RouteDBService.getRoute(widget.runId);
    if (run == null) {
      throw StateError('러닝 정보를 찾을 수 없어요');
    }
    final points = await RouteDBService.getPoints(widget.runId);
    final pins = await RouteDBService.getPins(widget.runId);
    return _RunResult(run: run, points: points, pins: pins);
  }

  // 경로 전체가 보이게 카메라 fit
  void _fitCamera(List<RoutePoint> points) {
    if (points.length < 2 || _mapController == null) return;

    double minLat = points.first.lat;
    double maxLat = points.first.lat;
    double minLng = points.first.lng;
    double maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60), // 60px 패딩
    );
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: FutureBuilder<_RunResult>(
        future: _loadFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error?.toString() ?? '결과를 불러올 수 없어요',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _buildResult(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildResult(_RunResult data) {
    final run = data.run;
    final elapsed = run.endedAt != null
        ? run.endedAt!.difference(run.startedAt)
        : Duration.zero;
    final pace = RunMetrics.averagePaceSecondsPerKm(
      distanceMeters: run.distance,
      elapsed: elapsed,
    );
    final calories = RunMetrics.estimateCalories(distanceMeters: run.distance);
    final dateStr = DateFormat(
      'M월 d일 (E) a h:mm',
      'ko_KR',
    ).format(run.startedAt);

    return SafeArea(
      child: Column(
        children: [
          // ── 상단 닫기 X ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
              ],
            ),
          ),

          // ── 스크롤 가능 컨텐츠 ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 축하 + 날짜
                  Text(
                    '러닝 완료',
                    style: AppTextStyles.smallBold.copyWith(
                      letterSpacing: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: AppTextStyles.small.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 큰 거리
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        RunMetrics.formatDistanceKmBig(run.distance),
                        style: AppTextStyles.display.copyWith(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'km',
                          style: AppTextStyles.h2.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 통계 카드 4분할 (2x2)
                  _StatsGrid(
                    elapsed: elapsed,
                    pace: pace,
                    calories: calories,
                    pinCount: data.pins.length,
                  ),

                  const SizedBox(height: 24),

                  // 경로 미니맵
                  if (data.points.length >= 2)
                    _MapPreview(
                      points: data.points,
                      pins: data.pins,
                      onMapCreated: (c) {
                        _mapController = c;
                        // 다음 프레임에 fit (controller 준비 보장)
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _fitCamera(data.points);
                        });
                      },
                    )
                  else
                    _NoPathPlaceholder(),
                ],
              ),
            ),
          ),

          // ── 하단: 확인 버튼 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.primary,
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
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
// Data
// ──────────────────────────────────────────────────────────────

class _RunResult {
  final TraceRoute run;
  final List<RoutePoint> points;
  final List<Pin> pins;

  _RunResult({required this.run, required this.points, required this.pins});
}

// ──────────────────────────────────────────────────────────────
// Sub Widgets
// ──────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Duration elapsed;
  final double pace;
  final int calories;
  final int pinCount;

  const _StatsGrid({
    required this.elapsed,
    required this.pace,
    required this.calories,
    required this.pinCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatCell(
                label: '시간',
                value: RunMetrics.formatElapsed(elapsed),
                icon: Icons.timer_outlined,
              ),
              _CellDivider(),
              _StatCell(
                label: '평균 페이스',
                value: RunMetrics.formatPace(pace),
                icon: Icons.speed_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatCell(
                label: '칼로리',
                value: '$calories',
                suffix: 'kcal',
                icon: Icons.local_fire_department_outlined,
              ),
              _CellDivider(),
              _StatCell(
                label: '핀',
                value: '$pinCount',
                suffix: '개',
                icon: Icons.place_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final IconData icon;

  const _StatCell({
    required this.label,
    required this.value,
    this.suffix,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    suffix!,
                    style: AppTextStyles.small.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CellDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 56, color: AppColors.border);
  }
}

class _MapPreview extends StatelessWidget {
  final List<RoutePoint> points;
  final List<Pin> pins;
  final void Function(GoogleMapController) onMapCreated;

  const _MapPreview({
    required this.points,
    required this.pins,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final polylinePoints = points.map((p) => LatLng(p.lat, p.lng)).toList();

    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: polylinePoints.first,
                zoom: 15,
              ),
              onMapCreated: onMapCreated,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false, // 결과 화면이라 인터랙션 차단
              zoomGesturesEnabled: false,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              polylines: {
                Polyline(
                  polylineId: const PolylineId('result_path'),
                  points: polylinePoints,
                  color: AppColors.primary,
                  width: 5,
                ),
              },
              markers: {
                // 시작점
                Marker(
                  markerId: const MarkerId('start'),
                  position: polylinePoints.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                  infoWindow: const InfoWindow(title: '시작'),
                ),
                // 끝점
                Marker(
                  markerId: const MarkerId('end'),
                  position: polylinePoints.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                  infoWindow: const InfoWindow(title: '도착'),
                ),
                // 러닝 중 추가한 핀들 (카테고리 색상)
                for (final pin in pins)
                  Marker(
                    markerId: MarkerId('pin_${pin.id}'),
                    position: LatLng(pin.lat, pin.lng),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      pin.category.markerHue,
                    ),
                  ),
              },
            ),
            // 살짝 보라 톤
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
    );
  }
}

class _NoPathPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 36, color: AppColors.gray400),
          const SizedBox(height: 8),
          Text(
            '경로가 너무 짧아서 표시할 수 없어요',
            style: AppTextStyles.small.copyWith(color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}
