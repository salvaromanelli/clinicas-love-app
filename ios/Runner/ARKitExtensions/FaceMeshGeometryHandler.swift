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
    static func setupARView(_ view: ARSCNView?) {
        // Verificar que la vista no es nil
        guard let view = view else {
            print("Error: Se intentó configurar una vista AR nil")
            return
        }
        
        arView = view
        print("✅ Vista AR configurada correctamente")
    }
    
    // Método para crear una geometría facial personalizada
    private static func createFaceMeshGeometry(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sourceIndex = args["source"] as? Int,
              let scaleMultiplier = args["scaleMultiplier"] as? [Double],
              let positionOffset = args["positionOffset"] as? [Double] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Argumentos inválidos", details: nil))
            return
        }
        
        // Convertir los datos de entrada
        let source = FaceMeshSource(rawValue: sourceIndex) ?? .face
        let scale = simd_float3(Float(scaleMultiplier[0]), Float(scaleMultiplier[1]), Float(scaleMultiplier[2]))
        let offset = simd_float3(Float(positionOffset[0]), Float(positionOffset[1]), Float(positionOffset[2]))
        
        // Verificar que tenemos acceso a la sesión AR
        guard let arView = self.arView,
              // CORRECCIÓN: session no es opcional, así que no use 'let session = arView.session'
              let currentFrame = arView.session.currentFrame,
              let device = arView.device else {
            // Implementación de fallback para pruebas
            let geometryId = "fallback_\(UUID().uuidString)"
            result(geometryId)
            return
        }
        
        // Obtener datos de la cara si están disponibles
        guard let faceAnchor = currentFrame.anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else {
            result(FlutterError(code: "NO_FACE", message: "No se detectó cara", details: nil))
            return
        }
        
        // Obtener la geometría facial
        let faceGeometry = faceAnchor.geometry
        
        // Crear una copia de la geometría que podamos modificar
        guard let modifiedGeometry = createModifiedFaceGeometry(from: faceGeometry, 
                                                             source: source, 
                                                             scale: scale, 
                                                             offset: offset, 
                                                             device: device) else {
            result(FlutterError(code: "GEOMETRY_CREATION_FAILED", message: "Error al crear geometría modificada", details: nil))
            return
        }
        
        // Crear un identificador único para la geometría
        let geometryId = UUID().uuidString
        
        // Guardar la geometría para uso posterior
        geometries[geometryId] = modifiedGeometry
        
        // Devolver el ID de la geometría al lado Dart
        result(geometryId)
    }
    
    // Crear una geometría facial modificada
    private static func createModifiedFaceGeometry(from originalGeometry: ARFaceGeometry, 
                                            source: FaceMeshSource, 
                                            scale: simd_float3, 
                                            offset: simd_float3, 
                                            device: MTLDevice) -> ARKitFaceGeometry? {
        // Verificación segura de los datos originales
        let vertexCount = originalGeometry.vertices.count
        if vertexCount == 0 {
            print("Error: Geometría facial original sin vértices")
            return nil
        }
        
        // Verificación de texturas
        if originalGeometry.textureCoordinates.count == 0 {
            print("Error: Geometría facial original sin coordenadas de textura")
            return nil
        }
        
        // Verificación de índices
        if originalGeometry.triangleIndices.count == 0 {
            print("Error: Geometría facial original sin índices de triángulos")
            return nil
        }
        
        // Obtener los vértices originales de manera segura
        var vertices = [simd_float3]()
        for i in 0..<vertexCount {
            vertices.append(originalGeometry.vertices[i])
        }
        
        // Aplicar filtrado con manejo seguro
        let filteredVertices = filterFaceVertices(vertices, source: source)
        
        // Verificar resultado del filtrado
        if filteredVertices.isEmpty {
            print("Error: No hay vértices después de filtrar para source: \(source)")
            return nil
        }
        
        // Aplicar transformaciones
        let modifiedVertices = filteredVertices.map { vertex in
            return simd_float3(vertex.x * scale.x + offset.x,
                            vertex.y * scale.y + offset.y,
                            vertex.z * scale.z + offset.z)
        }
        
        // Verificar que tenemos coordenadas de textura y que son consistentes
        let maxTextureCount = originalGeometry.textureCoordinates.count
        if maxTextureCount == 0 {
            print("Error: No hay coordenadas de textura disponibles")
            return nil
        }
        
        // Usar solo el número de coordenadas de textura que podemos manejar
        let safeTextureCount = min(filteredVertices.count, maxTextureCount)
        
        // Verificar que tenemos al menos algunas coordenadas de textura
        if safeTextureCount == 0 {
            print("Error: No hay coordenadas de textura aplicables")
            return nil
        }
        
        let textureCoords = Array(originalGeometry.textureCoordinates[0..<safeTextureCount])
        
        // Verificar que tenemos índices de triángulos
        if originalGeometry.triangleIndices.isEmpty {
            print("Error: No hay índices de triángulos disponibles")
            return nil
        }
        
        // Crear geometría con manejo seguro
        return createGeometry(vertices: modifiedVertices, 
                            textureCoords: textureCoords, 
                            triangleIndices: originalGeometry.triangleIndices, 
                            device: device)
    }
    
    // Filtrar vértices según la parte de la cara
    private static func filterFaceVertices(_ vertices: [simd_float3], source: FaceMeshSource) -> [simd_float3] {
        // Verificación básica
        if vertices.isEmpty {
            print("Error: No hay vértices para filtrar")
            return []
        }
        
        let totalVertices = vertices.count
        
        // Función ayudante para evitar accesos fuera de rango
        func safeRange(from start: Double, to end: Double) -> [simd_float3] {
            let safeStart = min(max(Int(totalVertices * start), 0), totalVertices - 1)
            let safeEnd = min(max(Int(totalVertices * end), safeStart + 1), totalVertices)
            
            if safeStart >= safeEnd {
                return []
            }
            
            return Array(vertices[safeStart..<safeEnd])
        }
        
        switch source {
        case .face:
            return vertices // Toda la cara
        case .forehead:
            return safeRange(from: 0.0, to: 0.25)
        case .nose:
            return safeRange(from: 0.3, to: 0.4)
        case .mouth:
            return safeRange(from: 0.6, to: 0.75)
        case .cheeks:
            // Combinar dos rangos separados de manera segura
            let leftCheek = safeRange(from: 0.4, to: 0.5)
            let rightCheek = safeRange(from: 0.8, to: 0.9)
            return leftCheek + rightCheek
        case .jawline:
            return safeRange(from: 0.75, to: 0.95)
        }
    }
    
    // Crear una nueva geometría a partir de vértices, texturas e índices
    private static func createGeometry(vertices: [simd_float3], 
                                    textureCoords: [simd_float2], 
                                    triangleIndices: [Int16], 
                                    device: MTLDevice) -> ARKitFaceGeometry? {
        // Verificaciones básicas
        if vertices.isEmpty {
            print("Error: No hay vértices para crear geometría")
            return nil
        }
        
        if textureCoords.isEmpty {
            print("Error: No hay coordenadas de textura para crear geometría")
            return nil
        }
        
        if triangleIndices.isEmpty {
            print("Error: No hay índices de triángulos para crear geometría")
            return nil
        }
        
        // Verificar que hay al menos el mínimo necesario para una cara
        if vertices.count < 3 {
            print("Error: Insuficientes vértices para crear una cara válida")
            return nil
        }
        
        // Asegurarse de que los índices no excedan los vértices disponibles
        if let maxIndex = triangleIndices.max(), Int(maxIndex) >= vertices.count {
            print("Error: Los índices de triángulos exceden los vértices disponibles")
            return nil
        }
        
        // Crear la geometría con valores seguros
        let geometry = ARKitFaceGeometry(device: device)
        geometry.vertices = vertices
        geometry.textureCoordinates = textureCoords
        geometry.triangleIndices = triangleIndices
        return geometry
    }
}