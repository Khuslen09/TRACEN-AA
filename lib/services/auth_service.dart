import '../l10n/strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';
import 'route_db_service.dart';
import 'sync_queue_service.dart';

/// AA 인증 서비스.
///
/// 책임:
///   - Firebase Auth 가입/로그인/로그아웃
///   - Google Sign-In OAuth 흐름
///   - Firestore users/{uid} 문서를 Auth와 동기화 (가입 시 자동 생성)
///   - 로그인 상태 변화 스트림 노출
///
/// 화면(LoginScreen, SignUpScreen, SplashScreen)에서는 이 서비스만
/// 호출하고, FirebaseAuth/GoogleSignIn 직접 의존하지 않음. (단일 진입점)
class AuthService {
  AuthService._();

  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _googleSignIn = GoogleSignIn();

  static CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  // ─────────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────────

  /// 현재 로그인된 Firebase User (없으면 null)
  static User? get currentUser => _auth.currentUser;

  /// 로그인 여부
  static bool get isLoggedIn => _auth.currentUser != null;

  /// 로그인 상태 변화 스트림 — Splash나 root widget에서 listen.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────
  // 이메일/비밀번호
  // ─────────────────────────────────────────────

  /// 이메일/비밀번호로 신규 가입.
  ///
  /// 성공 시 Firestore users 컬렉션에도 문서 생성.
  /// 실패 시 [FirebaseAuthException]을 한국어 메시지로 변환해 throw.
  static Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;

      // Auth displayName도 같이 설정 (Google과 일관성)
      await user.updateDisplayName(name);

      // Firestore에 사용자 문서 생성
      final appUser = AppUser(
        uid: user.uid,
        email: user.email ?? email.trim(),
        name: name,
        photoUrl: null,
      );
      await _usersCol.doc(user.uid).set(appUser.toFirestore());

      return appUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  /// 이메일/비밀번호로 로그인.
  static Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      return await _getOrCreateUserDoc(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  /// 비밀번호 재설정 메일 발송.
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  // ─────────────────────────────────────────────
  // Google Sign-In
  // ─────────────────────────────────────────────

  /// Google 계정으로 로그인.
  ///
  /// 흐름:
  ///   1. GoogleSignIn UI로 계정 선택
  ///   2. ID 토큰/Access 토큰 받기
  ///   3. Firebase Credential로 변환해 signInWithCredential
  ///   4. Firestore users 문서 생성 또는 업데이트
  ///
  /// 사용자가 다이얼로그를 닫으면 `cancelled: true`인 [AuthException]을 throw.
  static Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException(Strings.current.authCancelled, cancelled: true);
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      return await _getOrCreateUserDoc(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(Strings.current.googleLoginFailed);
    }
  }

  // ─────────────────────────────────────────────
  // 로그아웃
  // ─────────────────────────────────────────────

  static Future<void> signOut() async {
    // Google 세션도 함께 종료 (다음 로그인 때 계정 선택 다이얼로그 다시 뜨도록)
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google 세션이 없을 수 있으니 실패는 무시
    }
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────
  // Firestore users 컬렉션 헬퍼
  // ─────────────────────────────────────────────

