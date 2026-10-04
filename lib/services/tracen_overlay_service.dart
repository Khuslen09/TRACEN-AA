import 'package:geocoding/geocoding.dart';

import '../l10n/strings.dart';
import '../models/tracen_overlay_data.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'route_db_service.dart';
import 'run_metrics.dart';

/// 촬영 사진에 찍히는 "날짜 · 도시 · 오늘 거리" 스탬프 + 오늘의 GPS 경로용
/// 데이터를 모아주는 서비스. 실패해도 절대 throw하지 않음 — 위치/네트워크가
/// 없어도 사진은 찍혀야 하므로, city가 null이거나 path가 비어 있을 수 있음.
class TracenOverlayService {
  TracenOverlayService._();

  /// 'YYYY-MM-DD' — day_tracks 조회에 쓰는 dayId 포맷.
  static String dayIdFor(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static double totalDistanceMeters(List<({double lat, double lng})> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += RunMetrics.haversineMeters(
        points[i - 1].lat,
        points[i - 1].lng,
        points[i].lat,
        points[i].lng,
      );
    }
    return total;
  }

  /// "5.2km" 형태 — 기존 RunMetrics 포매터들은 소수점 자리수/단위 표기가
  /// 이 스탬프 용도와 안 맞아서(2자리 소수 또는 단위 없음) 새로 만듦.
  static String formatStampDistance(double meters) {
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  /// "2026.10.04 · Seoul · 5.2km" — city나 거리가 없으면 그 부분은 생략.
  static String buildStampText(TracenOverlayData data) {
    String two(int n) => n.toString().padLeft(2, '0');
    final dateStr =
        '${data.date.year}.${two(data.date.month)}.${two(data.date.day)}';
    final parts = [dateStr];
    if (data.city != null && data.city!.isNotEmpty) parts.add(data.city!);
    if (data.distanceMeters > 0) {
      parts.add(formatStampDistance(data.distanceMeters));
    }
    return parts.join(' · ');
  }

  /// 앱 언어(ko/en/mn)를 geocoding 결과 언어로 매핑. 기기 언어가 아니라
  /// **앱 설정 언어**를 따라가게 하는 게 사용자 결정 사항.
  static String _localeIdentifierFor(String appLocale) => switch (appLocale) {
    'ko' => 'ko_KR',
    'mn' => 'mn_MN',
    _ => 'en_US',
  };

  static Future<TracenOverlayData> loadToday() async {
    final now = DateTime.now();
    final userId = AuthService.currentUser?.uid;

    var path = <({double lat, double lng})>[];
    try {
      path = await RouteDBService.getDayTrackRawPoints(
        dayIdFor(now),
        userId: userId,
      );
    } catch (_) {
      // 오늘 기록이 아직 없거나 DB 조회 실패 — 경로 없이 진행.
    }

    String? city;
    try {
      final pos = await LocationService.currentPosition().timeout(
        const Duration(seconds: 4),
      );
      await setLocaleIdentifier(_localeIdentifierFor(Strings.current.localeName));
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea;
      }
    } catch (_) {
      // 위치 권한 없음/타임아웃/지오코딩 실패 — city 없이 진행(절대 throw 안 함).
    }

    return TracenOverlayData(
      date: now,
      city: city,
      distanceMeters: totalDistanceMeters(path),
      path: path,
    );
  }
}
