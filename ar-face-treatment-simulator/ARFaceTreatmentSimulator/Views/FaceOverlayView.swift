import UIKit
import ARKit

class FaceOverlayView: UIView {
    
    var facePoints: [CGPoint] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.clear(rect)
        
        // Draw detected facial points
        context.setFillColor(UIColor.red.cgColor)
        for point in facePoints {
            let pointRect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fillEllipse(in: pointRect)
        }
    }
}