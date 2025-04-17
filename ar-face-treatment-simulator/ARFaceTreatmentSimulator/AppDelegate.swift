import UIKit
import ARKit
import Flutter

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var currentFaceAnchor: ARFaceAnchor?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Flutter integration
        let flutterEngine = FlutterEngine(name: "my flutter engine")
        flutterEngine.run()
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = flutterViewController
        window?.makeKeyAndVisible()

        // MethodChannel for mask
        let channel = FlutterMethodChannel(name: "com.yourapp.arkit/face_points", binaryMessenger: flutterViewController.binaryMessenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "getFaceMask" {
                guard let anchor = self?.currentFaceAnchor else {
                    result(FlutterError(code: "NO_FACE", message: "No face anchor available", details: nil))
                    return
                }
                let maskImage = generateMaskFromFaceAnchor(anchor: anchor)
                if let pngData = maskImage.pngData() {
                    let base64String = pngData.base64EncodedString()
                    result(base64String)
                } else {
                    result(FlutterError(code: "NO_MASK", message: "Could not generate mask", details: nil))
                }
            }
        }

        // Configure AR session
        configureARSession()
        return true
    }

    private func configureARSession() {
        guard ARFaceTrackingConfiguration.isSupported else {
            print("Face tracking is not supported on this device.")
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        // Additional configuration settings can be added here
    }
}

// Utilidad para generar una máscara simple (ejemplo: todos los puntos faciales en blanco sobre negro)
func generateMaskFromFaceAnchor(anchor: ARFaceAnchor) -> UIImage {
    let size = CGSize(width: 256, height: 256)
    UIGraphicsBeginImageContext(size)
    guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    context.setFillColor(UIColor.white.cgColor)
    for vertex in anchor.geometry.vertices {
        let x = CGFloat(vertex.x + 0.5) * size.width
        let y = CGFloat(1.0 - (vertex.y + 0.5)) * size.height
        context.fillEllipse(in: CGRect(x: x-2, y: y-2, width: 4, height: 4))
    }
    let maskImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return maskImage
}