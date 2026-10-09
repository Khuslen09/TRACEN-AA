import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/activity_share_template.dart';
import '../../models/activity_type.dart';
import '../../models/share_ink_color.dart';
import '../../services/run_metrics.dart';
import 'route_sticker_painter.dart';
import 'share_card_fonts.dart';
import 'share_card_logo_mark.dart';

/// 활동 공유 카드에 필요한 기록 스냅샷 — 결과 화면이 조립해서 넘긴다.
class ActivityShareData {
  final ActivityType activityType;
  final String title;
  final DateTime startedAt;
  final double distanceMeters;
  final Duration movingTime;
  final double elevationGain;
  final List<({double lat, double lng})> path;

  /// 이 활동 중 찍은 사진(핀) 경로들 — 사진 템플릿 배경 후보.
  final List<String> photoPaths;

  const ActivityShareData({
    required this.activityType,
    required this.title,
    required this.startedAt,
    required this.distanceMeters,
    required this.movingTime,
    required this.elevationGain,
    required this.path,
    required this.photoPaths,
  });

  String get distanceKm => RunMetrics.formatDistanceKmBig(distanceMeters);
  String get time => RunMetrics.formatElapsed(movingTime);

  /// 러닝/걷기 = 평균 페이스, 자전거 = 평균 속도.
  String get avgValue => activityType.usesPace
      ? RunMetrics.formatPace(
          RunMetrics.averagePaceSecondsPerKm(
            distanceMeters: distanceMeters,
            elapsed: movingTime,
          ),
        )
      : RunMetrics.formatSpeedKmh(
          RunMetrics.averageSpeedKmh(
            distanceMeters: distanceMeters,
            elapsed: movingTime,
          ),
        );

  String get avgUnit => activityType.usesPace ? '/km' : 'km/h';
}

/// 360×640 논리 크기의 활동 공유 카드(기존 핀 공유 카드와 같은 비율 —
/// 인스타 스토리 9:16). 미리보기와 내보내기가 같은 위젯을 쓴다.
///
/// [ActivityShareTemplate.sticker]는 배경을 칠하지 않아 PNG가 투명하게
/// 저장된다(미리보기의 체커보드는 카드 바깥에서 따로 그림).
class ActivityShareCard extends StatelessWidget {
  static const Size cardSize = Size(360, 640);

  final ActivityShareData data;
  final ActivityShareTemplate template;
  final ShareInkColor ink;
  final String? photoPath;

