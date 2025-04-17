import ARKit
import UIKit

class ARFaceTrackingService: NSObject, ARSessionDelegate {
    private var arView: ARSCNView
    private var faceAnchor: ARFaceAnchor?
    
    init(arView: ARSCNView) {
        self.arView = arView
        super.init()
        self.setupARSession()
    }
    
    private func setupARSession() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        arView.session.run(configuration)
        arView.session.delegate = self
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let faceAnchors = frame.anchors.compactMap({ $0 as? ARFaceAnchor }), let faceAnchor = faceAnchors.first else {
            return
        }
        
        self.faceAnchor = faceAnchor
        let facialPoints = extractFacialPoints(from: faceAnchor)
        sendFacialPointsToReplicate(points: facialPoints)
    }
    
    private func extractFacialPoints(from faceAnchor: ARFaceAnchor) -> [String: simd_float3] {
        var points: [String: simd_float3] = [:]
        
        for landmark in faceAnchor.blendShapes {
            points[landmark.key.rawValue] = faceAnchor.transform.columns.3.xyz
        }
        
        return points
    }
    
    private func sendFacialPointsToReplicate(points: [String: simd_float3]) {
        // Implement the logic to send points to Replicate API
    }
}