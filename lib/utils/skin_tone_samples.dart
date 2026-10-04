/// Monk Skin Tone 10단계 스케일의 공개된 근사 sRGB 값(hex).
/// https://skintone.google 참고.
///
/// [FilterRecipe]의 피부 보호가 실제로 다양한 피부톤에서 동작하는지
/// 검증(`filter_recipe_test.dart`)하고, 실시간 미리보기용 ColorMatrix를
/// 피부톤에서 가장 정확하게 피팅(`color_matrix_fit.dart`)하는 데 쓰는
/// 공통 샘플.
library;

const monkSkinToneHex = <int>[
  0xf6ede4,
  0xf3e7db,
  0xf7ead0,
  0xeadaba,
  0xd7bd96,
  0xa07e56,
  0x825c43,
  0x604134,
  0x3a312a,
  0x292420,
];

(double r, double g, double b) rgbFromHex(int hex) {
  final r = ((hex >> 16) & 0xFF) / 255.0;
  final g = ((hex >> 8) & 0xFF) / 255.0;
  final b = (hex & 0xFF) / 255.0;
  return (r, g, b);
}
