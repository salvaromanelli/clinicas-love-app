import UIKit
import Flutter
import ARKit

@UIApplicationMain
class AppDelegate: FlutterAppDelegate, ARSessionDelegate {
  var currentAnchor: ARFaceAnchor? // Debes actualizar esto desde tu ARSessionDelegate
  var arSession: ARSession? 

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller = window?.rootViewController as? FlutterViewController

    // Canal para ARKit safety (puedes dejarlo si lo usas)
    let safetyChannel = FlutterMethodChannel(
      name: "com.clinicaslove.arkit_safety",
      binaryMessenger: controller!.binaryMessenger)
    safetyChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "initializeARKit":
        result(ARFaceTrackingConfiguration.isSupported)
      case "isARKitSupported":
        result(ARFaceTrackingConfiguration.isSupported)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Canal para máscaras faciales
    let maskChannel = FlutterMethodChannel(
      name: "com.yourapp.arkit/face_points", // Debe coincidir con tu código Dart
      binaryMessenger: controller!.binaryMessenger)
    maskChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getFaceMask":
        guard let args = call.arguments as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "No feature provided", details: nil))
          return
        }
        let feature = args
        // Debes tener el anchor actual de la sesión ARKit
        guard let anchor = self?.currentAnchor else {
          result(FlutterError(code: "NO_ANCHOR", message: "No ARFaceAnchor available", details: nil))
          return
        }
        let maskImage = self?.generateMaskFromFaceAnchor(anchor: anchor, feature: feature) ?? UIImage()
        guard let maskData = maskImage.pngData() else {
          result(FlutterError(code: "MASK_ERROR", message: "Could not encode mask image", details: nil))
          return
        }
        let base64String = maskData.base64EncodedString()
        result(base64String)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    setupARSession()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func setupARSession() {
    arSession = ARSession()
    arSession?.delegate = self
    let configuration = ARFaceTrackingConfiguration()
    arSession?.run(configuration)
  }

  // Implementa el delegate para actualizar el anchor
  func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    for anchor in anchors {
      if let faceAnchor = anchor as? ARFaceAnchor {
        self.currentAnchor = faceAnchor
      }
    }
  }


  func generateMaskFromFaceAnchor(anchor: ARFaceAnchor, feature: String) -> UIImage {
    let size = CGSize(width: 512, height: 512) // Tamaño estándar para ControlNet
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
    guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
    
    // Fondo negro (transparent para ControlNet)
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    
    // Color blanco para la zona a modificar
    context.setFillColor(UIColor.white.cgColor)
    
    switch feature {
    case "lips":
        // Índices de labios en ARKit (adapta según la documentación)
        let upperLipIndices = [0, 1, 2, 3, 4, 5, 6, 7]
        let lowerLipIndices = [8, 9, 10, 11, 12, 13, 14, 15]
        
        // Convierte las coordenadas 3D de ARKit a 2D en la imagen
        var upperLipPoints: [CGPoint] = []
        for idx in upperLipIndices {
            let vertex = anchor.geometry.vertices[idx + 48] // Offset para los índices de labios
            let point = CGPoint(
                x: CGFloat(vertex.x + 0.5) * size.width,
                y: CGFloat(1.0 - (vertex.y + 0.5)) * size.height
            )
            upperLipPoints.append(point)
        }
        
        var lowerLipPoints: [CGPoint] = []
        for idx in lowerLipIndices {
            let vertex = anchor.geometry.vertices[idx + 56] // Offset para los índices de labios inferiores
            let point = CGPoint(
                x: CGFloat(vertex.x + 0.5) * size.width,
                y: CGFloat(1.0 - (vertex.y + 0.5)) * size.height
            )
            lowerLipPoints.append(point)
        }
        
        // Dibuja el polígono cerrado para los labios
        if !upperLipPoints.isEmpty && !lowerLipPoints.isEmpty {
            let path = UIBezierPath()
            path.move(to: upperLipPoints[0])
            
            // Añade todos los puntos al path
            for point in upperLipPoints {
                path.addLine(to: point)
            }
            for point in lowerLipPoints.reversed() {
                path.addLine(to: point)
            }
            
            path.close()
            context.addPath(path.cgPath)
            context.fillPath()
            
            // Suavizar los bordes (importante para ControlNet)
            context.setBlendMode(.normal)
            context.setShadow(offset: .zero, blur: 5.0, color: UIColor.white.withAlphaComponent(0.5).cgColor)
            context.addPath(path.cgPath)
            context.fillPath()
        }
        
    case "nose":
        // Para la nariz, usamos puntos específicos de ARKit
        // Índices aproximados para el puente nasal y la punta
        let noseIndices = [27, 28, 29, 30, 31, 32, 33]
        
        var nosePoints: [CGPoint] = []
        for idx in noseIndices {
            let vertex = anchor.geometry.vertices[idx]
            let point = CGPoint(
                x: CGFloat(vertex.x + 0.5) * size.width,
                y: CGFloat(1.0 - (vertex.y + 0.5)) * size.height
            )
            nosePoints.append(point)
        }
        
        // Crear un polígono para la nariz
        if !nosePoints.isEmpty {
            // Crear un área más grande alrededor de los puntos nasales
            let noseCenter = CGPoint(
                x: nosePoints.reduce(0, { $0 + $1.x }) / CGFloat(nosePoints.count),
                y: nosePoints.reduce(0, { $0 + $1.y }) / CGFloat(nosePoints.count)
            )
            
            // Dibujar un óvalo para la nariz
            let noseWidth = size.width * 0.12
            let noseHeight = size.height * 0.2
            let noseRect = CGRect(
                x: noseCenter.x - noseWidth/2,
                y: noseCenter.y - noseHeight/2,
                width: noseWidth,
                height: noseHeight
            )
            
            let nosePath = UIBezierPath(ovalIn: noseRect)
            context.addPath(nosePath.cgPath)
            context.fillPath()
            
            // Suavizar los bordes
            context.setShadow(offset: .zero, blur: 5.0, color: UIColor.white.withAlphaComponent(0.5).cgColor)
            context.addPath(nosePath.cgPath)
            context.fillPath()
        }
        
    case "jawline":
        // Puntos para la mandíbula
        let jawIndices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
        
        var jawPoints: [CGPoint] = []
        for idx in jawIndices {
            let vertex = anchor.geometry.vertices[idx]
            let point = CGPoint(
                x: CGFloat(vertex.x + 0.5) * size.width,
                y: CGFloat(1.0 - (vertex.y + 0.5)) * size.height
            )
            jawPoints.append(point)
        }
        
        if !jawPoints.isEmpty {
            // Crear un trazo más ancho para la mandíbula
            let jawPath = UIBezierPath()
            jawPath.move(to: jawPoints[0])
            
            for point in jawPoints {
                jawPath.addLine(to: point)
            }
            
            // Hacer un trazo ancho en lugar de relleno
            jawPath.lineWidth = 20
            UIColor.white.setStroke()
            jawPath.stroke()
            
            // Suavizar los bordes
            context.setShadow(offset: .zero, blur: 8.0, color: UIColor.white.withAlphaComponent(0.6).cgColor)
            jawPath.stroke()
        }
        
    case "botox":
        // Para botox, enfocarse en áreas típicas: frente, entrecejo y patas de gallo
        
        // Área de la frente
        let foreheadRect = CGRect(x: size.width * 0.3, y: size.height * 0.1, 
                                width: size.width * 0.4, height: size.height * 0.15)
        context.fillEllipse(in: foreheadRect)
        
        // Entrecejo
        let eyebrowRect = CGRect(x: size.width * 0.45, y: size.height * 0.28, 
                              width: size.width * 0.1, height: size.height * 0.05)
        context.fillEllipse(in: eyebrowRect)
        
        // Patas de gallo (izquierda y derecha)
        let leftCrowsRect = CGRect(x: size.width * 0.2, y: size.height * 0.32, 
                                width: size.width * 0.1, height: size.height * 0.05)
        let rightCrowsRect = CGRect(x: size.width * 0.7, y: size.height * 0.32, 
                                  width: size.width * 0.1, height: size.height * 0.05)
        
        context.fillEllipse(in: leftCrowsRect)
        context.fillEllipse(in: rightCrowsRect)
        
        // Suavizar los bordes
        context.setShadow(offset: .zero, blur: 15.0, color: UIColor.white.withAlphaComponent(0.5).cgColor)
        context.fillEllipse(in: foreheadRect)
        context.fillEllipse(in: eyebrowRect)
        context.fillEllipse(in: leftCrowsRect)
        context.fillEllipse(in: rightCrowsRect)
        
    case "fillers":
        // Para rellenos faciales, enfocarse en pliegues nasolabiales y mejillas
        
        // Pliegues nasolabiales
        let leftFoldPath = UIBezierPath()
        leftFoldPath.move(to: CGPoint(x: size.width * 0.35, y: size.height * 0.4))
        leftFoldPath.addLine(to: CGPoint(x: size.width * 0.3, y: size.height * 0.6))
        leftFoldPath.lineWidth = 15
        UIColor.white.setStroke()
        leftFoldPath.stroke()
        
        let rightFoldPath = UIBezierPath()
        rightFoldPath.move(to: CGPoint(x: size.width * 0.65, y: size.height * 0.4))
        rightFoldPath.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.6))
        rightFoldPath.lineWidth = 15
        rightFoldPath.stroke()
        
        // Mejillas
        let leftCheekRect = CGRect(x: size.width * 0.2, y: size.height * 0.45, 
                                width: size.width * 0.15, height: size.height * 0.12)
        let rightCheekRect = CGRect(x: size.width * 0.65, y: size.height * 0.45, 
                                  width: size.width * 0.15, height: size.height * 0.12)
        
        context.fillEllipse(in: leftCheekRect)
        context.fillEllipse(in: rightCheekRect)
        
        // Suavizar los bordes
        context.setShadow(offset: .zero, blur: 10.0, color: UIColor.white.withAlphaComponent(0.5).cgColor)
        leftFoldPath.stroke()
        rightFoldPath.stroke()
        context.fillEllipse(in: leftCheekRect)
        context.fillEllipse(in: rightCheekRect)
        
    case "cheeks":
        // Para aumento de pómulos
        let leftCheekboneRect = CGRect(x: size.width * 0.15, y: size.height * 0.4, 
                                    width: size.width * 0.2, height: size.height * 0.1)
        let rightCheekboneRect = CGRect(x: size.width * 0.65, y: size.height * 0.4, 
                                      width: size.width * 0.2, height: size.height * 0.1)
        
        // Dibujar elipses para los pómulos
        let leftCheekPath = UIBezierPath(ovalIn: leftCheekboneRect)
        let rightCheekPath = UIBezierPath(ovalIn: rightCheekboneRect)
        
        context.addPath(leftCheekPath.cgPath)
        context.fillPath()
        context.addPath(rightCheekPath.cgPath)
        context.fillPath()
        
        // Suavizar los bordes
        context.setShadow(offset: .zero, blur: 12.0, color: UIColor.white.withAlphaComponent(0.6).cgColor)
        context.addPath(leftCheekPath.cgPath)
        context.fillPath()
        context.addPath(rightCheekPath.cgPath)
        context.fillPath()
        
    case "double_chin":
        // Para reducción de papada
        let chinPath = UIBezierPath()
        
        // Definir el área de la papada
        chinPath.move(to: CGPoint(x: size.width * 0.3, y: size.height * 0.7))
        chinPath.addCurve(to: CGPoint(x: size.width * 0.7, y: size.height * 0.7),
                        controlPoint1: CGPoint(x: size.width * 0.4, y: size.height * 0.85),
                        controlPoint2: CGPoint(x: size.width * 0.6, y: size.height * 0.85))
        
        // Cerrar el path conectando con la mandíbula
        chinPath.addCurve(to: CGPoint(x: size.width * 0.3, y: size.height * 0.7),
                        controlPoint1: CGPoint(x: size.width * 0.6, y: size.height * 0.75),
                        controlPoint2: CGPoint(x: size.width * 0.4, y: size.height * 0.75))
        
        chinPath.close()
        
        // Rellenar y aplicar el trazo
        context.addPath(chinPath.cgPath)
        context.fillPath()
        
        // Suavizar los bordes
        context.setShadow(offset: .zero, blur: 10.0, color: UIColor.white.withAlphaComponent(0.5).cgColor)
        context.addPath(chinPath.cgPath)
        context.fillPath()
        
    case "eye_enhance":
        // Para realce de ojos
        // Posiciones aproximadas de los ojos
        let leftEyeRect = CGRect(x: size.width * 0.25, y: size.height * 0.35, 
                              width: size.width * 0.15, height: size.height * 0.08)
        let rightEyeRect = CGRect(x: size.width * 0.6, y: size.height * 0.35, 
                                width: size.width * 0.15, height: size.height * 0.08)
        
        // Dibujar los ojos con un poco más de área para maquillaje/realce
        let leftEyePath = UIBezierPath(ovalIn: leftEyeRect.insetBy(dx: -8, dy: -5))
        let rightEyePath = UIBezierPath(ovalIn: rightEyeRect.insetBy(dx: -8, dy: -5))
        
        context.addPath(leftEyePath.cgPath)
        context.fillPath()
        context.addPath(rightEyePath.cgPath)
        context.fillPath()
        
        // Suavizar los bordes
        context.setShadow(offset: .zero, blur: 8.0, color: UIColor.white.withAlphaComponent(0.6).cgColor)
        context.addPath(leftEyePath.cgPath)
        context.fillPath()
        context.addPath(rightEyePath.cgPath)
        context.fillPath()
        
    case "skin_retouch":
        // Para retoque de piel, aplicar a toda la cara con una máscara que excluya ojos y labios
        
        // Crear un óvalo que cubra toda la cara
        let faceOval = CGRect(x: size.width * 0.25, y: size.height * 0.15, 
                            width: size.width * 0.5, height: size.height * 0.7)
        
        let facePath = UIBezierPath(ovalIn: faceOval)
        
        // Excluir ojos y boca (si tuviéramos información precisa de ARKit)
        // Aquí usamos posiciones aproximadas
        let leftEyeRect = CGRect(x: size.width * 0.3, y: size.height * 0.35, 
                              width: size.width * 0.12, height: size.height * 0.06)
        let rightEyeRect = CGRect(x: size.width * 0.58, y: size.height * 0.35, 
                                width: size.width * 0.12, height: size.height * 0.06)
        let mouthRect = CGRect(x: size.width * 0.35, y: size.height * 0.55, 
                            width: size.width * 0.3, height: size.height * 0.1)
        
        let leftEyePath = UIBezierPath(ovalIn: leftEyeRect)
        let rightEyePath = UIBezierPath(ovalIn: rightEyeRect)
        let mouthPath = UIBezierPath(ovalIn: mouthRect)
        
        // Aplicar la máscara excluyendo ojos y boca
        context.addPath(facePath.cgPath)
        context.fillPath()
        
        // Cortar los ojos y la boca (haciendo agujeros en la máscara)
        context.setBlendMode(.clear)
        UIColor.black.setFill()
        context.addPath(leftEyePath.cgPath)
        context.fillPath()
        context.addPath(rightEyePath.cgPath)
        context.fillPath()
        context.addPath(mouthPath.cgPath)
        context.fillPath()
        
        // Restablecer el modo de mezcla
        context.setBlendMode(.normal)
        
    case "face_shape":
        // Para modelado facial completo, enfocarse en el contorno facial
        
        // Crear un contorno facial simplificado
        let facePath = UIBezierPath()
        
        // Forehead
        facePath.move(to: CGPoint(x: size.width * 0.3, y: size.height * 0.2))
        facePath.addLine(to: CGPoint(x: size.width * 0.7, y: size.height * 0.2))
        
        // Right side
        facePath.addCurve(to: CGPoint(x: size.width * 0.75, y: size.height * 0.6),
                        controlPoint1: CGPoint(x: size.width * 0.75, y: size.height * 0.3),
                        controlPoint2: CGPoint(x: size.width * 0.8, y: size.height * 0.45))
        
        // Jaw and chin
        facePath.addCurve(to: CGPoint(x: size.width * 0.5, y: size.height * 0.75),
                        controlPoint1: CGPoint(x: size.width * 0.7, y: size.height * 0.7),
                        controlPoint2: CGPoint(x: size.width * 0.6, y: size.height * 0.75))
        
        // Left jaw and face
        facePath.addCurve(to: CGPoint(x: size.width * 0.25, y: size.height * 0.6),
                        controlPoint1: CGPoint(x: size.width * 0.4, y: size.height * 0.75),
                        controlPoint2: CGPoint(x: size.width * 0.3, y: size.height * 0.7))
        
        // Complete the path
        facePath.addCurve(to: CGPoint(x: size.width * 0.3, y: size.height * 0.2),
                        controlPoint1: CGPoint(x: size.width * 0.2, y: size.height * 0.45),
                        controlPoint2: CGPoint(x: size.width * 0.25, y: size.height * 0.3))
        
        facePath.lineWidth = 15
        UIColor.white.setStroke()
        facePath.stroke()
        
        // Difuminar los bordes para un efecto más suave
        context.setShadow(offset: .zero, blur: 10.0, color: UIColor.white.withAlphaComponent(0.6).cgColor)
        facePath.stroke()
        
    default:
        // Para cualquier otra característica, crear una máscara genérica de área facial
        print("Generando máscara genérica para: \(feature)")
        
        // Dibujar un óvalo que cubra el área facial central
        let faceOval = CGRect(x: size.width * 0.25, y: size.height * 0.2, 
                            width: size.width * 0.5, height: size.height * 0.6)
        
        let facePath = UIBezierPath(ovalIn: faceOval)
        context.addPath(facePath.cgPath)
        context.fillPath()
        
        // Suavizar los bordes
        context.setShadow(offset: .zero, blur: 12.0, color: UIColor.white.withAlphaComponent(0.5).cgColor)
        context.addPath(facePath.cgPath)
        context.fillPath()
    }
    
    let maskImage = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return maskImage
  }
}
