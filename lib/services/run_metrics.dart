import 'dart:math';

/// 러닝 통계 계산 유틸.
///
/// 책임:
///   - 거리 + 경과시간으로 평균 페이스 계산
///   - 거리 + 사용자 정보로 칼로리 추정
///   - 표시용 포맷팅 (분'초", km, 시간)
///
/// 페이스 (pace) = "1km를 가는 데 걸리는 시간". 러닝 표준 단위.
/// 예: 5'30" = 5분 30초 / km
class RunMetrics {
  RunMetrics._();

  // ─────────────────────────────────────────────
  // 페이스 계산
  // ─────────────────────────────────────────────

  /// 평균 페이스 (초/km).
  /// 거리 0이면 0 반환 (앱이 nan/inf 보이지 않게).
  static double averagePaceSecondsPerKm({
    required double distanceMeters,
    required Duration elapsed,
  }) {
    if (distanceMeters < 10) return 0; // 10m 미만은 의미 없음
    final km = distanceMeters / 1000.0;
    return elapsed.inSeconds / km;
  }

  /// 페이스를 "M'SS"" 형식으로.
  /// 5'30" 같은 표기. 페이스 0이면 "-'--""
  static String formatPace(double secondsPerKm) {
    if (secondsPerKm <= 0 || !secondsPerKm.isFinite) return "-'--\"";
    final minutes = secondsPerKm ~/ 60;
    final seconds = (secondsPerKm % 60).round();
    final ss = seconds.toString().padLeft(2, '0');
    return "$minutes'$ss\"";
  }

  // ─────────────────────────────────────────────
  // 속도 계산 (사이클링용 — 러닝/워킹은 페이스를 씀)
  // ─────────────────────────────────────────────

  /// 평균 속도 (km/h).
  static double averageSpeedKmh({
    required double distanceMeters,
    required Duration elapsed,
  }) {
    if (elapsed.inSeconds <= 0) return 0;
    final hours = elapsed.inSeconds / 3600.0;
    return (distanceMeters / 1000.0) / hours;
  }

  /// 속도를 "12.3" 형식으로 (단위 km/h는 화면에서 따로 붙임).
  static String formatSpeedKmh(double kmh) {
    if (kmh <= 0 || !kmh.isFinite) return '-.-';
    return kmh.toStringAsFixed(1);
  }

  // ─────────────────────────────────────────────
  // 칼로리 계산
  // ─────────────────────────────────────────────

  /// 칼로리 추정 (kcal).
  ///
  /// 공식: kg × km × MET 기반 계수
  /// 러닝 평균 9.8 MET → 1 km당 약 1 kcal/kg (시속 ~9km 기준)
  /// 학생 프로젝트라 단순화 — 정확한 칼로리는 강도 따라 다름.
  ///
  /// 기본 체중 65kg 가정. 향후 사용자 프로필에서 받아오면 더 정확.
  static int estimateCalories({
    required double distanceMeters,
    double weightKg = 65,
  }) {
    if (distanceMeters < 100) return 0;
    final km = distanceMeters / 1000.0;
    return (km * weightKg * 1.0).round();
  }

  // ─────────────────────────────────────────────
  // 거리 포맷
  // ─────────────────────────────────────────────

  /// 거리를 보기 좋게 — 1km 미만이면 m, 이상이면 km
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  /// 거리를 km 단위 큰 숫자로 (러닝 라이브 화면용).
  /// 예: 3.42
  static String formatDistanceKmBig(double meters) {
    final km = meters / 1000.0;
    return km.toStringAsFixed(2);
  }

  // ─────────────────────────────────────────────
  // 시간 포맷
  // ─────────────────────────────────────────────

  /// 경과 시간을 "M:SS" 또는 "H:MM:SS" 형식으로
  static String formatElapsed(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$minutes:$ss';
  }

  // ─────────────────────────────────────────────
  // 거리 누적 (Haversine)
  // ─────────────────────────────────────────────

  /// 두 좌표 간 거리 (미터). 지구 곡률 고려.
  /// 러닝 중 GPS 점 사이 거리 계산에 사용.
  static double haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _toRad(double deg) => deg * pi / 180.0;
}
