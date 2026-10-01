import '../l10n/strings.dart';
import 'package:geolocator/geolocator.dart';

/// 디바이스 GPS 관련 책임만 갖는 서비스.
///
/// "DB에 저장된 위치 이력 조회"는 RouteDBService의 몫이므로
/// 여기서는 절대 import하지 않습니다. (단일 책임 원칙)
class LocationService {
  /// 위치 서비스 활성화 + 권한 확인/요청.
  ///
  /// 호출 측에서 try-catch로 감싸 사용자에게 안내 메시지 표시할 것.
  /// - 디바이스 위치 서비스가 꺼져있으면 → Exception
  /// - 사용자가 권한 거부 → 다시 요청
  /// - 영구 거부 → Exception (앱 설정에서 직접 켜야 함)
  static Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(Strings.current.locationServiceOff);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(Strings.current.locationPermissionDenied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(Strings.current.locationPermissionDeniedForever);
    }
  }

  /// GPS 위치 스트림.
  ///
  /// [distanceFilter]가 5m라서 사용자가 5m 이상 움직였을 때만
  /// 새 이벤트가 발생합니다 — 배터리 + DB INSERT 횟수를 줄이는 효과.
  static Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }

  /// 현재 위치 1회 조회 (스트림이 첫 이벤트를 주기 전 즉시 위치가 필요할 때).
  static Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}