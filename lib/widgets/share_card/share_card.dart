import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/share_card_template.dart';
import '../../models/share_ink_color.dart';
import '../../models/sticker_id.dart';
import '../../utils/country_outline_painter.dart';
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

  const ShareCard({
    super.key,
    required this.model,
    this.interactive = false,
    this.selectedSticker,
    this.onStickerSelected,
    this.onStickerGestureStart,
    this.onStickerGestureUpdate,
  });

  List<StickerId> get _activeStickerIds {
    if (model.template == ShareCardTemplate.stamp) {
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
            ..._buildFrameDecoration(),
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
    return RawImage(image: photo, fit: BoxFit.cover);
  }

  List<Widget> _buildFrameDecoration() {
    if (model.template != ShareCardTemplate.film) return const [];
    final frameColor = model.inkColor == ShareInkColor.black
        ? const Color(0xFFF3EFE6)
        : const Color(0xFF121212);
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(painter: _FilmFramePainter(color: frameColor)),
        ),
      ),
    ];
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
    }
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
              color: const Color(0xFFFF9A4D),
            ).copyWith(
              shadows: [
                Shadow(color: const Color(0xFFFF9A4D).withValues(alpha: 0.65), blurRadius: 8),
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
          Text(_fullDate(model.date), style: ShareCardFonts.mono(size: 15, weight: FontWeight.w600, color: color, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(
            _weekdaysEn[model.date.weekday - 1],
            style: ShareCardFonts.mono(size: 10, color: color, letterSpacing: 3, opacity: 0.8),
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
                            style: ShareCardFonts.unbounded(size: 12, weight: FontWeight.w600, color: color),
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
          strokeColor: model.template == ShareCardTemplate.film ? const Color(0xFFFF9A4D) : color,
          pinColor: model.template == ShareCardTemplate.film ? const Color(0xFFFF9A4D) : color,
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
            Text(
              place,
              style: ShareCardFonts.unbounded(size: isFilm ? 13 : 17, weight: FontWeight.w700, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (country != null) ...[
            const SizedBox(height: 2),
            Text(
              country,
              style: ShareCardFonts.mono(size: 10, color: color, letterSpacing: 1.8, opacity: 0.85),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            _formatCoords(model.pinLat, model.pinLng),
            style: ShareCardFonts.mono(size: 9, color: color, opacity: 0.8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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

class _FilmFramePainter extends CustomPainter {
  final Color color;
  const _FilmFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const frame = 16.0;
    const bandHeight = 108.0;
    final paint = Paint()..color = color;

    // 위/좌/우 테두리
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, frame), paint);
    canvas.drawRect(Rect.fromLTWH(0, 0, frame, size.height), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - frame, 0, frame, size.height), paint);
    // 아래쪽 띠(테두리 포함)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - frame - bandHeight, size.width, frame + bandHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FilmFramePainter oldDelegate) => oldDelegate.color != color;
}
