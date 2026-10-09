import '../models/pin.dart';
import 'cloud_sync_service.dart';
import 'place_name_service.dart';
import 'route_db_service.dart';

/// 핀의 POI 위치명을 조회해서 영구 저장하는 오케스트레이션 — **핀 저장
/// 직후 1회만** 호출하고, 공유 카드를 열 때마다 재조회하지 않는다
/// ([ShareCardController]는 `pin.placeCandidates`가 이미 있으면 그걸 쓰고,
/// 비어 있을 때만 이 함수를 지연 호출한다 — 옛날에 저장된 핀 대응).
///
/// 베스트에포트: POI 조회가 실패/빈 결과면 기존 역지오코딩(동/시 단위)으로
/// 폴백. 둘 다 실패해도 조용히 아무 것도 안 하고 끝남 — throw 없음, 핀
/// 저장 자체를 막지 않음(fire-and-forget로 호출하는 게 전제).
class PinPlaceLookupService {
  PinPlaceLookupService._();

  /// 성공하면 갱신된 [Pin]을 돌려준다(호출부가 화면 상태를 바로 갱신할 수
  /// 있게) — 아무 것도 못 얻었으면 `null`.
  static Future<Pin?> resolveAndPersist(
    Pin pin, {
    required String languageCode,
  }) async {
    if (pin.id == null) return null; // 아직 로컬 DB에 없는 핀 — 저장할 곳이 없음
    // 이미 placeName이 있으면(사진 편집 화면에서 사용자가 직접 골랐거나,
    // 전에 이미 이 함수로 채워졌으면) 건너뜀 — 자동 조회가 사용자의 선택을
    // 조용히 덮어쓰면 안 된다.
    if (pin.placeName != null) return null;

    final candidates = await PlaceNameService.poiCandidatesFor(
      pin.lat,
      pin.lng,
      languageCode: languageCode,
    );

    String? placeName;
    String? placeCity;
    if (candidates.isNotEmpty) {
      placeName = candidates.first.name;
      placeCity = candidates.first.city;
    } else {
      placeName = await PlaceNameService.placeNameFor(pin.lat, pin.lng);
      placeCity = placeName;
    }

    if (placeName == null && candidates.isEmpty) return null; // 아무 것도 못 얻음

    final updated = pin.copyWith(
      placeName: placeName,
      placeCity: placeCity,
      placeCandidates: candidates,
    );
    await RouteDBService.updatePin(updated);
    CloudSyncService.syncPinAdded(updated);
    return updated;
  }
}
