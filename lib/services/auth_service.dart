import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user.dart';

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
  /// 사용자가 다이얼로그를 닫으면 [AuthException('취소되었어요')]를 throw.
  static Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('취소되었어요');
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
      throw AuthException('Google 로그인에 실패했어요');
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
    if (u == null) throw AuthException('로그인이 필요해요');

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
      if (updated == null) throw AuthException('프로필을 불러올 수 없어요');
      return updated;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e));
    }
  }

  /// 회원 탈퇴.
  ///
  /// Firebase Auth 정책상 민감한 작업은 "최근 로그인" 필요.
  /// 너무 오래 전에 로그인한 사용자는 [AuthException('재로그인이 필요해요')] 발생.
  /// 화면 단에서 이 에러 잡아서 "다시 로그인해주세요" 흐름으로 안내.
  ///
  /// Firestore의 users/{uid} 문서는 함께 지우지만,
  /// users/{uid}/routes 서브컬렉션은 클라이언트에서 cascade 삭제할 수 없으므로
  /// (Firebase 정책상 그렇게 해서는 안 됨) 서버 Cloud Function이 처리.
  /// 회원 탈퇴 — Firestore + Storage 데이터 완전 삭제 후 Auth 계정 제거.
  /// 개인정보보호법상 탈퇴 시 모든 개인정보 즉시 삭제 의무.
  static Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) throw AuthException('로그인이 필요해요');

    try {
      final uid = u.uid;

      // 1. Storage 사진 모두 삭제 (routes 폴더 + standalone 폴더)
      try {
        final storage = FirebaseStorage.instance;
        final photosRef = storage.ref().child('users/$uid/photos');
        final profileRef = storage.ref().child('users/$uid/profile');
        for (final ref in [photosRef, profileRef]) {
          try {
            final list = await ref.listAll();
            // 하위 폴더(routeUuid 폴더)까지 재귀 삭제
            for (final prefix in list.prefixes) {
              final sub = await prefix.listAll();
              await Future.wait(sub.items.map((i) => i.delete()));
            }
            await Future.wait(list.items.map((i) => i.delete()));
          } catch (_) {}
        }
      } catch (_) {}

      // 2. Firestore 서브컬렉션 삭제 (routes → pins → route 문서 순)
      final routesSnap = await _usersCol.doc(uid).collection('routes').get();
      for (final routeDoc in routesSnap.docs) {
        final pinsSnap = await routeDoc.reference.collection('pins').get();
        final batch = _firestore.batch();
        for (final pinDoc in pinsSnap.docs) {
          batch.delete(pinDoc.reference);
        }
        batch.delete(routeDoc.reference);
        await batch.commit();
      }

      // 3. standalone pins 삭제
      final pinsSnap = await _usersCol.doc(uid).collection('pins').get();
      final pinsBatch = _firestore.batch();
      for (final pinDoc in pinsSnap.docs) {
        pinsBatch.delete(pinDoc.reference);
      }
      await pinsBatch.commit();

      // 4. users/{uid} 문서 삭제
      await _usersCol.doc(uid).delete();

      // 5. Auth 계정 삭제
      await u.delete();

      // 6. Google 세션 종료
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException('재로그인이 필요해요. 다시 로그인 후 탈퇴해주세요.');
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
        return '올바른 이메일 형식이 아니에요';
      case 'user-disabled':
        return '비활성화된 계정이에요';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return '이메일 또는 비밀번호가 일치하지 않아요';
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 해요';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요';
      case 'too-many-requests':
        return '너무 많은 시도가 있었어요. 잠시 후 다시 시도해주세요';
      default:
        return '인증에 실패했어요 (${e.code})';
    }
  }
}

/// 화면 단에서 catch하기 쉬운 도메인 예외.
/// FirebaseAuthException 대신 이 타입만 보면 됨.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
