import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API 키는 ios/Flutter/Secrets.xcconfig 에 GOOGLE_MAPS_API_KEY = ...
    // 로 저장하고 Info.plist 의 $(GOOGLE_MAPS_API_KEY) 빌드 설정으로 주입됩니다.
    // Secrets.xcconfig 는 .gitignore 에 등록되어 있어 저장소에 커밋되지 않습니다.
    let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String ?? ""
    GMSServices.provideAPIKey(mapsKey)

    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "InstagramStoryChannel") {
      InstagramStoryChannel.register(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// 인스타그램 스토리 편집 화면으로 이미지를 바로 넘기는 채널.
///
/// 이미지는 UIPasteboard에 Meta가 정한 키로 담고 `instagram-stories://share`
/// 를 연다. 배경(backgroundPath)이 없으면 topColor/bottomColor 그라데이션이
/// 배경이 되고, 스티커(stickerPath)는 인스타에서 옮기고 크기 조절할 수 있다.
/// 인스타가 없으면 false — Dart 쪽이 공유 시트로 폴백한다.
enum InstagramStoryChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "tracen/instagram_story", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "share", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      share(args, result: result)
    }
  }

  private static func share(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let appId = args["appId"] as? String,
          let url = URL(string: "instagram-stories://share?source_application=\(appId)"),
          UIApplication.shared.canOpenURL(url) else {
      result(false)
      return
    }
    var item: [String: Any] = [:]
    if let path = args["backgroundPath"] as? String, let data = FileManager.default.contents(atPath: path) {
      item["com.instagram.sharedSticker.backgroundImage"] = data
    }
    if let path = args["stickerPath"] as? String, let data = FileManager.default.contents(atPath: path) {
      item["com.instagram.sharedSticker.stickerImage"] = data
    }
    if let top = args["topColor"] as? String {
      item["com.instagram.sharedSticker.backgroundTopColor"] = top
    }
    if let bottom = args["bottomColor"] as? String {
      item["com.instagram.sharedSticker.backgroundBottomColor"] = bottom
    }
    UIPasteboard.general.setItems(
      [item],
      options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
    )
    UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
  }
}
