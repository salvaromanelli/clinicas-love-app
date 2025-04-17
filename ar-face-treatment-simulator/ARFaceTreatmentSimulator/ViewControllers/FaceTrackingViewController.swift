import UIKit
import ARKit

class FaceTrackingViewController: UIViewController, ARSessionDelegate {
    var arView: ARSCNView!
    var faceTrackingService: ARFaceTrackingService!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        startFaceTracking()
    }

    func setupARView() {
        arView = ARSCNView(frame: view.bounds)
        arView.delegate = self
        view.addSubview(arView)
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration)
    }

    func startFaceTracking() {
        faceTrackingService = ARFaceTrackingService(arView: arView)
        faceTrackingService.startTracking()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        faceTrackingService.processFaceData(frame: frame)
    }
}