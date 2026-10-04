import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../theme/app_colors.dart';
import '../../utils/country_outline_painter.dart';
import 'route_sticker_painter.dart';
import 'share_card_fonts.dart';
import 'share_card_layout.dart';
import 'share_card_logo_mark.dart';
import 'share_card_view_model.dart';

const _weekdaysEn = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

String _two(int n) => n.toString().padLeft(2, '0');

String _fullDate(DateTime d) => '${d.year}.${_two(d.month)}.${_two(d.day)}';

String _filmDate(DateTime d) => "'${_two(d.year % 100)} ${_two(d.month)} ${_two(d.day)}";

String _stampDate(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  return '${_two(d.day)} ${months[d.month - 1]} ${d.year}';
}

const _textShadow = [Shadow(color: Color(0x80000000), blurRadius: 6, offset: Offset(0, 1))];

String _formatCoords(double lat, double lng) {
  final ns = lat >= 0 ? 'N' : 'S';
  final ew = lng >= 0 ? 'E' : 'W';
  return '${lat.abs().toStringAsFixed(4)}°$ns  ${lng.abs().toStringAsFixed(4)}°$ew';
}

/// 360×640 논리 크기의 공유 카드. [interactive]가 켜져 있으면 각 스티커를
/// 드래그/핀치로 재배치할 수 있고, 꺼져 있으면(= 내보내기용 인스턴스) 같은
/// 위젯 트리를 선택 표시만 없이 그대로 그린다 — 미리보기와 내보내기가
/// 레이아웃이 어긋날 수 없는 이유(아키텍처 결정, PLAN 참고).
class ShareCard extends StatelessWidget {
  final ShareCardViewModel model;
  final bool interactive;
  final StickerId? selectedSticker;
  final void Function(StickerId id)? onStickerSelected;
  final void Function(StickerId id)? onStickerGestureStart;
  final void Function(StickerId id, Offset focalPointDelta, double scale)? onStickerGestureUpdate;
  final void Function(StickerId id)? onStickerTap;

  const ShareCard({
    super.key,
    required this.model,
    this.interactive = false,
    this.selectedSticker,
    this.onStickerSelected,
    this.onStickerGestureStart,
    this.onStickerGestureUpdate,
    this.onStickerTap,
  });

  List<StickerId> get _activeStickerIds {
    if (model.template == ShareCardTemplate.stamp) {
      // 날짜/위치명처럼 경로도 도장 안에 녹여넣지 않고 그냥 생략 — 스탬프는
      // 지도+로고만 독립 스티커.
      return const [StickerId.map, StickerId.logo];
    }
    return StickerId.values;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ShareCardLayout.cardSize.width,
      height: ShareCardLayout.cardSize.height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: _buildBackground()),
            Positioned.fill(child: IgnorePointer(child: _buildScrim())),
            for (final id in _activeStickerIds)
              if (model.isVisible(id)) _buildSticker(context, id),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final photo = model.photo;
    if (photo == null) {
      return const ColoredBox(color: Color(0xFF1A1D27));
    }
    final raw = RawImage(image: photo, fit: BoxFit.cover);
    final matrix = model.previewColorMatrix;
    if (matrix == null) return raw;
    // 실시간 필터 미리보기 — 래스터화 없이 GPU 합성만(필터 선택의 싼 근사
    // 치). 정확한 LUT 결과는 저장/공유 시 호출부가 [photo] 자체를 구워서
    // 넣는다(그때는 matrix가 반드시 null).
    return ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: raw);
  }

  /// 사진 위에 텍스트/지도가 잘 읽히게 위/아래를 살짝 어둡게 — 스탬프
  /// 템플릿이거나 잉크색이 먹색이면 그 자체로 이미 충분히 대비돼서 끔.
  Widget _buildScrim() {
    if (model.template == ShareCardTemplate.stamp || model.inkColor == ShareInkColor.black) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x99000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xB3000000),
          ],
          stops: [0.0, 0.22, 0.55, 1.0],
        ),
      ),
    );
  }

  Widget _buildSticker(BuildContext context, StickerId id) {
    final baseRect = ShareCardLayout.baseRectFor(id, model.template);
    final transform = model.transformOf(id);
    final effectiveRect = Rect.fromCenter(
      center: baseRect.center + transform.offset,
      width: baseRect.width * transform.scale,
      height: baseRect.height * transform.scale,
    );
    final isSelected = interactive && selectedSticker == id;

    Widget content = _contentFor(id, effectiveRect.size);
    if (isSelected) {
      content = DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.5)),
        child: content,
      );
    }

    if (!interactive) {
      return Positioned.fromRect(rect: effectiveRect, child: content);
    }

    return Positioned.fromRect(
      rect: effectiveRect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onStickerTap == null ? null : () => onStickerTap!(id),
        onScaleStart: (_) {
          onStickerSelected?.call(id);
          onStickerGestureStart?.call(id);
        },
        onScaleUpdate: (details) {
          onStickerGestureUpdate?.call(id, details.focalPointDelta, details.scale);
        },
        child: content,
      ),
    );
  }

  Widget _contentFor(StickerId id, Size size) {
    switch (id) {
      case StickerId.date:
        return _DateContent(model: model, size: size);
      case StickerId.map:
        return _MapContent(model: model, size: size);
      case StickerId.place:
        return _PlaceContent(model: model, size: size);
      case StickerId.logo:
        return _LogoContent(model: model, size: size);
      case StickerId.route:
        return _RouteContent(model: model, size: size);
    }
  }
}