  /// Firestore users/{uid} 문서를 가져오거나, 없으면 Auth 정보로 생성.
  ///
  /// Google 로그인이나 기존 이메일 사용자가 처음으로 Firestore 문서를
  /// 갖게 되는 경로를 모두 커버. (멱등)
  static Future<AppUser> _getOrCreateUserDoc(User user) async {
    final docRef = _usersCol.doc(user.uid);
    final snap = await docRef.get();

    if (snap.exists) {
      return AppUser.fromFirestore(snap);
    }

    final newUser = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      name: user.displayName,
      photoUrl: user.photoURL,
    );
    await docRef.set(newUser.toFirestore());
    return newUser;
  }

  /// 현재 로그인된 사용자의 Firestore 프로필 가져오기.
  /// 화면에서 "내 프로필" 표시할 때 사용.
  static Future<AppUser?> fetchCurrentUserProfile() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final snap = await _usersCol.doc(u.uid).get();
    if (!snap.exists) return null;
    return AppUser.fromFirestore(snap);
  }

  /// 프로필 정보 수정 (닉네임 / 사진 URL).
  ///
  /// Firebase Auth의 displayName/photoURL과 Firestore 문서를 함께 업데이트.
  /// 둘 다 nullable — null이면 해당 필드 그대로 둠.
  static Future<AppUser> updateProfile({String? name, String? photoUrl}) async {
    final u = _auth.currentUser;
    if (u == null) throw AuthException(Strings.current.authLoginRequired);

    try {
      // Auth 측 갱신
      if (name != null) await u.updateDisplayName(name);
      if (photoUrl != null) await u.updatePhotoURL(photoUrl);

      // Firestore 측 갱신 (변경된 필드만)
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (updates.isNotEmpty) {
        await _usersCol.doc(u.uid).update(updates);
      }

      // 갱신된 프로필 반환
      final updated = await fetchCurrentUserProfile();
      if (updated == null) throw AuthException(Strings.current.profileLoadFailed);
      return updated;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  /// 재인증 유효 기간 — 이보다 오래 전에 로그인했으면 탈퇴 전에 선제 재인증.
  static const _reauthWindow = Duration(minutes: 5);

  /// 탈퇴처럼 민감한 작업 전, 로그인이 오래됐으면 선제적으로 재인증.
  ///
  /// 데이터 삭제를 시작하기 "전"에 끝내야 한다 — 재인증 실패를 삭제 후에
  /// 알게 되면 데이터는 이미 사라졌는데 Auth 계정만 남는 상황이 생긴다.
  /// 이메일 사용자는 비밀번호 없이는 재인증할 수 없으므로, 호출 측이
  /// [password]를 받아 `deleteAccount(password: ...)`로 재시도해야 한다.
  static Future<void> _ensureRecentLogin(User u, {String? password}) async {
    final lastSignIn = u.metadata.lastSignInTime;
    final isRecent = lastSignIn != null &&
        DateTime.now().difference(lastSignIn) < _reauthWindow;
    if (isRecent) return;

    final providerId =
        u.providerData.isNotEmpty ? u.providerData.first.providerId : null;

    if (providerId == 'google.com') {
      final googleUser =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException(Strings.current.authReauthRequired);
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await u.reauthenticateWithCredential(credential);
    } else if (providerId == 'password') {
      if (password == null || password.isEmpty) {
        throw AuthException(Strings.current.authReauthRequired);
      }
      final credential = EmailAuthProvider.credential(
        email: u.email ?? '',
        password: password,
      );
      await u.reauthenticateWithCredential(credential);
    }
  }

  /// Storage 폴더를 깊이 제한 없이 재귀적으로 완전히 삭제.
  static Future<void> _deleteStorageFolderRecursive(Reference ref) async {
    final list = await ref.listAll();
    await Future.wait(list.items.map((i) => i.delete()));
    await Future.wait(list.prefixes.map(_deleteStorageFolderRecursive));
  }

  /// Firestore 문서 목록을 400개씩 나눠 배치 삭제 (한도 500 writes/commit).
  static Future<void> _deleteRefsInChunks(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    const chunkSize = 400;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final end = (i + chunkSize < refs.length) ? i + chunkSize : refs.length;
      final batch = _firestore.batch();
      for (final ref in refs.sublist(i, end)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// 회원 탈퇴.
  ///
  /// Firebase Auth 정책상 민감한 작업은 "최근 로그인" 필요.
  /// 너무 오래 전에 로그인한 사용자는 [AuthException('재로그인이 필요해요')] 발생.
  /// 화면 단에서 이 에러 잡아서 "다시 로그인해주세요" 흐름으로 안내.
  /// (이메일 사용자는 비밀번호를 받아 [password]로 재시도해야 함.)
  ///
  /// Firestore의 users/{uid} 문서는 함께 지우지만,
  /// users/{uid}/routes 서브컬렉션은 클라이언트에서 cascade 삭제할 수 없으므로
  /// (Firebase 정책상 그렇게 해서는 안 됨) 서버 Cloud Function이 처리.
  /// 회원 탈퇴 — Firestore + Storage 데이터 완전 삭제 후 Auth 계정 제거.
  /// 개인정보보호법상 탈퇴 시 모든 개인정보 즉시 삭제 의무.
  static Future<void> deleteAccount({String? password}) async {
    final u = _auth.currentUser;
    if (u == null) throw AuthException(Strings.current.authLoginRequired);

    try {
      // 0. 재인증 선행 — 데이터 삭제 전에 끝내야 삭제-후-실패를 피할 수 있다.
      await _ensureRecentLogin(u, password: password);

      final uid = u.uid;

      // 1. Storage 사진 모두 삭제 (routes 폴더 + standalone 폴더, 깊이 제한 없이 재귀)
      final storage = FirebaseStorage.instance;
      final photosRef = storage.ref().child('users/$uid/photos');
      final profileRef = storage.ref().child('users/$uid/profile');
      for (final ref in [photosRef, profileRef]) {
        try {
          await _deleteStorageFolderRecursive(ref);
        } catch (_) {}
      }

      // 2. routes → pins → route 문서 삭제 (청크 단위 배치)
      final routesSnap = await _usersCol.doc(uid).collection('routes').get();
      final routeRefs = <DocumentReference<Map<String, dynamic>>>[];
      for (final routeDoc in routesSnap.docs) {
        final pinsSnap = await routeDoc.reference.collection('pins').get();
        routeRefs.addAll(pinsSnap.docs.map((d) => d.reference));
        routeRefs.add(routeDoc.reference);
      }
      await _deleteRefsInChunks(routeRefs);

      // 3. standalone pins 삭제
      final pinsSnap = await _usersCol.doc(uid).collection('pins').get();
      await _deleteRefsInChunks(pinsSnap.docs.map((d) => d.reference).toList());

      // 3b. dayTracks 삭제 — 기존엔 빠져 있던 부분
      final dayTracksSnap =
          await _usersCol.doc(uid).collection('dayTracks').get();
      await _deleteRefsInChunks(
        dayTracksSnap.docs.map((d) => d.reference).toList(),
      );

      // 4. users/{uid} 문서 삭제
      await _usersCol.doc(uid).delete();

      // 5. Auth 계정 삭제
      await u.delete();

      // 6. Google 세션 종료
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 7. 로컬 SQLite/큐 정리 — Auth 계정은 이미 삭제됐으니 실패해도 계속 진행.
      try {
        await RouteDBService.clearAll();
        await SyncQueueService.clearAll();
      } catch (e) {
        if (kDebugMode) debugPrint('[AuthService] 로컬 데이터 정리 실패: $e');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException(Strings.current.authReauthRequired);
      }
      throw AuthException(_mapAuthError(e));
    }
  }

  // ─────────────────────────────────────────────
  // 에러 메시지 변환
  // ─────────────────────────────────────────────

  static String _mapAuthError(FirebaseAuthException e) {
    if (kDebugMode) debugPrint('[AuthService] ${e.code}: ${e.message}');
    switch (e.code) {
      case 'invalid-email':
        return Strings.current.emailInvalid;
      case 'user-disabled':
        return Strings.current.authErrorDisabled;
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return Strings.current.authErrorWrongCredentials;
      case 'email-already-in-use':
        return Strings.current.authErrorEmailInUse;
      case 'weak-password':
        return Strings.current.passwordTooShort;
      case 'network-request-failed':
        return Strings.current.authErrorNetwork;
      case 'too-many-requests':
        return Strings.current.authErrorTooMany;
      default:
        return Strings.current.authErrorGeneric(e.code);
    }
  }
}

/// 화면 단에서 catch하기 쉬운 도메인 예외.
/// FirebaseAuthException 대신 이 타입만 보면 됨.
class AuthException implements Exception {
  final String message;

  /// 사용자가 로그인 창을 닫은 경우 — 에러 메시지를 띄우지 않는다.
  /// (번역된 문구가 아니라 이 플래그로 구분해야 언어가 바뀌어도 안 깨진다.)
  final bool cancelled;
  AuthException(this.message, {this.cancelled = false});

  @override
  String toString() => message;
}
