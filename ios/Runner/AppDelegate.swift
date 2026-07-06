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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
