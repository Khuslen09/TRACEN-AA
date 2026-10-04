import 'dart:io';

import 'package:camera/camera.dart' show CameraLensType;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android에서 후면 카메라의 초광각/망원 렌즈를 감지하는 네이티브 브릿지.
///
/// iOS는 `camera_avfoundation` 플러그인이 `CameraDescription.lensType`을
/// 이미 채워주므로 이 채널이 필요 없음(호출 자체를 안 함). Android의
/// `camera_android_camerax` 구현은 `lensType`을 안 채워서(소스 확인됨),
/// Camera2 `CameraCharacteristics`로 직접 분류한 뒤 "표준(1x) 렌즈 대비
/// 줌 배율"로 돌려준다 — Android에서는 다른 물리 렌즈로의 전환이 카메라를
/// 다시 여는 게 아니라 논리 카메라에 그 배율로 `setZoomLevel`을 호출하는
/// 방식으로 이뤄짐(기기/OEM에 따라 정확한 전환 배율은 근사치).
class CameraLensChannel {
  CameraLensChannel._();

  static const _channel = MethodChannel('tracen/camera_lens');

  static Future<Map<CameraLensType, double>> getBackLensZoomRatios() async {
    if (!Platform.isAndroid) return const {};
    try {
      final result = await _channel.invokeMethod<Map>('getBackLensZoomRatios');
      if (result == null) return const {};
      final map = <CameraLensType, double>{};
      for (final entry in result.entries) {
        final type = switch (entry.key as String) {
          'ultraWide' => CameraLensType.ultraWide,
          'telephoto' => CameraLensType.telephoto,
          _ => CameraLensType.wide,
        };
        map[type] = (entry.value as num).toDouble();
      }
      return map;
    } catch (e) {
      debugPrint('CameraLensChannel 조회 실패: $e');
      return const {};
    }
  }
}
