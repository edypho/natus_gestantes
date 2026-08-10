import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureGoogleMaps()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureGoogleMaps() {
    let apiKey = (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard let apiKey, !apiKey.isEmpty, !apiKey.contains("$(") else {
      NSLog("Natus: GOOGLE_MAPS_IOS_API_KEY não configurada.")
      return
    }

    GMSServices.provideAPIKey(apiKey)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
