import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let wifiMetadataChannelName = "wifi_metadata"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: wifiMetadataChannelName,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { call, result in
        guard call.method == "load" else {
          result(FlutterMethodNotImplemented)
          return
        }

        result([
          "platform": "ios",
          "status": "unsupported_platform",
        ])
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
