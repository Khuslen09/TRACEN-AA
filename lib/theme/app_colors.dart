import 'package:flutter/material.dart';

/// AA 컬러 팔레트.
///
/// 디자인 원칙:
///   - 메인 보라(#6B4EFF)는 기존 #7C4DFF보다 살짝 차분하게 — 장시간 사용해도 피로 적음
///   - 그레이 스케일은 9단계로 세분화 — UI 요소별 미묘한 명도 차이로 위계 표현
///   - 배경은 순백(#FFF) 대신 살짝 따뜻한 #FAFAFB — 눈 부담 감소
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF6B4EFF);
  static const primaryDark = Color(0xFF5538E5);
  static const primaryLight = Color(0xFFE8E3FF); // 밝은 보라 배경, 칩, 호버

  // Semantic
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Neutrals (Tailwind-style 9-step scale)
  static const gray50 = Color(0xFFFAFAFB);
  static const gray100 = Color(0xFFF4F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);

  // Light surface aliases
  static const background = gray50;
  static const surface = Colors.white;
  static const border = gray200;
  static const textPrimary = gray900;
  static const textSecondary = gray500;
  static const textTertiary = gray400;

  // Dark surface aliases
  static const darkBackground = Color(0xFF0F1117);
  static const darkSurface = Color(0xFF1A1D27);
  static const darkCard = Color(0xFF222638);
  static const darkBorder = Color(0xFF2D3148);
  static const darkTextPrimary = Color(0xFFF1F2F6);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkTextTertiary = Color(0xFF6B7280);

  // ─────────────────────────────────────────────
  // 발자취 (지나간 길) 시각화 색상
  // ─────────────────────────────────────────────
  // 보라 톤이 깔린 지도 위에 베이지 라인을 그려 "벗겨낸 흔적" 효과.
  // 진짜 마스킹은 Google Maps에서 불가하지만, 색 대비로 비슷한 임팩트.
  //
  // 색상 후보 (취향따라 home_screen.dart에서 교체 가능):
  //   - 따뜻한 분홍: 0xFFE8C5B5
  //   - 크림 베이지: 0xFFF5E8D8  ← 현재 선택
  //   - 옅은 흰베이지: 0xFFF8F0E5
  static const trackPath = Color(0xFFF5E8D8);
}

/// 부드러운 그림자 프리셋.
///
/// Material 기본 elevation은 너무 진해서 "AI가 만든 앱" 느낌이 남.
/// 트렌디한 앱들은 blur가 크고 alpha가 낮은 그림자를 씀.
class AppShadows {
  AppShadows._();

  /// 카드, 입력 필드 등 기본 떠 있음
  static const sm = [
    BoxShadow(
      color: Color(0x0A000000), // black 4%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// 떠 있는 버튼, 모달 헤더
  static const md = [
    BoxShadow(
      color: Color(0x0F000000), // black 6%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// 바텀시트, 다이얼로그
  static const lg = [
    BoxShadow(
      color: Color(0x14000000), // black 8%
      blurRadius: 32,
      offset: Offset(0, 8),
    ),
  ];

  /// 보라 버튼 강조 — primary 색을 살짝 흘리는 효과
  static List<BoxShadow> primary = const [
    BoxShadow(
      color: Color(0x336B4EFF), // primary 20%
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}

/// 표준 모서리 반경.
///
/// 트렌드: 더 둥글게. Material 기본 4px → 12~24px.
class AppRadius {
  AppRadius._();

  static const sm = 8.0; // 칩, 작은 버튼
  static const md = 12.0; // 입력 필드
  static const lg = 16.0; // 카드, 큰 버튼
  static const xl = 20.0; // 모달, 시트
  static const xxl = 28.0; // 매우 큰 카드, 영웅 컴포넌트
  static const full = 999.0; // 알약(pill) 형태
}

/// 표준 간격.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}
