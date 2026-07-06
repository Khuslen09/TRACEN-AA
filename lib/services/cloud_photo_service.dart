import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Firebase Storage에 사진을 올리고 내리는 서비스.
///
/// 저장 경로 규칙 (FIRESTORE_SCHEMA.md 3.2 참조):
///   users/{uid}/photos/{routeUuid}/{pinUuid}.jpg
///
/// 이렇게 하면:
///   - 사용자 격리: Storage 보안 규칙을 한 줄로 적용 가능
///   - 여정 단위 정리: 여정 삭제 시 폴더 통째로 제거 가능
///
/// 모든 메서드는 사용자 격리를 강제하기 위해 uid를 명시적으로 받음.
/// (currentUser에 묵시적으로 의존하면 로그아웃 직후 경로 꼬임 발생)
class CloudPhotoService {
  CloudPhotoService._();

  static final _storage = FirebaseStorage.instance;

  /// 로컬 파일을 Firebase Storage에 업로드.
  ///
  /// 반환값:
  ///   - downloadUrl: 어디서든 이미지 표시할 때 쓸 HTTPS URL
  ///   - storagePath: 나중에 삭제할 때 쓸 Storage 내부 경로
  ///
  /// 두 값 모두 Firestore 핀 문서에 저장합니다.
  /// (URL만 갖고는 삭제 못 하기 때문에 path도 함께 보존)
  static Future<({String downloadUrl, String storagePath})> uploadPinPhoto({
    required String uid,
    required String routeUuid,
    required String pinUuid,
    required File localFile,
  }) async {
    final ext = _extOf(localFile.path);
    final storagePath = 'users/$uid/photos/$routeUuid/$pinUuid$ext';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: _mimeFor(ext),
      cacheControl: 'public, max-age=31536000', // 1년 — 사진은 변하지 않음
    );

    await ref.putFile(localFile, metadata);
    final url = await ref.getDownloadURL();
    return (downloadUrl: url, storagePath: storagePath);
  }

  /// Storage에서 사진 삭제. 핀 삭제 동기화 시 호출.
  /// 파일이 이미 없어도 throw 안 함.
  static Future<void> deletePhoto(String storagePath) async {
    try {
      await _storage.ref().child(storagePath).delete();
    } on FirebaseException catch (e) {
      // object-not-found는 이미 지워진 경우라 무시
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// 여정 삭제 시 그 여정의 모든 사진을 한 번에 정리.
  ///
  /// listAll은 페이지네이션 없이 모두 가져오는데, 한 여정에 사진이 100장
  /// 넘어가면 비효율. 우리 MVP는 핀당 사진 1장이라 OK.
  static Future<void> deleteRoutePhotos({
    required String uid,
    required String routeUuid,
  }) async {
    final folder = _storage.ref().child('users/$uid/photos/$routeUuid');
    try {
      final list = await folder.listAll();
      await Future.wait(list.items.map((item) => item.delete()));
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// 프로필 사진 업로드.
  ///
  /// 저장 경로: `users/{uid}/profile/avatar.jpg`
  /// 같은 경로에 덮어쓰기 — 사용자가 사진 바꾸면 이전 게 자동으로 교체됨.
  /// 그래서 별도 storagePath 반환 안 하고 downloadUrl만.
  static Future<String> uploadProfilePhoto({
    required String uid,
    required File localFile,
  }) async {
    final ext = _extOf(localFile.path);
    final storagePath = 'users/$uid/profile/avatar$ext';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: _mimeFor(ext),
      // 프로필은 자주 안 바뀌어도 최대 1일 캐시 — 너무 길면 변경 반영 늦음
      cacheControl: 'public, max-age=86400',
    );

    await ref.putFile(localFile, metadata);
    return await ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────
  // 내부
  // ─────────────────────────────────────────────

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '.jpg';
    final ext = path.substring(dot).toLowerCase();
    // 알려진 확장자가 아니면 jpg로 통일 (안전 fallback)
    const known = {'.jpg', '.jpeg', '.png', '.heic', '.webp'};
    return known.contains(ext) ? ext : '.jpg';
  }

  static String _mimeFor(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.heic':
        return 'image/heic';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
