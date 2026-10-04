import 'package:flutter_test/flutter_test.dart';
import 'package:tracen/utils/script_detector.dart';

void main() {
  group('containsHangul', () {
    test('한글 문자열 → true', () {
      expect(containsHangul('한양대학교 ERICA캠퍼스'), isTrue);
    });

    test('영문만 → false', () {
      expect(containsHangul('Starbucks Gangnam'), isFalse);
    });

    test('혼합 문자열 → true', () {
      expect(containsHangul('Seoul 서울'), isTrue);
    });

    test('빈 문자열 → false', () {
      expect(containsHangul(''), isFalse);
    });
  });
}
