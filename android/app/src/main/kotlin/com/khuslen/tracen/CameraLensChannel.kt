package com.khuslen.tracen

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * Android에서 후면 카메라의 물리 렌즈(초광각/표준/망원)를 Camera2
 * CameraCharacteristics로 분류해, 표준(1x) 렌즈 대비 줌 배율로 돌려주는
 * MethodChannel 핸들러.
 *
 * camera_android_camerax 플러그인은 lensType을 안 채워주므로(wide/unknown만),
 * Dart 쪽에서 렌즈 버튼을 보여주려면 이 분류가 필요함. Android는 iOS처럼
 * 카메라를 다시 여는 게 아니라, 논리 카메라에 이 배율로 setZoomLevel을
 * 호출하면 내부적으로 해당 물리 렌즈로 전환됨(OEM별로 정확한 전환 배율은
 * 조금씩 다를 수 있어 이 값은 근사치).
 */
class CameraLensChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "tracen/camera_lens"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getBackLensZoomRatios" -> result.success(getBackLensZoomRatios())
            else -> result.notImplemented()
        }
    }

    private data class Lens(val id: String, val focal35mm: Double)

    private fun getBackLensZoomRatios(): Map<String, Double> {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val backLenses = mutableListOf<Lens>()

        for (id in manager.cameraIdList) {
            val chars = manager.getCameraCharacteristics(id)
            if (chars.get(CameraCharacteristics.LENS_FACING) != CameraCharacteristics.LENS_FACING_BACK) {
                continue
            }
            val focalLengths = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val sensorSize = chars.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            if (focalLengths == null || focalLengths.isEmpty() || sensorSize == null) continue

            // 35mm 환산 = 실제 초점거리 * (36mm 풀프레임 폭 / 센서 폭)의 근사.
            // 센서 종횡비가 기기마다 조금씩 달라도 초광각/표준/망원 분류
            // 목적에는 이 근사로 충분함.
            val cropFactor = 36.0 / sensorSize.width
            val focal35mm = focalLengths[0].toDouble() * cropFactor
            backLenses.add(Lens(id, focal35mm))
        }

        if (backLenses.isEmpty()) return emptyMap()

        // 표준(wide) 기준점 — 28mm 환산에 가장 가까운 렌즈를 1x로 둠.
        val standard = backLenses.minByOrNull { abs(it.focal35mm - 28.0) } ?: backLenses[0]

        val zoomRatios = mutableMapOf<String, Double>()
        for (lens in backLenses) {
            val key = when {
                lens.focal35mm < 24.0 -> "ultraWide"
                lens.focal35mm > 35.0 -> "telephoto"
                else -> "wide"
            }
            // 같은 분류가 여러 개면 먼저 찾은 것만 유지.
            if (!zoomRatios.containsKey(key)) {
                zoomRatios[key] = lens.focal35mm / standard.focal35mm
            }
        }
        return zoomRatios
    }
}
