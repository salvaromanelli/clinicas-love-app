import ARKit
import Flutter
import UIKit
import Metal

// Clases de soporte
class ARKitGeometry {
    func toFlutterData() -> [String: Any] { return [:] }
}

class ARKitFaceGeometry: ARKitGeometry {
    var vertices: [simd_float3] = []
    var textureCoordinates: [simd_float2] = []
    var triangleIndices: [Int16] = []
    
    init(device: MTLDevice) {
        super.init()
        // Inicialización adicional si es necesaria
    }
    
    override func toFlutterData() -> [String: Any] {
        return [
            "vertices": vertices.map { [$0.x, $0.y, $0.z] },
            "textureCoordinates": textureCoordinates.map { [$0.x, $0.y] },
            "triangleIndices": triangleIndices
        ]
    }
}

// Enum para mapear las partes de la cara
enum FaceMeshSource: Int {
    case face = 0
    case forehead = 1
    case nose = 2
    case mouth = 3
    case cheeks = 4
    case jawline = 5
}

class FaceMeshGeometryHandler {
    
    // Mantener referencias a geometrías creadas
    static var geometries: [String: ARKitFaceGeometry] = [:]
    static var arView: ARSCNView?
    
    // Registrar el canal de métodos personalizado
    static func registerChannel(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.yourapp.arkit/face_mesh_geometry", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "createFaceMeshGeometry":
                createFaceMeshGeometry(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // Configurar la vista AR - debe ser llamado desde el controlador ARKit
    static func setupARView(_ view: ARSCNView) {
        arView = view
    }
    
    // Método principal más seguro
    private static func createFaceMeshGeometry(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Verificar argumentos de manera segura
        guard let args = call.arguments as? [String: Any],
            let sourceIndex = args["source"] as? Int,
            let scaleMultiplier = args["scaleMultiplier"] as? [Double],
            let positionOffset = args["positionOffset"] as? [Double] else {
            print("Error: Argumentos inválidos para createFaceMeshGeometry")
            result(FlutterError(code: "INVALID_ARGS", message: "Argumentos inválidos", details: nil))
            return
        }
        
        // Verificar que los arrays tienen el tamaño correcto
        guard scaleMultiplier.count >= 3, positionOffset.count >= 3 else {
            print("Error: scaleMultiplier o positionOffset no tienen suficientes elementos")
            result(FlutterError(code: "INVALID_ARGS", message: "scaleMultiplier o positionOffset inválidos", details: nil))
            return
        }
        
        // Convertir los datos de entrada de manera segura
        let source = FaceMeshSource(rawValue: sourceIndex) ?? .face
        let scale = simd_float3(Float(scaleMultiplier[0]), Float(scaleMultiplier[1]), Float(scaleMultiplier[2]))
        let offset = simd_float3(Float(positionOffset[0]), Float(positionOffset[1]), Float(positionOffset[2]))
        
        // Verificar que tenemos acceso a la sesión AR de manera segura
        guard let arView = self.arView else {
            print("Error: ARView no inicializada")
            // Devolver un ID de fallback
            let geometryId = "fallback_\(UUID().uuidString)"
            result(geometryId)
            return
        }
        
        // Verificar currentFrame y device de manera segura
        guard let currentFrame = arView.session.currentFrame,
            let device = arView.device else {
            print("Error: No hay frame actual o device disponible")
            // Devolver un ID de fallback
            let geometryId = "fallback_\(UUID().uuidString)"
            result(geometryId)
            return
        }
        
        // Obtener datos de la cara de manera segura
        guard let faceAnchor = currentFrame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            print("Error: No se detectó cara")
            result(FlutterError(code: "NO_FACE", message: "No se detectó cara", details: nil))
            return
        }
        
        // Obtener la geometría facial
        let faceGeometry = faceAnchor.geometry
        
        // Procesamiento en segundo plano para evitar bloqueos
        DispatchQueue.global(qos: .userInitiated).async {
            // Crear geometría modificada con manejo seguro
            if let modifiedGeometry = createModifiedFaceGeometry(
                from: faceGeometry,
                source: source, 
                scale: scale, 
                offset: offset, 
                device: device
            ) {
                // Crear un identificador único para la geometría
                let geometryId = UUID().uuidString
                
                // Volver al hilo principal para actualizar la UI
                DispatchQueue.main.async {
                    // Guardar la geometría para uso posterior
                    geometries[geometryId] = modifiedGeometry
                    
                    // Devolver el ID de la geometría al lado Dart
                    result(geometryId)
                }
            } else {
                // Volver al hilo principal para reportar error
                DispatchQueue.main.async {
                    print("Error: No se pudo crear geometría modificada")
                    result(FlutterError(
                        code: "GEOMETRY_CREATION_FAILED", 
                        message: "Error al crear geometría modificada", 
                        details: nil
                    ))
                }
            }
        }
    }

    // Crear una geometría facial modificada con manejo seguro de opcionales
    private static func createModifiedFaceGeometry(from originalGeometry: ARFaceGeometry, 
                                            source: FaceMeshSource, 
                                            scale: simd_float3, 
                                            offset: simd_float3, 
                                            device: MTLDevice) -> ARKitFaceGeometry? {
        // Verificar que la geometría original tiene vértices
        let vertexCount = originalGeometry.vertices.count
        if vertexCount == 0 {
            print("Error: La geometría facial original no contiene vértices")
            return nil
        }
        
        // Obtener los vértices originales de manera segura
        var vertices = [simd_float3]()
        for i in 0..<vertexCount {
            vertices.append(originalGeometry.vertices[i])
        }
        
        // Filtrar los vértices según la parte seleccionada
        let filteredVertices = filterFaceVertices(vertices, source: source)
        
        // Verificar que tenemos vértices después del filtrado
        if filteredVertices.isEmpty {
            print("Error: No hay vértices después del filtrado para source: \(source.rawValue)")
            return nil
        }
        
        // Aplicar escala y offset a los vértices filtrados
        let modifiedVertices = filteredVertices.map { vertex in
            return simd_float3(vertex.x * scale.x + offset.x,
                            vertex.y * scale.y + offset.y,
                            vertex.z * scale.z + offset.z)
        }
        
        // Verificar coordenadas de textura
        let textureCoordinateCount = originalGeometry.textureCoordinates.count
        if textureCoordinateCount == 0 {
            print("Error: La geometría facial original no contiene coordenadas de textura")
            return nil
        }
        
        // Asegurarse de no exceder el número de texturas disponibles
        let textureCount = min(filteredVertices.count, textureCoordinateCount)
        if textureCount == 0 {
            print("Error: No hay suficientes coordenadas de textura para los vértices")
            return nil
        }
        
        let textureCoords = Array(originalGeometry.textureCoordinates[0..<textureCount])
        
        // Verificar índices de triángulos
        if originalGeometry.triangleIndices.count == 0 {
            print("Error: La geometría facial original no contiene índices de triángulos")
            return nil
        }
        
        // Crear geometría con manejo seguro
        return createGeometry(vertices: modifiedVertices, 
                            textureCoords: textureCoords, 
                            triangleIndices: originalGeometry.triangleIndices, 
                            device: device)
    }
    
    // Filtrar vértices según la parte de la cara con manejo seguro de rangos
    private static func filterFaceVertices(_ vertices: [simd_float3], source: FaceMeshSource) -> [simd_float3] {
        // Verificar que tenemos vértices
        let totalVertices = vertices.count
        if totalVertices == 0 {
            print("Error: No hay vértices para filtrar")
            return []
        }
        
        switch source {
        case .face:
            return vertices // Toda la cara
            
        case .forehead:
            // Vértices aproximados para la frente (parte superior del rostro)
            let endIndex = min(Int(Double(totalVertices) * 0.25), totalVertices)
            if endIndex == 0 {
                return [] // No hay suficientes vértices
            }
            return Array(vertices[0..<endIndex])
            
        case .nose:
            // Vértices aproximados para la nariz (centro del rostro)
            let startIndex = min(Int(Double(totalVertices) * 0.3), totalVertices - 1)
            let endIndex = min(Int(Double(totalVertices) * 0.4), totalVertices)
            if startIndex >= endIndex {
                return [] // Rango inválido
            }
            return Array(vertices[startIndex..<endIndex])
            
        case .mouth:
            // Vértices aproximados para los labios (parte inferior del rostro)
            let startIndex = min(Int(Double(totalVertices) * 0.6), totalVertices - 1)
            let endIndex = min(Int(Double(totalVertices) * 0.75), totalVertices)
            if startIndex >= endIndex {
                return [] // Rango inválido
            }
            return Array(vertices[startIndex..<endIndex])
            
        case .cheeks:
            // Vértices aproximados para las mejillas (lados del rostro)
            var result: [simd_float3] = []
            
            let leftStart = min(Int(Double(totalVertices) * 0.4), totalVertices - 1)
            let leftEnd = min(Int(Double(totalVertices) * 0.5), totalVertices)
            if leftStart < leftEnd {
                result.append(contentsOf: vertices[leftStart..<leftEnd])
            }
            
            let rightStart = min(Int(Double(totalVertices) * 0.8), totalVertices - 1)
            let rightEnd = min(Int(Double(totalVertices) * 0.9), totalVertices)
            if rightStart < rightEnd {
                result.append(contentsOf: vertices[rightStart..<rightEnd])
            }
            
            return result
            
        case .jawline:
            // Vértices aproximados para la mandíbula (contorno del rostro)
            let startIndex = min(Int(Double(totalVertices) * 0.75), totalVertices - 1)
            let endIndex = min(Int(Double(totalVertices) * 0.95), totalVertices)
            if startIndex >= endIndex {
                return [] // Rango inválido
            }
            return Array(vertices[startIndex..<endIndex])
        }
    }
    
    // Crear una nueva geometría con manejo seguro
    private static func createGeometry(vertices: [simd_float3], 
                                    textureCoords: [simd_float2], 
                                    triangleIndices: [Int16], 
                                    device: MTLDevice) -> ARKitFaceGeometry? {
        // Verificaciones básicas
        guard !vertices.isEmpty, !textureCoords.isEmpty, !triangleIndices.isEmpty else {
            print("Error: Datos de geometría incompletos. Vértices: \(vertices.count), Texturas: \(textureCoords.count), Índices: \(triangleIndices.count)")
            return nil
        }
        
        // Crear geometría
        let geometry = ARKitFaceGeometry(device: device)
        
        // Asignar datos de manera segura
        geometry.vertices = vertices
        geometry.textureCoordinates = textureCoords
        geometry.triangleIndices = triangleIndices
        
        return geometry
    }
    
    // Funciones auxiliares para depuración
    private static func logGeometryDetails(_ geometry: ARFaceGeometry, source: FaceMeshSource) {
        print("AR Geometry Details:")
        print(" - Source: \(source)")
        print(" - Vertex Count: \(geometry.vertices.count)")
        print(" - Triangle Indices Count: \(geometry.triangleIndices.count)")
        print(" - Texture Coordinates Count: \(geometry.textureCoordinates.count)")
    }

    private static func logError(_ message: String) {
        print("⚠️ FaceMeshGeometryHandler Error: \(message)")
    }
    
    // Método para limpiar la cache de geometrías
    static func cleanupGeometries() {
        // Eliminar todas las geometrías guardadas
        geometries.removeAll()
        print("Limpiada la caché de geometrías faciales")
    }
}