class _RouteContent extends StatelessWidget {
  final ShareCardViewModel model;
  final Size size;
  const _RouteContent({required this.model, required this.size});

  @override
  Widget build(BuildContext context) {
    if (model.routePath.length < 2) return SizedBox.fromSize(size: size);
    final color = model.template == ShareCardTemplate.film ? AppColors.primary : model.inkColor.color;
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: RouteStickerPainter(path: model.routePath, strokeColor: color),
      ),
    );
  }
}

class _DateContent extends StatelessWidget {
  final ShareCardViewModel model;
  final Size size;
  const _DateContent({required this.model, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = model.inkColor.color;
    if (model.template == ShareCardTemplate.film) {
      return SizedBox.fromSize(
        size: size,
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(
            _filmDate(model.date),
            style: ShareCardFonts.mono(
              size: 15,
              weight: FontWeight.w600,
              color: AppColors.primary,
            ).copyWith(
              shadows: [
                Shadow(color: AppColors.primary.withValues(alpha: 0.65), blurRadius: 8),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox.fromSize(
      size: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fullDate(model.date),
            style: ShareCardFonts.mono(size: 15, weight: FontWeight.w600, color: color, letterSpacing: 1.2)
                .copyWith(shadows: _textShadow),
          ),
          const SizedBox(height: 2),
          Text(
            _weekdaysEn[model.date.weekday - 1],
            style: ShareCardFonts.mono(size: 10, color: color, letterSpacing: 3, opacity: 0.8)
                .copyWith(shadows: _textShadow),
          ),
        ],
      ),
    );
  }
}

class _MapContent extends StatelessWidget {
  final ShareCardViewModel model;
  final Size size;
  const _MapContent({required this.model, required this.size});

  @override
  Widget build(BuildContext context) {
    final country = model.countryOutline;
    final color = model.inkColor.color;

    if (model.template == ShareCardTemplate.stamp) {
      return SizedBox.fromSize(
        size: size,
        child: Transform.rotate(
          angle: -8 * math.pi / 180,
          child: Opacity(
            opacity: 0.94,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (model.isVisible(StickerId.place) && country != null)
                          Text(
                            country.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: ShareCardFonts.mono(size: 8, color: color, letterSpacing: 2.2),
                          ),
                        const SizedBox(height: 4),
                        if (country != null)
                          Expanded(
                            child: CustomPaint(
                              painter: CountryOutlinePainter(
                                country: country,
                                pinLat: model.pinLat,
                                pinLng: model.pinLng,
                                strokeColor: color,
                                pinColor: color,
                                padding: 2,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (model.isVisible(StickerId.place) && model.placeName != null)
                          Text(
                            model.placeName!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: ShareCardFonts.placeName(
                              text: model.placeName!,
                              size: 12,
                              weight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        if (model.isVisible(StickerId.date)) ...[
                          const SizedBox(height: 4),
                          Text(
                            _stampDate(model.date),
                            textAlign: TextAlign.center,
                            style: ShareCardFonts.mono(size: 9, color: color, opacity: 0.85),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (country == null) return SizedBox.fromSize(size: size);
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: CountryOutlinePainter(
          country: country,
          pinLat: model.pinLat,
          pinLng: model.pinLng,
          strokeColor: model.template == ShareCardTemplate.film ? AppColors.primary : color,
          pinColor: model.template == ShareCardTemplate.film ? AppColors.primary : color,
        ),
      ),
    );
  }
}

class _PlaceContent extends StatelessWidget {
  final ShareCardViewModel model;
  final Size size;
  const _PlaceContent({required this.model, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = model.inkColor.color;
    final isFilm = model.template == ShareCardTemplate.film;
    final place = model.placeName?.toUpperCase();
    final country = model.countryOutline?.name.toUpperCase();

    return SizedBox.fromSize(
      size: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (place != null)
            _ShrinkToFitText(
              text: place,
              maxSize: isFilm ? 17 : 24,
              minSize: 12,
              maxLines: 2,
              styleFor: (s) => ShareCardFonts.placeName(text: place, size: s, color: color)
                  .copyWith(shadows: _textShadow),
            ),
          if (country != null) ...[
            const SizedBox(height: 3),
            Text(
              country,
              style: ShareCardFonts.mono(size: 11, color: color, letterSpacing: 2, opacity: 0.85)
                  .copyWith(shadows: _textShadow),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatCoords(model.pinLat, model.pinLng),
            style: ShareCardFonts.mono(size: 9, color: color, opacity: 0.8).copyWith(shadows: _textShadow),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 긴 위치명이 박스 폭을 넘치면 [maxSize]에서 [minSize]까지 1px씩 줄여가며
/// [maxLines] 안에 들어가는 첫 크기로 그린다 — 그래도 안 들어가면
/// [minSize]에서 말줄임. 새 패키지(auto_size_text 등) 없이 `TextPainter`로
/// 직접 측정(이 저장소가 Canvas/TextPainter를 직접 쓰는 걸 선호하는 기존
/// 관례와 일치 — `TracenOverlayPainter` 등 참고).
class _ShrinkToFitText extends StatelessWidget {
  final String text;
  final TextStyle Function(double size) styleFor;
  final double maxSize;
  final double minSize;
  final int maxLines;

  const _ShrinkToFitText({
    required this.text,
    required this.styleFor,
    required this.maxSize,
    this.minSize = 12,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var fontSize = maxSize;
        while (fontSize > minSize) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: styleFor(fontSize)),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);
          if (!painter.didExceedMaxLines) break;
          fontSize -= 1;
        }
        return Text(
          text,
          style: styleFor(fontSize),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _LogoContent extends StatelessWidget {
  final ShareCardViewModel model;
  final Size size;
  const _LogoContent({required this.model, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = model.inkColor.color;
    final vertical = model.template == ShareCardTemplate.film;
    return SizedBox.fromSize(
      size: size,
      child: Align(
        alignment: vertical ? Alignment.center : Alignment.bottomRight,
        child: ShareCardLogoMark(
          color: color,
          iconSize: vertical ? 10 : 12,
          fontSize: vertical ? 8 : 10,
          direction: vertical ? Axis.vertical : Axis.horizontal,
        ),
      ),
    );
  }
}
