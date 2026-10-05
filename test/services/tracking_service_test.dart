import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracen/services/tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackingService.isAccurateEnough', () {
    test('정확도가 임계값 이하면 true', () {
      expect(TrackingService.isAccurateEnough(10.0), isTrue);
      expect(TrackingService.isAccurateEnough(30.0), isTrue); // 경계값
    });

    test('정확도가 임계값 초과면 false', () {
      expect(TrackingService.isAccurateEnough(30.1), isFalse);
      expect(TrackingService.isAccurateEnough(100.0), isFalse);
    });
  });

  group('TrackingService.isEnabled', () {
    test('저장된 값이 없으면 기본값 false', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await TrackingService.isEnabled(), isFalse);
    });

    test('저장된 true 값을 그대로 반환', () async {
      SharedPreferences.setMockInitialValues({'auto_tracking_enabled': true});
      expect(await TrackingService.isEnabled(), isTrue);
    });
  });
}
