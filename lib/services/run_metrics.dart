import 'dart:math';

import '../models/route_pause.dart';
import '../models/route_point.dart';

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

  // ─────────────────────────────────────────────
  // 결과 화면용 — 이동 시간 / 고도 상승 / 구간 기록
  // ─────────────────────────────────────────────

  /// [startedAt]~[at] 사이에서 일시정지 구간을 뺀 실제 이동 시간.
  /// [ActivityRecorder]의 타임스탬프 기반 계산과 같은 규칙.
  static Duration movingDurationAt({
    required DateTime startedAt,
    required DateTime at,
    required List<RoutePause> pauses,
  }) {
    var paused = Duration.zero;
    for (final p in pauses) {
      final pStart = p.startedAt.isBefore(startedAt) ? startedAt : p.startedAt;
      final pEnd = p.endedAt ?? at;
      final end = pEnd.isAfter(at) ? at : pEnd;
      if (end.isAfter(pStart)) paused += end.difference(pStart);
    }
    final total = at.difference(startedAt) - paused;
    return total.isNegative ? Duration.zero : total;
  }

  /// GPS 고도 상승(m). GPS 고도는 오차가 커서 그대로 더하면 평지도 크게
  /// 부풀려진다 → ① 수직 정확도가 나쁜 점(>15m) 제외 ② 5점 이동평균으로
  /// 스무딩 ③ 마지막 기준점보다 3m 이상 오를 때만 누적(히스테리시스).
  /// altitudeAccuracy가 0이면(기기가 값을 안 줌) 그 점은 그대로 사용.
  static double elevationGain(List<RoutePoint> points) {
    final alts = <double>[
      for (final p in points)
        if (p.altitudeAccuracy <= 15 && p.altitude != 0) p.altitude,
    ];
    if (alts.length < 5) return 0;

    const window = 5;
    final smoothed = <double>[];
    for (var i = 0; i < alts.length; i++) {
      final from = max(0, i - window ~/ 2);
      final to = min(alts.length, i + window ~/ 2 + 1);
      var sum = 0.0;
      for (var j = from; j < to; j++) {
        sum += alts[j];
      }
      smoothed.add(sum / (to - from));
    }

    const hysteresis = 3.0;
    var gain = 0.0;
    var ref = smoothed.first;
    for (final a in smoothed.skip(1)) {
      if (a - ref >= hysteresis) {
        gain += a - ref;
        ref = a;
      } else if (a < ref) {
        ref = a; // 내려가면 기준점을 낮춰 다음 오르막을 새로 잰다
      }
    }
    return gain;
  }

  /// [splitMeters](러닝/걷기 1km, 자전거 5km)마다 구간 기록.
  ///
  /// 경계를 넘는 두 점 사이를 선형 보간해 정확한 경계 시각을 구하고,
  /// 구간 시간은 일시정지를 뺀 이동 시간 기준. 마지막 남은 거리가
  /// 50m 이상이면 [Split.isPartial] 구간으로 덧붙인다.
  static List<Split> computeSplits({
    required List<RoutePoint> points,
    required List<RoutePause> pauses,
    required DateTime startedAt,
    double splitMeters = 1000,
  }) {
    if (points.length < 2) return const [];

    Duration movingAt(DateTime t) =>
        movingDurationAt(startedAt: startedAt, at: t, pauses: pauses);

    final splits = <Split>[];
    var cumulative = 0.0;
    var nextBoundary = splitMeters;
    var lastBoundaryMoving = movingAt(points.first.time);

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final seg = haversineMeters(a.lat, a.lng, b.lat, b.lng);
      if (seg <= 0) continue;
      while (cumulative + seg >= nextBoundary) {
        final ratio = (nextBoundary - cumulative) / seg;
        final ms = b.time.difference(a.time).inMilliseconds * ratio;
        final crossAt = a.time.add(Duration(milliseconds: ms.round()));
        final moving = movingAt(crossAt);
        splits.add(
          Split(
            index: splits.length + 1,
            distanceMeters: splitMeters,
            duration: moving - lastBoundaryMoving,
          ),
        );
        lastBoundaryMoving = moving;
        nextBoundary += splitMeters;
      }
      cumulative += seg;
    }

    final remaining = cumulative - (nextBoundary - splitMeters);
    if (remaining >= 50) {
      splits.add(
        Split(
          index: splits.length + 1,
          distanceMeters: remaining,
          duration: movingAt(points.last.time) - lastBoundaryMoving,
          isPartial: true,
        ),
      );
    }
    return splits;
  }
}

/// 한 구간(1km 또는 5km) 기록.
class Split {
  final int index;
  final double distanceMeters;
  final Duration duration;

  /// 마지막 자투리 구간(정해진 거리보다 짧음).
  final bool isPartial;

  const Split({
    required this.index,
    required this.distanceMeters,
    required this.duration,
    this.isPartial = false,
  });

  /// 초/km — 자투리 구간도 km 환산이라 다른 구간과 비교 가능.
  double get paceSecondsPerKm => distanceMeters <= 0
      ? 0
      : duration.inMilliseconds / 1000 / (distanceMeters / 1000);

  double get speedKmh => duration.inMilliseconds <= 0
      ? 0
      : (distanceMeters / 1000) / (duration.inMilliseconds / 3600000);
}
