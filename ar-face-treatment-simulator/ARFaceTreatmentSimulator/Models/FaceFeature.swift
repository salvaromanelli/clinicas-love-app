import Foundation
import ARKit

struct FaceFeature {
    var leftEye: CGPoint?
    var rightEye: CGPoint?
    var nose: CGPoint?
    var mouth: CGPoint?
    var leftCheek: CGPoint?
    var rightCheek: CGPoint?
    var jawline: [CGPoint]?
    
    init(leftEye: CGPoint? = nil, rightEye: CGPoint? = nil, nose: CGPoint? = nil, mouth: CGPoint? = nil, leftCheek: CGPoint? = nil, rightCheek: CGPoint? = nil, jawline: [CGPoint]? = nil) {
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.nose = nose
        self.mouth = mouth
        self.leftCheek = leftCheek
        self.rightCheek = rightCheek
        self.jawline = jawline
    }
}