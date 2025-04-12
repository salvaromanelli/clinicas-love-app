import UIKit
import Flutter
import ARKit

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Registrar canal para ARKit safety
    let controller = window?.rootViewController as? FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.clinicaslove.arkit_safety",
      binaryMessenger: controller!.binaryMessenger)
    
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "initializeARKit":
        // Solo verificar si ARKit está disponible
        result(ARFaceTrackingConfiguration.isSupported)
      case "isARKitSupported":
        result(ARFaceTrackingConfiguration.isSupported)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}