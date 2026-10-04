import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/script_detector.dart';

/// 공유 카드 전용 폰트 스타일 — 한 곳에 모아서 `share_card/` 바깥(앱 전역
/// 테마)에는 영향 없게 한다. 지명/로고는 Unbounded, 날짜/좌표는 JetBrains
/// Mono, 나머지 UI 텍스트는 IBM Plex Sans KR.
class ShareCardFonts {
  ShareCardFonts._();

  static TextStyle unbounded({
    required double size,
    FontWeight weight = FontWeight.w700,
    required Color color,
    double letterSpacing = 0,
  }) => GoogleFonts.unbounded(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// 위치명 전용 — 한글이 섞여 있으면 Unbounded엔 한글 글립이 없어서 IBM
  /// Plex Sans KR로, 아니면 Unbounded로(브랜드 느낌 유지).
  static TextStyle placeName({
    required String text,
    required double size,
    FontWeight weight = FontWeight.w700,
    required Color color,
    double letterSpacing = 0,
  }) => containsHangul(text)
      ? GoogleFonts.ibmPlexSansKr(
          fontSize: size,
          fontWeight: weight,
          color: color,
          letterSpacing: letterSpacing,
        )
      : unbounded(size: size, weight: weight, color: color, letterSpacing: letterSpacing);

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w500,
    required Color color,
    double letterSpacing = 0,
    double opacity = 1.0,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color.withValues(alpha: opacity),
    letterSpacing: letterSpacing,
  );

  static TextStyle ui({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = Colors.white,
  }) => GoogleFonts.ibmPlexSansKr(fontSize: size, fontWeight: weight, color: color);
}
