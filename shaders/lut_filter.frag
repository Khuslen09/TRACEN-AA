#version 460 core

#include <flutter/runtime_effect.glsl>

// float 유니폼 — 선언 순서가 Dart 쪽 setFloat(index, ...) 의 인덱스와 같다.
// vec2/vec4는 여러 슬롯을 차지하므로, Dart 쪽에서 반드시 이 순서를 지켜서
// setFloat을 호출해야 함 (lib/services/lut_shader_service.dart 참고).
uniform vec2 uOutSize;        // 0,1  — 그려지는 사각형의 크기(논리 픽셀)
uniform vec4 uSrcRect;        // 2..5 — 원본 이미지 안에서의 크롭 영역(정규화 UV: x,y,w,h)
uniform vec2 uSrcTexel;       // 6,7  — 1/원본가로, 1/원본세로 (디노이즈 탭 간격)
uniform float uStrength;      // 8    — 0..1, 원본과 필터 결과를 lerp
uniform float uGrain;         // 9    — 0..1
uniform float uGrainScale;    // 10   — 그레인 입자 밀도(긴 변 기준 입자 개수)
uniform float uVignette;      // 11   — 0..1
uniform float uShadowDenoise; // 12   — 0..1, 그림자 영역 크로마 디노이즈 강도
uniform float uLutSize;       // 13   — LUT 한 축 레벨 수(64)
uniform float uLutTiles;      // 14   — LUT 타일 한 변 개수(8)

uniform sampler2D uSource; // sampler 0 — 원본 사진
uniform sampler2D uLut;    // sampler 1 — 512x512 LUT(FilterQuality.low로 bilinear)

out vec4 fragColor;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// red/green은 LUT 텍스처의 하드웨어 bilinear 샘플링에 맡기고, blue(타일
// 선택)만 두 타일 사이를 직접 lerp — tools/generate_luts.dart,
// lib/utils/lut_math.dart와 정확히 같은 레이아웃/수학이어야 함.
vec3 sampleLut(vec3 c) {
  float n = uLutSize;
  float tiles = uLutTiles;

  float bz = c.b * (n - 1.0);
  float b0 = floor(bz);
  float b1 = min(b0 + 1.0, n - 1.0);
  float bf = bz - b0;

  // 텍셀 중심에 정확히 맞춰서(+0.5) 인접 타일로 새지 않게 함.
  vec2 rg = c.rg * (n - 1.0) + 0.5;

  vec2 tile0 = vec2(mod(b0, tiles), floor(b0 / tiles));
  vec2 tile1 = vec2(mod(b1, tiles), floor(b1 / tiles));

  vec2 uv0 = (tile0 * n + rg) / (n * tiles);
  vec2 uv1 = (tile1 * n + rg) / (n * tiles);

  vec3 lut0 = texture(uLut, uv0).rgb;
  vec3 lut1 = texture(uLut, uv1).rgb;
  return mix(lut0, lut1, bf);
}

vec3 applyShadowDenoise(vec3 c, vec2 uv) {
  if (uShadowDenoise <= 0.0) return c;

  vec3 avg = c;
  avg += texture(uSource, uv + vec2(uSrcTexel.x, 0.0) * 1.5).rgb;
  avg += texture(uSource, uv - vec2(uSrcTexel.x, 0.0) * 1.5).rgb;
  avg += texture(uSource, uv + vec2(0.0, uSrcTexel.y) * 1.5).rgb;
  avg += texture(uSource, uv - vec2(0.0, uSrcTexel.y) * 1.5).rgb;
  avg /= 5.0;

  float y = luma709(c);
  // Y(루마)는 원본 그대로 유지하고, 어두운 영역의 크로마(색차)만 주변
  // 평균 쪽으로 섞어서 디테일은 보존하면서 색 노이즈만 줄임.
  float shadowAmt = (1.0 - smoothstep(0.08, 0.30, y)) * uShadowDenoise;
  vec3 denoised = c + (avg - c) * shadowAmt;
  // 루마는 denoise 전 값으로 복원(간단 근사 — Cb/Cr 분리 없이 밝기 보존).
  float denoisedY = luma709(denoised);
  if (denoisedY > 0.0001) {
    denoised *= y / denoisedY;
  }
  return denoised;
}

void main() {
  vec2 fragUv = FlutterFragCoord().xy / uOutSize;
  vec2 srcUv = uSrcRect.xy + fragUv * uSrcRect.zw;

  vec3 original = texture(uSource, srcUv).rgb;
  vec3 c = applyShadowDenoise(original, srcUv);
  c = sampleLut(c);

  if (uGrain > 0.0) {
    vec2 grainUv = floor(fragUv * uGrainScale);
    float n = hash12(grainUv) - 0.5;
    float y = luma709(c);
    float midtoneWeight = 4.0 * y * (1.0 - y); // 미드톤에서 가장 두드러짐
    c += n * uGrain * 0.06 * midtoneWeight;
  }

  if (uVignette > 0.0) {
    vec2 aspectFix = vec2(uOutSize.x / uOutSize.y, 1.0);
    if (uOutSize.x < uOutSize.y) {
      aspectFix = vec2(1.0, uOutSize.y / uOutSize.x);
    }
    float d = length((fragUv - 0.5) * aspectFix);
    c *= 1.0 - uVignette * smoothstep(0.45, 1.0, d);
  }

  c = clamp(c, 0.0, 1.0);
  fragColor = vec4(mix(original, c, uStrength), 1.0);
}