  const ActivityShareCard({
    super.key,
    required this.data,
    required this.template,
    required this.ink,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: cardSize.width,
      height: cardSize.height,
      child: switch (template) {
        ActivityShareTemplate.route => _RouteTemplate(
          data: data,
          ink: ink,
          l10n: l10n,
        ),
        ActivityShareTemplate.stats => _StatsTemplate(
          data: data,
          ink: ink,
          l10n: l10n,
        ),
        ActivityShareTemplate.photo => _PhotoTemplate(
          data: data,
          ink: ink,
          l10n: l10n,
          photoPath: photoPath,
        ),
        ActivityShareTemplate.sticker => _StickerTemplate(
          data: data,
          ink: ink,
          l10n: l10n,
        ),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 공용 조각
// ─────────────────────────────────────────────────────────────

/// 잉크 색에 맞춘 배경 — 흰 잉크면 어두운 보라, 검정이면 종이색, 보라면
/// 아주 연한 라벤더.
BoxDecoration _paperFor(ShareInkColor ink, {bool vivid = false}) {
  switch (ink) {
    case ShareInkColor.white:
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: vivid
              ? const [Color(0xFF7B5CFF), Color(0xFF3A22B8)]
              : const [Color(0xFF2A1B66), Color(0xFF0B0820)],
        ),
      );
    case ShareInkColor.black:
      return const BoxDecoration(color: Color(0xFFF4F1EA));
    case ShareInkColor.purple:
      return const BoxDecoration(color: Color(0xFFF3F0FF));
  }
}

List<Shadow>? _shadowFor(ShareInkColor ink, bool onImage) =>
    onImage && ink == ShareInkColor.white
    ? const [Shadow(color: Color(0x66000000), blurRadius: 8)]
    : null;

String _date(DateTime t) => DateFormat('yyyy.MM.dd').format(t);

class _Header extends StatelessWidget {
  final ActivityShareData data;
  final Color color;
  final List<Shadow>? shadows;

  const _Header({required this.data, required this.color, this.shadows});

  @override
  Widget build(BuildContext context) {
    final label = data.activityType.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(data.activityType.icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: ShareCardFonts.placeName(
                text: label,
                size: 12,
                color: color,
                letterSpacing: 1.2,
              ).copyWith(shadows: shadows),
            ),
            const Spacer(),
            Text(
              _date(data.startedAt),
              style: ShareCardFonts.mono(
                size: 11,
                color: color,
                opacity: 0.85,
              ).copyWith(shadows: shadows),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ShareCardFonts.placeName(
            text: data.title,
            size: 20,
            color: color,
          ).copyWith(height: 1.25, shadows: shadows),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final double size;
  final List<Shadow>? shadows;

  const _Stat({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
    this.size = 20,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: ShareCardFonts.ui(
            size: 10,
            weight: FontWeight.w600,
            color: color.withValues(alpha: 0.7),
          ).copyWith(shadows: shadows),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: ShareCardFonts.unbounded(
                  size: size,
                  color: color,
                ).copyWith(shadows: shadows),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: ShareCardFonts.mono(
                    size: size * 0.45,
                    color: color,
                    opacity: 0.8,
                  ).copyWith(shadows: shadows),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 거리 · 시간 · 평균(페이스/속도) 3칸.
class _StatsRow extends StatelessWidget {
  final ActivityShareData data;
  final AppLocalizations l10n;
  final Color color;
  final List<Shadow>? shadows;
  final double size;

  const _StatsRow({
    required this.data,
    required this.l10n,
    required this.color,
    this.shadows,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final avgLabel = data.activityType.usesPace
        ? l10n.runAvgPace
        : l10n.metricAvgSpeed;
    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: l10n.runDistance,
            value: data.distanceKm,
            unit: 'km',
            color: color,
            size: size,
            shadows: shadows,
          ),
        ),
        Expanded(
          child: _Stat(
            label: l10n.runTime,
            value: data.time,
            color: color,
            size: size,
            shadows: shadows,
          ),
        ),
        Expanded(
          child: _Stat(
            label: avgLabel,
            value: data.avgValue,
            unit: data.avgUnit,
            color: color,
            size: size,
            shadows: shadows,
          ),
        ),
      ],
    );
  }
}

class _Route extends StatelessWidget {
  final ActivityShareData data;
  final Color color;
  final double size;
  const _Route({required this.data, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: RouteStickerPainter(
          path: data.path,
          strokeColor: color,
          padding: 10,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 템플릿 1 — 경로 아트
// ─────────────────────────────────────────────────────────────

class _RouteTemplate extends StatelessWidget {
  final ActivityShareData data;
  final ShareInkColor ink;
  final AppLocalizations l10n;
  const _RouteTemplate({
    required this.data,
    required this.ink,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final c = ink.color;
    return DecoratedBox(
      decoration: _paperFor(ink),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(data: data, color: c),
            Expanded(
              child: Center(child: _Route(data: data, color: c, size: 280)),
            ),
            _StatsRow(data: data, l10n: l10n, color: c),
            const SizedBox(height: 22),
            Center(child: ShareCardLogoMark(color: c, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 템플릿 2 — 기록 강조
// ─────────────────────────────────────────────────────────────

class _StatsTemplate extends StatelessWidget {
  final ActivityShareData data;
  final ShareInkColor ink;
  final AppLocalizations l10n;
  const _StatsTemplate({
    required this.data,
    required this.ink,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final c = ink.color;
    final avgLabel = data.activityType.usesPace
        ? l10n.runAvgPace
        : l10n.metricAvgSpeed;
    return DecoratedBox(
      decoration: _paperFor(ink, vivid: true),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(data: data, color: c),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.distanceKm,
                style: ShareCardFonts.unbounded(
                  size: 104,
                  weight: FontWeight.w800,
                  color: c,
                  letterSpacing: -4,
                ).copyWith(height: 1),
              ),
            ),
            Text(
              'KILOMETERS',
              style: ShareCardFonts.unbounded(
                size: 14,
                color: c,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 28),
            Container(height: 1, color: c.withValues(alpha: 0.25)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: l10n.runTime,
                    value: data.time,
                    color: c,
                    size: 22,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: avgLabel,
                    value: data.avgValue,
                    unit: data.avgUnit,
                    color: c,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Stat(
              label: l10n.resultElevationGain,
              value: data.elevationGain.round().toString(),
              unit: 'm',
              color: c,
              size: 22,
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShareCardLogoMark(color: c, fontSize: 11),
                const Spacer(),
                _Route(data: data, color: c, size: 110),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 템플릿 3 — 사진 + 경로
// ─────────────────────────────────────────────────────────────

class _PhotoTemplate extends StatelessWidget {
  final ActivityShareData data;
  final ShareInkColor ink;
  final AppLocalizations l10n;
  final String? photoPath;
  const _PhotoTemplate({
    required this.data,
    required this.ink,
    required this.l10n,
    required this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final c = ink.color;
    final shadows = _shadowFor(ink, true);
    final path = photoPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path != null)
          Image.file(File(path), fit: BoxFit.cover)
        else
          DecoratedBox(decoration: _paperFor(ShareInkColor.white, vivid: true)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x59000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xA6000000),
              ],
              stops: [0, 0.25, 0.55, 1],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(data: data, color: c, shadows: shadows),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Route(data: data, color: c, size: 104),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stat(
                          label: l10n.runDistance,
                          value: data.distanceKm,
                          unit: 'km',
                          color: c,
                          size: 34,
                          shadows: shadows,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _Stat(
                                label: l10n.runTime,
                                value: data.time,
                                color: c,
                                size: 16,
                                shadows: shadows,
                              ),
                            ),
                            Expanded(
                              child: _Stat(
                                label: data.activityType.usesPace
                                    ? l10n.runAvgPace
                                    : l10n.metricAvgSpeed,
                                value: data.avgValue,
                                unit: data.avgUnit,
                                color: c,
                                size: 16,
                                shadows: shadows,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(child: ShareCardLogoMark(color: c, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 템플릿 4 — 투명 스티커
// ─────────────────────────────────────────────────────────────

class _StickerTemplate extends StatelessWidget {
  final ActivityShareData data;
  final ShareInkColor ink;
  final AppLocalizations l10n;
  const _StickerTemplate({
    required this.data,
    required this.ink,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final c = ink.color;
    final shadows = _shadowFor(ink, true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Route(data: data, color: c, size: 230),
          const SizedBox(height: 24),
          _StatsRow(
            data: data,
            l10n: l10n,
            color: c,
            shadows: shadows,
            size: 22,
          ),
          const SizedBox(height: 18),
          ShareCardLogoMark(color: c, fontSize: 11),
        ],
      ),
    );
  }
}
