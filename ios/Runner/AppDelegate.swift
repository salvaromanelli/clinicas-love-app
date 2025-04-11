import UIKit
import Flutter
import ARKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Usar una implementación directa para evitar problemas con módulos
    if let controller = window?.rootViewController as? FlutterViewController {
        FaceMeshGeometryHandler.registerChannel(messenger: controller.binaryMessenger)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}