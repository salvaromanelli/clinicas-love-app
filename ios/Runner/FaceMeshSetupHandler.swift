import Flutter
import ARKit

public class FaceMeshSetupHandler: NSObject, FlutterPlugin {
    // Referencia estática a la vista ARKit
    private static var arView: ARSCNView?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.yourapp.arkit/face_mesh_setup", binaryMessenger: registrar.messenger())
        let instance = FaceMeshSetupHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        print("✅ Registrado canal com.yourapp.arkit/face_mesh_setup")
    }
    
    // Método para configurar la ARView
    public static func setupARView(_ view: ARSCNView?) {
        arView = view
        print("✅ ARView configurada correctamente en FaceMeshSetupHandler")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setupFaceMeshHandler":
            // Este método será llamado desde Flutter
            if let arView = FaceMeshSetupHandler.arView {
                // Configurar el handler de FaceMesh con la vista AR existente
                FaceMeshGeometryHandler.setupARView(arView)
                print("✅ FaceMeshGeometryHandler configurado con ARView existente")
                result(true)
            } else {
                print("❌ Error: ARView no inicializada")
                result(FlutterError(code: "NO_ARVIEW", 
                                   message: "ARView no inicializada", 
                                   details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}