import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/models/pin.dart';
import 'package:tracen/models/share_card_template.dart';
import 'package:tracen/models/sticker_id.dart';
import 'package:tracen/widgets/share_card/share_card_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pin = Pin(
    uuid: 'test-uuid',
    lat: 37.5665,
    lng: 126.9780,
    createdAt: DateTime(2026, 10, 4),
  );

  group('ShareCardController', () {
    test('초기 상태는 minimal 템플릿 + 모든 스티커 표시 + 기본 transform', () async {
      final controller = await ShareCardController.load(pin);
      expect(controller.template, ShareCardTemplate.minimal);
      for (final id in StickerId.values) {
        expect(controller.isVisible(id), isTrue);
        expect(controller.transformFor(id).offset, Offset.zero);
        expect(controller.transformFor(id).scale, 1.0);
      }
    });

    test('드래그/핀치 제스처가 해당 스티커의 transform만 갱신', () async {
      final controller = await ShareCardController.load(pin);
      controller.beginStickerGesture(StickerId.logo);
      controller.updateStickerGesture(StickerId.logo, const Offset(10, -5), 1.0);

      expect(controller.transformFor(StickerId.logo).offset, const Offset(10, -5));
      // 건드리지 않은 스티커는 그대로.
      expect(controller.transformFor(StickerId.date).offset, Offset.zero);
    });

    test('핀치 배율은 제스처 시작 시점 배율에 누적 배율을 곱함', () async {
      final controller = await ShareCardController.load(pin);
      controller.beginStickerGesture(StickerId.map);
      controller.updateStickerGesture(StickerId.map, Offset.zero, 1.5);
      expect(controller.transformFor(StickerId.map).scale, closeTo(1.5, 1e-9));

      // 같은 제스처 세션 안에서 추가 업데이트 — 시작 시점(1.0) 기준 누적.
      controller.updateStickerGesture(StickerId.map, Offset.zero, 2.0);
      expect(controller.transformFor(StickerId.map).scale, closeTo(2.0, 1e-9));
    });

    test('setTemplate이 모든 오버라이드를 비우고 새 템플릿 기본값으로 리셋', () async {
      final controller = await ShareCardController.load(pin);
      controller.beginStickerGesture(StickerId.logo);
      controller.updateStickerGesture(StickerId.logo, const Offset(20, 20), 1.8);
      expect(controller.transformFor(StickerId.logo).offset, isNot(Offset.zero));

      controller.setTemplate(ShareCardTemplate.film);
      expect(controller.template, ShareCardTemplate.film);
      expect(controller.transformFor(StickerId.logo).offset, Offset.zero);
      expect(controller.transformFor(StickerId.logo).scale, 1.0);
    });

    test('toggleVisibility가 해당 스티커만 토글', () async {
      final controller = await ShareCardController.load(pin);
      expect(controller.isVisible(StickerId.map), isTrue);
      controller.toggleVisibility(StickerId.map);
      expect(controller.isVisible(StickerId.map), isFalse);
      expect(controller.isVisible(StickerId.date), isTrue);
      controller.toggleVisibility(StickerId.map);
      expect(controller.isVisible(StickerId.map), isTrue);
    });

    test('selectSticker가 selectedSticker를 갱신', () async {
      final controller = await ShareCardController.load(pin);
      expect(controller.selectedSticker, isNull);
      controller.selectSticker(StickerId.place);
      expect(controller.selectedSticker, StickerId.place);
      controller.selectSticker(null);
      expect(controller.selectedSticker, isNull);
    });
  });
}
