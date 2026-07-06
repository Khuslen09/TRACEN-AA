import 'package:permission_handler/permission_handler.dart';

/// 앱이 사용하는 모든 권한을 한 곳에서 관리.
///
/// 책임:
///   - 위치 / 카메라 / 사진 라이브러리 권한 상태 조회
///   - 권한 요청 호출
///   - 영구 거부된 경우 앱 설정으로 이동
///
/// 화면 단(PermissionRequestScreen 등)에서는 이 서비스만 호출하고
/// permission_handler 패키지에 직접 의존하지 않음.
class PermissionService {
  PermissionService._();

  // ─────────────────────────────────────────────
  // 단일 권한 상태 조회
  // ─────────────────────────────────────────────

  static Future<AppPermissionStatus> locationStatus() =>
      _wrap(Permission.locationWhenInUse);

  static Future<AppPermissionStatus> cameraStatus() =>
      _wrap(Permission.camera);

  /// iOS는 photos, Android 13+는 photos, Android 12 이하는 storage.
  /// permission_handler가 OS 버전에 따라 적절히 매핑해줌.
  static Future<AppPermissionStatus> photosStatus() =>
      _wrap(Permission.photos);

  // ─────────────────────────────────────────────
  // 단일 권한 요청
  // ─────────────────────────────────────────────

  static Future<AppPermissionStatus> requestLocation() async {
    final result = await Permission.locationWhenInUse.request();
    return _toAppStatus(result);
  }

  static Future<AppPermissionStatus> requestCamera() async {
    final result = await Permission.camera.request();
    return _toAppStatus(result);
  }

  static Future<AppPermissionStatus> requestPhotos() async {
    final result = await Permission.photos.request();
    return _toAppStatus(result);
  }

  // ─────────────────────────────────────────────
  // 일괄 조회 / 요청
  // ─────────────────────────────────────────────

  /// 화면 진입 시 한 번에 3개 권한 상태 조회.
  static Future<AllPermissions> getAll() async {
    final results = await Future.wait([
      locationStatus(),
      cameraStatus(),
      photosStatus(),
    ]);
    return AllPermissions(
      location: results[0],
      camera: results[1],
      photos: results[2],
    );
  }

  /// 모든 권한이 granted인지 한 번에 확인 — Home 진입 전 검사용.
  static Future<bool> areAllGranted() async {
    final all = await getAll();
    return all.location == AppPermissionStatus.granted &&
        all.camera == AppPermissionStatus.granted &&
        all.photos == AppPermissionStatus.granted;
  }

  /// 영구 거부된 권한이 있을 때 사용자를 앱 설정 화면으로 이동.
  /// (시스템 다이얼로그 다시 띄울 수 없는 상태이므로 설정에서 직접 켜야 함)
  static Future<bool> openSettings() => openAppSettings();

  // ─────────────────────────────────────────────
  // 내부 변환
  // ─────────────────────────────────────────────

  static Future<AppPermissionStatus> _wrap(Permission permission) async {
    final status = await permission.status;
    return _toAppStatus(status);
  }

  /// permission_handler의 PermissionStatus enum을 우리 도메인 enum으로 단순화.
  /// (limited, restricted 등 세부 상태는 화면에서 신경 쓸 필요 없음)
  static AppPermissionStatus _toAppStatus(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return AppPermissionStatus.granted;
    if (s.isPermanentlyDenied) return AppPermissionStatus.permanentlyDenied;
    if (s.isDenied) return AppPermissionStatus.denied;
    if (s.isRestricted) return AppPermissionStatus.permanentlyDenied;
    return AppPermissionStatus.notDetermined;
  }
}

/// 화면에서 다루기 쉬운 단순화된 권한 상태.
enum AppPermissionStatus {
  /// 아직 요청한 적 없음 (iOS의 .notDetermined와 동일)
  notDetermined,

  /// 허용됨 (iOS의 limited 포함 — 일부 사진만 허용 등도 우리에겐 OK)
  granted,

  /// 거부됨 — 다시 요청 가능
  denied,

  /// 영구 거부 또는 OS 차원에서 차단 — 앱 설정에서만 변경 가능
  permanentlyDenied,
}

/// 3가지 권한 상태를 한 묶음으로 다루는 값 객체.
class AllPermissions {
  final AppPermissionStatus location;
  final AppPermissionStatus camera;
  final AppPermissionStatus photos;

  const AllPermissions({
    required this.location,
    required this.camera,
    required this.photos,
  });
}
