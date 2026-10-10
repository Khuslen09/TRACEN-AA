import 'package:flutter/material.dart';

import '../services/category_sync_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/permission_service.dart';
import 'home/home_screen.dart';
import 'permission_request_screen.dart';

/// 로그인이 끝난 사용자를 다음 화면으로 안내하는 헬퍼.
///
/// 동작:
///   1. 클라우드에서 여정 데이터 풀 다운로드 (다른 기기에서 만든 데이터 가져오기)
///   2. 큐에 쌓인 동기화 작업 flush (오프라인 중 만든 데이터 업로드)
///   3. 권한 체크 후 적절한 화면으로 라우팅
///      - 모든 권한 OK → HomeScreen
///      - 빠진 권한 있음 → PermissionRequestScreen
///
/// 한 곳에서 라우팅 결정을 내리면 Login, SignUp, Splash 세 곳의
/// 분기 로직이 일관되게 유지됨.
class AuthGate {
  AuthGate._();

  static Future<void> proceedAfterLogin(BuildContext context) async {
    // 1. 풀 다운로드 — 같은 계정으로 다른 기기에서 만든 여정 가져오기.
    //    실패해도 앱은 계속 동작해야 하므로 try-catch.
    try {
      await CloudSyncService.pullAll();
    } catch (e) {
      debugPrint('[AuthGate] pullAll failed: $e');
    }

    // 1b. 카테고리 커스터마이즈(추가 카테고리 포함) — 핀 화면이 뜨기 전에.
    await CategorySyncService.pull();

    // 2. 오프라인 중 쌓였던 큐 비우기 (fire-and-forget).
    CloudSyncService.flushQueue();

    if (!context.mounted) return;

    // 3. 권한 분기 → 화면 이동
    final allGranted = await PermissionService.areAllGranted();
    if (!context.mounted) return;

    final destination = allGranted
        ? const HomeScreen()
        : const PermissionRequestScreen();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }
}
