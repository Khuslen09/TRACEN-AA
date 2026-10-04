import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/camera_filter.dart';
import '../utils/lut_math.dart';

/// `shaders/lut_filter.frag`를 로드/캐시하고, 매 프레임 호출할 때마다
/// uniform을 채워 [ui.FragmentShader]를 만들어주는 서비스.
///
/// [FragmentProgram]과 LUT [ui.Image]는 한 번만 로드해 캐시하지만,
/// [ui.FragmentShader] 자체는 매 호출마다 새로 만든다(유니폼 값이 매번
/// 다르므로) — 호출 쪽이 다 쓰고 나면 **반드시 `shader.dispose()`** 해야
/// 네이티브 리소스가 안 샌다.
class LutShaderService {
  LutShaderService._();

  static Future<ui.FragmentProgram>? _programFuture;
  static final Map<String, Future<ui.Image>> _lutImages = {};

  static Future<ui.FragmentProgram> _loadProgram() {
    return _programFuture ??= ui.FragmentProgram.fromAsset(
      'shaders/lut_filter.frag',
    );
  }

  static Future<ui.Image> _loadLut(TracenFilter filter) {
    return _lutImages.putIfAbsent(filter.lutAsset, () async {
      final data = await rootBundle.load(filter.lutAsset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    });
  }

  /// 앱 시작 시(또는 촬영 화면 진입 시) 미리 호출해두면 첫 사용 때 디코드
  /// 지연이 없음 — 필수는 아니고 선택적 워밍업.
  static Future<void> warmUp() async {
    await _loadProgram();
    await Future.wait(TracenFilter.values.map(_loadLut));
  }

  /// [filter]를 [source] 이미지에 적용하는 셰이더를 구성해서 반환.
  ///
  /// - [outSize]: 이 셰이더로 그릴 사각형의 크기(논리 픽셀) — 미리보기면
  ///   화면에 보이는 크기, 내보내기면 최종 출력 해상도.
  /// - [srcRectUv]: [source] 안에서 크롭할 영역(정규화 UV, 0..1). 보통
  ///   비율(4:5/1:1/9:16)에 맞춘 중앙 크롭 사각형.
  /// - [strength]: 0..1, 원본과 필터 결과를 섞는 비율.
  static Future<ui.FragmentShader> configure({
    required TracenFilter filter,
    required ui.Image source,
    required ui.Size outSize,
    required ui.Rect srcRectUv,
    required double strength,
  }) async {
    final program = await _loadProgram();
    final lut = await _loadLut(filter);
    final recipe = filter.recipe;
    final shader = program.fragmentShader();

    shader.getUniformVec2('uOutSize').set(outSize.width, outSize.height);
    shader
        .getUniformVec4('uSrcRect')
        .set(srcRectUv.left, srcRectUv.top, srcRectUv.width, srcRectUv.height);
    shader
        .getUniformVec2('uSrcTexel')
        .set(1.0 / source.width, 1.0 / source.height);
    shader.getUniformFloat('uStrength').set(strength.clamp(0.0, 1.0));
    shader.getUniformFloat('uGrain').set(recipe.grain);
    // 그레인 입자가 출력 해상도와 무관하게 같은 물리적 크기로 보이게 —
    // 출력 긴 변을 기준으로 입자 개수를 정함(긴 변 2px당 입자 하나 정도).
    final grainScale = math.max(outSize.width, outSize.height) / 2.0;
    shader.getUniformFloat('uGrainScale').set(grainScale);
    shader.getUniformFloat('uVignette').set(recipe.vignette);
    shader.getUniformFloat('uShadowDenoise').set(recipe.shadowDenoise);
    shader.getUniformFloat('uLutSize').set(kLutSize.toDouble());
    shader.getUniformFloat('uLutTiles').set(kLutTiles.toDouble());

    // 샘플러는 filterQuality를 지정해야 해서(이름 기반 ImageSamplerSlot엔
    // 그 옵션이 없음) 인덱스 기반 API를 씀 — GLSL에 선언된 순서대로
    // uSource가 0, uLut이 1 (sampler2D는 float 유니폼과 별개로 0부터 센다).
    shader.setImageSampler(0, source, filterQuality: ui.FilterQuality.low);
    shader.setImageSampler(1, lut, filterQuality: ui.FilterQuality.low);

    return shader;
  }
}
