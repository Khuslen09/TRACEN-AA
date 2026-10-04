/// TRACEN 시그니처 카메라 필터 4종.
///
/// 순수 Dart — `tools/generate_luts.dart`가 그대로 import. 이름 자체
/// (Golden Route 등)는 브랜드명으로 취급해 모든 언어에서 영어로 고정
/// (ko/en/mn ARB에 동일한 영어 문자열로 저장됨 — `lib/models/camera_filter_l10n.dart`
/// 참고).
library;

import 'filter_recipe.dart';

enum TracenFilter {
  goldenRoute('golden_route'),
  nightTrace('night_trace'),
  fadedMap('faded_map'),
  monoPath('mono_path');

  final String id;
  const TracenFilter(this.id);

  String get lutAsset => 'assets/luts/$id.png';

  static const defaultStrength = 0.65;
  static const defaultFilter = TracenFilter.goldenRoute;

  FilterRecipe get recipe => switch (this) {
    TracenFilter.goldenRoute => _goldenRoute,
    TracenFilter.nightTrace => _nightTrace,
    TracenFilter.fadedMap => _fadedMap,
    TracenFilter.monoPath => _monoPath,
  };
}

/// 기본 필터 — 색온도를 따뜻하게, 완만한 S커브, 블랙 포인트를 살짝 올려
/// 매트하게, 하이라이트는 앰버·섀도는 약한 틸로 스플릿톤, 초록은 채도를
/// 낮추며 노란 쪽으로, 파랑도 채도를 살짝 낮춤.
final _goldenRoute = FilterRecipe(
  temperatureShiftK: 250,
  curve: ToneCurve.gentleS(),
  blackLift: 0.035,
  hsl: const {
    HslBand.green: HslBandAdjust(hueShiftDeg: -10, satDelta: -0.20),
    HslBand.blue: HslBandAdjust(satDelta: -0.10),
  },
  splitHighlightHueDeg: 40,
  splitHighlightSat: 0.10,
  splitShadowHueDeg: 185,
  splitShadowSat: 0.06,
  skinProtect: 0.9,
  grain: 0.12,
  vignette: 0.10,
);

/// 야간용 — 섀도 노이즈를 억제하고(셰이더에서 처리) 네온 색이 살아나게
/// vibrance를 올리고, 약간 차가운 톤.
final _nightTrace = FilterRecipe(
  temperatureShiftK: -300,
  curve: ToneCurve.gentleS(shadowY: 0.16),
  blackLift: 0.015,
  vibrance: 0.25,
  splitShadowHueDeg: 210,
  splitShadowSat: 0.08,
  skinProtect: 0.85,
  grain: 0.06,
  vignette: 0.15,
  shadowDenoise: 0.6,
);

/// 매트하고 바랜 필름 느낌 — 전체 채도를 낮추고, 블랙/화이트 포인트를
/// 둘 다 안쪽으로 당겨 콘트라스트를 낮춘다.
final _fadedMap = FilterRecipe(
  temperatureShiftK: 80,
  curve: ToneCurve.gentleS(shadowY: 0.27, highlightY: 0.72),
  blackLift: 0.09,
  whiteDrop: 0.06,
  globalSaturation: -0.35,
  splitHighlightHueDeg: 35,
  splitHighlightSat: 0.05,
  splitShadowHueDeg: 170,
  splitShadowSat: 0.05,
  skinProtect: 0.85,
  grain: 0.18,
  vignette: 0.08,
);

/// 부드러운 대비의 흑백 — 블랙을 살짝 들어 올려 매트한 흑백.
final _monoPath = FilterRecipe(
  curve: ToneCurve.gentleS(shadowY: 0.23, highlightY: 0.77),
  blackLift: 0.05,
  whiteDrop: 0.02,
  monochrome: true,
  grain: 0.15,
  vignette: 0.12,
);
