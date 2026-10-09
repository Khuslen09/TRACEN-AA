package com.khuslen.tracen

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 인스타그램 스토리 편집 화면으로 이미지를 바로 넘기는 MethodChannel 핸들러.
 *
 * - backgroundPath: 스토리 배경 이미지(9:16)
 * - stickerPath: 배경 위에 올라가는 스티커(투명 PNG) — 인스타에서 옮기고 크기 조절 가능
 * - 배경이 없으면 topColor/bottomColor 그라데이션이 배경이 됨
 *
 * 인스타가 설치돼 있지 않으면 false를 돌려줘 Dart 쪽이 공유 시트로 폴백한다.
 */
class InstagramStoryChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "tracen/instagram_story"
        private const val INSTAGRAM_PACKAGE = "com.instagram.android"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "share" -> result.success(share(call))
            "shareToApp" -> result.success(shareToApp(call.argument<String>("path")))
            else -> result.notImplemented()
        }
    }

    private fun share(call: MethodCall): Boolean {
        val appId = call.argument<String>("appId") ?: return false
        val background = call.argument<String>("backgroundPath")?.let(::uriFor)
        val sticker = call.argument<String>("stickerPath")?.let(::uriFor)

        val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
            putExtra("source_application", appId)
            if (background != null) {
                setDataAndType(background, "image/png")
            } else {
                type = "image/png"
            }
            if (sticker != null) putExtra("interactive_asset_uri", sticker)
            call.argument<String>("topColor")?.let { putExtra("top_background_color", it) }
            call.argument<String>("bottomColor")?.let { putExtra("bottom_background_color", it) }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        for (uri in listOfNotNull(background, sticker)) {
            activity.grantUriPermission(INSTAGRAM_PACKAGE, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (activity.packageManager.resolveActivity(intent, 0) == null) return false
        activity.startActivityForResult(intent, 0)
        return true
    }

    /**
     * 인스타 앱으로 일반 이미지 공유(ACTION_SEND) — 인스타가 피드/스토리/
     * 릴스/메시지 선택 화면을 띄운다. 앱 ID가 필요 없다.
     */
    private fun shareToApp(path: String?): Boolean {
        if (path == null) return false
        val uri = uriFor(path)
        val intent = Intent(Intent.ACTION_SEND).apply {
            setPackage(INSTAGRAM_PACKAGE)
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (activity.packageManager.resolveActivity(intent, 0) == null) return false
        activity.startActivity(intent)
        return true
    }

    private fun uriFor(path: String): Uri =
        FileProvider.getUriForFile(activity, "${activity.packageName}.instagram_share", File(path))
}
