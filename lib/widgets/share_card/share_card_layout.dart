import 'package:flutter/material.dart';

import '../../models/share_card_template.dart';
import '../../models/sticker_id.dart';
import '../../models/sticker_transform.dart';

/// 360×640 논리 좌표계 기준, 템플릿별 스티커 기본 위치/크기 테이블.
/// 미리보기(`ShareCard(interactive:true)`)와 내보내기 인스턴스가 공유하는
/// 단일 레이아웃 소스 — 템플릿을 바꾸면 [ShareCardController.setTemplate]이
/// 이 기본값으로 리셋한다.
///
/// `stamp` 템플릿은 나라명/외곽선/위치명/날짜가 원형 도장 하나로 합쳐지는
/// 디자인이라 `date`/`place` 스티커는 별도로 그려지지 않고 `map` 스티커(도장
/// 전체)에 내용으로 포함됨 — [baseRectFor]는 데이터 일관성을 위해 그래도
/// 값을 돌려주지만, `ShareCard`가 `stamp`일 때는 `date`/`place` 위젯 자체를
/// 렌더링하지 않는다(토글은 도장 안 해당 줄의 표시 여부로 동작).
class ShareCardLayout {
  ShareCardLayout._();

  static const Size cardSize = Size(360, 640);

  /// 지도/도장 스티커의 기본 한 변 길이.
  static const double mapSize = 112;
  static const double stampDiscSize = 196;

  static Map<StickerId, StickerTransform> defaultsFor(ShareCardTemplate template) {
    return {
      for (final id in StickerId.values) id: const StickerTransform.identity(),
    };
  }

  static Rect baseRectFor(StickerId id, ShareCardTemplate template) {
    return switch (template) {
      // 원본은 스티커를 안 그리지만 switch를 완결하려고 미니멀 배치를 쓴다.
      ShareCardTemplate.original || ShareCardTemplate.minimal => _minimalRect(id),
      ShareCardTemplate.film => _filmRect(id),
      ShareCardTemplate.stamp => _stampRect(id),
    };
  }

  static Rect _minimalRect(StickerId id) {
    const margin = 24.0;
    switch (id) {
      case StickerId.date:
        return const Rect.fromLTWH(margin, 30, 150, 44);
      case StickerId.map:
        return Rect.fromLTWH(
          margin,
          cardSize.height - 30 - mapSize,
          mapSize,
          mapSize,
        );
      case StickerId.place:
        final mapRect = _minimalRect(StickerId.map);
        return Rect.fromLTWH(
          mapRect.right + 12,
          mapRect.top + (mapRect.height - 88) / 2,
          cardSize.width - mapRect.right - 12 - margin,
          88,
        );
      case StickerId.logo:
        return const Rect.fromLTWH(246, 592, 90, 20);
      case StickerId.route:
        return Rect.fromLTWH(cardSize.width - margin - 90, 30, 90, 90);
    }
  }

  static Rect _filmRect(StickerId id) {
    // 하드 테두리는 없음(스크림 그라데이션으로 대체) — frame/bandHeight는
    // 그냥 배치 기준 숫자.
    const frame = 16.0;
    const bandHeight = 108.0;
    final bandTop = cardSize.height - frame - bandHeight;
    switch (id) {
      case StickerId.date:
        return Rect.fromLTWH(cardSize.width - frame - 10 - 96, bandTop - 10 - 24, 96, 24);
      case StickerId.map:
        return Rect.fromLTWH(frame + 14, bandTop + (bandHeight - 72) / 2, 72, 72);
      case StickerId.place:
        final mapRect = _filmRect(StickerId.map);
        return Rect.fromLTWH(
          mapRect.right + 12,
          bandTop + 16,
          cardSize.width - mapRect.right - 12 - frame - 36,
          bandHeight - 32,
        );
      case StickerId.logo:
        return Rect.fromLTWH(cardSize.width - frame - 28, bandTop + 14, 18, bandHeight - 28);
      case StickerId.route:
        return Rect.fromLTWH(frame + 14, 30, 80, 80);
    }
  }

  static Rect _stampRect(StickerId id) {
    final discRect = Rect.fromLTWH(
      (cardSize.width - stampDiscSize) / 2,
      cardSize.height * 0.52 - stampDiscSize / 2,
      stampDiscSize,
      stampDiscSize,
    );
    switch (id) {
      case StickerId.map:
        return discRect;
      case StickerId.date:
      case StickerId.place:
      case StickerId.route:
        // 도장 안에 내용으로 녹아 들어가서 독립적으로 그려지지 않음(route는
        // 스탬프에서 아예 스티커로 안 둠, `ShareCard._activeStickerIds`
        // 참고) — 위치 데이터는 일관성을 위해 도장 영역을 그대로 돌려줌.
        return discRect;
      case StickerId.logo:
        return const Rect.fromLTWH(130, 578, 100, 24);
    }
  }
}
