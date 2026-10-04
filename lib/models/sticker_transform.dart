import 'package:flutter/material.dart';

/// 스티커(날짜/지도/위치명/로고)의 기본 위치 대비 오프셋 + 배율.
/// 불변 값 타입 — [ShareCardController]가 스티커별로 하나씩 들고 있는다.
@immutable
class StickerTransform {
  final Offset offset;
  final double scale;

  const StickerTransform({this.offset = Offset.zero, this.scale = 1.0});

  const StickerTransform.identity() : offset = Offset.zero, scale = 1.0;

  StickerTransform copyWith({Offset? offset, double? scale}) => StickerTransform(
    offset: offset ?? this.offset,
    scale: scale ?? this.scale,
  );

  @override
  bool operator ==(Object other) =>
      other is StickerTransform && other.offset == offset && other.scale == scale;

  @override
  int get hashCode => Object.hash(offset, scale);
}
