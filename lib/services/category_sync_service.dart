import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'category_color_service.dart';

/// 카테고리 커스터마이즈(기본 6종의 이름/아이콘/색 + 사용자가 추가한
/// 카테고리)를 계정에 동기화한다 — 재설치하거나 다른 기기에서 로그인해도
/// 같은 카테고리가 보이게.
///
/// 저장 위치: `users/{uid}` 문서의 `categorySettings` 필드
/// (`CategoryColorService.exportAll` 형식). 사용자 문서 자체는 기존 보안
/// 규칙(본인만 읽기/쓰기)으로 이미 보호되고, 회원탈퇴 시 문서와 함께 지워진다.
///
/// - 올리기: [CategoryColorNotifier]가 바뀔 때마다 통째로 덮어쓰기.
/// - 받기: 로그인 직후와 자동 로그인 시([pull]). 클라우드 값이 이긴다 — 단,
///   오프라인이라 못 올린 로컬 변경이 있으면 그걸 먼저 올린다.
/// - 계정 구분: 로컬 값이 어느 계정 것인지 기억해, 다른 계정으로 로그인했을
///   때 이전 계정의 카테고리를 새 계정에 올리지 않는다.
class CategorySyncService {
  CategorySyncService._();

  static const _field = 'categorySettings';
  static const _dirtyKey = 'category_settings_dirty';
  static const _ownerKey = 'category_settings_owner';

  static bool _started = false;

  /// 클라우드 값을 로컬에 적용하는 중 — 그 변경을 다시 올리지 않게.
  static bool _applying = false;

  static DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// 앱 시작 시 한 번 — 이후 로컬 변경을 자동으로 올린다.
  static void start() {
    if (_started) return;
    _started = true;
    CategoryColorNotifier.instance.addListener(_onLocalChange);
  }

  static void _onLocalChange() {
    if (_applying) return;
    unawaited(push());
  }

  /// 로컬 값을 클라우드에 덮어쓴다. 실패(오프라인 등)하면 다음 [pull] 때
  /// 다시 올리도록 표시만 해둔다.
  static Future<void> push() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      await prefs.setBool(_dirtyKey, true);
      return;
    }
    try {
      final data = await CategoryColorService.exportAll();
      await _doc(uid).set({
        _field: {...data, 'updatedAt': FieldValue.serverTimestamp()},
      }, SetOptions(mergeFields: [_field]));
      await prefs.setBool(_dirtyKey, false);
      await prefs.setString(_ownerKey, uid);
    } catch (e) {
      debugPrint('[CategorySync] 업로드 실패: $e');
      await prefs.setBool(_dirtyKey, true);
    }
  }

  /// 클라우드 값을 받아 로컬에 적용한다.
  static Future<void> pull() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_ownerKey);
    final otherAccount = owner != null && owner != uid;

    try {
      // 같은 계정에서 오프라인 중 바꾼 게 있으면 그게 최신.
      if (!otherAccount && (prefs.getBool(_dirtyKey) ?? false)) {
        await push();
        return;
      }

      final snap = await _doc(uid).get();
      final remote = snap.data()?[_field];
      if (remote is Map<String, dynamic>) {
        await _apply(remote);
      } else if (otherAccount) {
        // 새 계정이고 클라우드에 아무것도 없음 — 이전 계정 값을 지우고 기본값.
        await _apply(const {'customKeys': <String>[], 'items': {}});
      } else {
        // 이 기능 이전에 바꿔둔 값(소유 계정 미기록)은 이 계정 것으로 올림.
        await push();
        return;
      }
      await prefs.setString(_ownerKey, uid);
      await prefs.setBool(_dirtyKey, false);
    } catch (e) {
      debugPrint('[CategorySync] 받기 실패: $e');
    }
  }

  static Future<void> _apply(Map<String, dynamic> data) async {
    _applying = true;
    try {
      await CategoryColorService.importAll(data);
      await CategoryColorNotifier.instance.init();
    } finally {
      _applying = false;
    }
  }
}
