import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracen/models/pin_category.dart';
import 'package:tracen/services/category_color_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PinCategory.setCustom(const []);
    await CategoryColorNotifier.instance.init();
  });

  group('PinCategory.fromKey', () {
    test('빈 값이면 general', () {
      expect(PinCategory.fromKey(null), PinCategory.general);
      expect(PinCategory.fromKey(''), PinCategory.general);
    });

    test('모르는 key도 버리지 않고 그대로 보존', () {
      final c = PinCategory.fromKey('custom_123');
      expect(c.key, 'custom_123');
      expect(c.isCustom, isTrue);
    });
  });

  group('CategoryColorNotifier 추가/삭제', () {
    test('추가하면 목록 맨 뒤에 붙고 이름/아이콘/색이 저장된다', () async {
      final n = CategoryColorNotifier.instance;
      final c = await n.addCategory(
        name: '산책로',
        iconKey: 'nature',
        color: const Color(0xFF10B981),
      );

      expect(PinCategory.values.last, c);
      expect(n.labelOf(c), '산책로');
      expect(n.iconOf(c), Icons.park_rounded);
      expect(n.colorOf(c).toARGB32(), 0xFF10B981);

      // 앱 재시작처럼 다시 로드해도 유지.
      PinCategory.setCustom(const []);
      await n.init();
      expect(PinCategory.values, contains(c));
      expect(n.labelOf(c), '산책로');
    });

    test('추가한 카테고리는 삭제되고, 기본 6종은 삭제 불가', () async {
      final n = CategoryColorNotifier.instance;
      final c = await n.addCategory(
        name: '임시',
        iconKey: 'star',
        color: const Color(0xFFEC4899),
      );

      await n.deleteCategory(c);
      expect(PinCategory.values, isNot(contains(c)));

      await n.deleteCategory(PinCategory.food);
      expect(PinCategory.values, contains(PinCategory.food));
    });

    test('초기화는 기본 6종만 되돌리고 추가한 카테고리는 유지', () async {
      final n = CategoryColorNotifier.instance;
      await n.updateName(PinCategory.food, '맛집');
      final c = await n.addCategory(
        name: '여행',
        iconKey: 'beach',
        color: const Color(0xFF3B82F6),
      );

      await n.reset();
      expect(n.labelOf(PinCategory.food), PinCategory.food.label);
      expect(n.labelOf(c), '여행');
    });
  });

  group('클라우드 동기화 포맷(export/import)', () {
    test('내보낸 값을 다른 기기(빈 저장소)에 넣으면 그대로 복원', () async {
      final n = CategoryColorNotifier.instance;
      await n.updateName(PinCategory.cafe, '단골 카페');
      final c = await n.addCategory(
        name: '전시회',
        iconKey: 'celebration',
        color: const Color(0xFFEC4899),
      );
      final exported = await CategoryColorService.exportAll();

      // 다른 기기: 저장소 비우고 기본값 상태에서 가져오기.
      SharedPreferences.setMockInitialValues({});
      PinCategory.setCustom(const []);
      await n.init();
      expect(PinCategory.values, isNot(contains(c)));

      await CategoryColorService.importAll(exported);
      await n.init();
      expect(n.labelOf(PinCategory.cafe), '단골 카페');
      expect(PinCategory.values.last, c);
      expect(n.labelOf(c), '전시회');
      expect(n.colorOf(c).toARGB32(), 0xFFEC4899);
    });

    test('가져오기는 기존 로컬 값을 통째로 교체', () async {
      final n = CategoryColorNotifier.instance;
      final local = await n.addCategory(
        name: '로컬 전용',
        iconKey: 'star',
        color: const Color(0xFF6B7280),
      );
      await n.updateName(PinCategory.food, '로컬 이름');

      await CategoryColorService.importAll(const {
        'customKeys': <String>[],
        'items': <String, dynamic>{},
      });
      await n.init();
      expect(PinCategory.values, isNot(contains(local)));
      expect(n.labelOf(PinCategory.food), PinCategory.food.label);
    });
  });
}
