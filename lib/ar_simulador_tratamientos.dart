import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';


class ARTratamientosPage extends StatefulWidget {
  final String initialTreatment;
  final double initialIntensity;
  
  const ARTratamientosPage({
    Key? key, 
    required this.initialTreatment,
    required this.initialIntensity,
  }) : super(key: key);

  @override
  State<ARTratamientosPage> createState() => _ARTratamientosPageState();
}

// Define esta enumeración cerca del principio de tu archivo
enum ARKitFaceMeshSource {
  face,
  forehead,
  nose,
  mouth,
  cheeks,
  jawline,
}
// Extiende ARKitGeometry para crear una geometría facial personalizada
class ARKitFaceMeshGeometry extends ARKitGeometry {
  static const MethodChannel _channel = MethodChannel('com.yourapp.arkit/face_mesh_geometry');
  String? identifier;

  ARKitFaceMeshGeometry({
    required ARKitFaceMeshSource source,
    vector.Vector3? scaleMultiplier,
    vector.Vector3? positionOffset,
  }) : super() {
    _createGeometry(source, scaleMultiplier, positionOffset);
  }

  void _createGeometry(
    ARKitFaceMeshSource source,
    vector.Vector3? scaleMultiplier,
    vector.Vector3? positionOffset
  ) {
    final params = {
      'source': source.index,
      'scaleMultiplier': scaleMultiplier != null 
          ? [scaleMultiplier.x, scaleMultiplier.y, scaleMultiplier.z] 
          : [1.0, 1.0, 1.0],
      'positionOffset': positionOffset != null 
          ? [positionOffset.x, positionOffset.y, positionOffset.z] 
          : [0.0, 0.0, 0.0],
    };
    
    try {
      _channel.invokeMethod('createFaceMeshGeometry', params).then((geometryId) {
        if (geometryId != null && geometryId is String) {
          identifier = geometryId;
        }
      }).catchError((e) {
        print("Error creando geometría facial: $e");
      });
    } catch (e) {
      print("Error invocando método nativo: $e");
    }
  }
  
  @override
  Map<String, dynamic> toJson() {
    return {'identifier': identifier, 'type': 'faceMeshGeometry'};
  }
}

class _ARTratamientosPageState extends State<ARTratamientosPage> with WidgetsBindingObserver {
  ARKitController? arkitController;
  ARKitNode? faceNode;
  ARKitFaceAnchor? faceAnchor;
  late String _selectedTreatment;
  late double _intensity;
  bool _isCapturing = false;
  bool _isRecording = false;
  File? _resultImage;
  String? _videoPath;
  VideoPlayerController? _videoController;
  bool _isVideoPlayerInitialized = false;
  bool _showControls = true;
  bool _isEffectBeingApplied = false;
  DateTime _lastApplyAttempt = DateTime.now();
  int _consecutiveErrors = 0;
  bool _useSimpleFallback = false;
  
  // Timer para ocultar controles de UI durante grabación
  Timer? _controlsTimer;
  
  final Map<String, String> _treatmentTranslations = {
    'lips': 'Aumento de labios',
    'nose': 'Rinomodelación',
    'botox': 'Botox',
    'fillers': 'Rellenos faciales',
    'skincare': 'Tratamiento de piel',
    'lifting': 'Lifting facial'
  };

  @override
  void initState() {
    super.initState();
    _selectedTreatment = widget.initialTreatment;
    _intensity = widget.initialIntensity;
    _requestPermissions();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    arkitController?.dispose();
    _videoController?.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detener grabación si la app pasa a segundo plano
    if (state == AppLifecycleState.paused && _isRecording) {
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.microphone.request(); // Para grabación de video
    await Permission.storage.request(); // Para guardar fotos/videos
  }
  

  void _onARKitViewCreated(ARKitController controller) {
    arkitController = controller;

    

    // Registrarse para actualizaciones de seguimiento facial
    arkitController!.onAddNodeForAnchor = _handleAddAnchor;
    arkitController!.onUpdateNodeForAnchor = _handleUpdateAnchor;

  }
  

  void _handleAddAnchor(ARKitAnchor anchor) {
    if (anchor is! ARKitFaceAnchor) return;
    faceAnchor = anchor;
    _updateFaceMesh(anchor);
  }

  void _handleUpdateAnchor(ARKitAnchor anchor) {
    if (anchor is! ARKitFaceAnchor || faceNode == null) return;
    faceAnchor = anchor;
    _updateFaceMesh(anchor);
  }


void _updateFaceMesh(ARKitFaceAnchor anchor) {
  try {
    // Si la bandera ha estado activa por más de 3 segundos, forzar reset
    if (_isEffectBeingApplied) {
      final now = DateTime.now();
      if (now.difference(_lastApplyAttempt).inSeconds > 3) {
        print("🚨 Forzando reset de bandera después de timeout");
        _isEffectBeingApplied = false; // Forzar reset
        _consecutiveErrors++; // Incrementar contador de errores
        
        // Si hay demasiados errores consecutivos, usar fallback simple
        if (_consecutiveErrors > 3) {
          _useSimpleFallback = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Usando modo simplificado debido a errores")),
          );
        }
      }
    }
    
    // Aplicar efecto realista según tratamiento
    _applyRealisticEffect(anchor);
    
  } catch (e) {
    print("Error en updateFaceMesh: $e");
  }
}

ARKitMaterial _createSaferMaterial(String treatment, double opacity) {
  // Valores por defecto seguros
  Color diffuseColor = Colors.blue;
  double transparencyValue = 0.8;
  ARKitLightingModel lightingModel = ARKitLightingModel.blinn; // Cambio de tipo
  bool doubleSided = true;
  
  switch (treatment) {
    case 'lips':
      diffuseColor = Colors.red.shade300;
      transparencyValue = 0.7;
      break;
    case 'nose':
      diffuseColor = Colors.blue.shade200;
      transparencyValue = 0.75;
      break;
    case 'botox':
      diffuseColor = Colors.purple.shade100;
      transparencyValue = 0.85;
      lightingModel = ARKitLightingModel.constant; // Esto ahora es correcto
      break;
    case 'fillers':
      diffuseColor = Colors.amber.shade200;
      transparencyValue = 0.8;
      break;
    case 'lifting':
      diffuseColor = Colors.teal.shade100;
      transparencyValue = 0.85;
      break;
    case 'skincare':
      diffuseColor = Colors.white;
      transparencyValue = 0.9;
      break;
  }
  
  // Crear un material con valores seguros
  return ARKitMaterial(
    diffuse: ARKitMaterialProperty.color(diffuseColor.withOpacity(opacity * 0.3)),
    transparency: transparencyValue,
    lightingModelName: lightingModel, // Aquí se usa el enum directamente
    doubleSided: doubleSided,
  );
}

void _applyRealisticEffect(ARKitFaceAnchor anchor) {
  // Evitar aplicaciones simultáneas que podrían congelar la app
  if (_isEffectBeingApplied) {
    print("⚠️ Ya hay un efecto aplicándose, esperando...");
    
    // Si ha pasado demasiado tiempo, forzar reset
    final now = DateTime.now();
    if (now.difference(_lastApplyAttempt).inSeconds > 3) {
      print("🚨 Forzando reset de bandera después de timeout");
      _isEffectBeingApplied = false;
      _consecutiveErrors++;
      
      // Si hay demasiados errores consecutivos, usar modo simple
      if (_consecutiveErrors > 3 && !_useSimpleFallback) {
        setState(() {
          _useSimpleFallback = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Cambiando a modo simplificado debido a errores")),
          );
        });
      }
    } else {
      return; // Esperar si no ha pasado suficiente tiempo
    }
  }
  
  try {
    _isEffectBeingApplied = true;
    _lastApplyAttempt = DateTime.now();
    
    // Limpiar nodos anteriores
    arkitController?.remove("treatment_effect_overlay");
    arkitController?.remove("skincare_glow_overlay");
    
    // Si estamos en modo fallback, usar un efecto muy simple
    if (_useSimpleFallback) {
      _applySimpleFallback(anchor);
      return;
    }
    
    // Convertir intensidad a valor significativo
    final effectIntensity = 0.01 + (_intensity * 0.24);
    
    // Usar Future.microtask para permitir que la UI responda
    Future.microtask(() async {
      try {
        // Usar el generador de material seguro
        final effectMaterial = _createSaferMaterial(_selectedTreatment, _intensity);
        
        switch (_selectedTreatment) {
          case 'lips':
            await _applyMouthEffect(anchor, effectMaterial, effectIntensity);
            break;
          case 'nose':
            await _applyNoseEffect(anchor, effectMaterial, effectIntensity);
            break;
          case 'botox':
            await _applyForeheadEffect(anchor, effectMaterial, effectIntensity);
            break;
          case 'fillers':
            await _applyCheeksEffect(anchor, effectMaterial, effectIntensity);
            break;
          case 'lifting':
            await _applyJawlineEffect(anchor, effectMaterial, effectIntensity);
            break;
          case 'skincare':
            await _applyFaceEffect(anchor, effectMaterial, effectIntensity);
            break;
          default:
            _isEffectBeingApplied = false;
            return;
        }
        
        // Efecto aplicado con éxito - resetear contador de errores
        _consecutiveErrors = 0;
        print("✅ Efecto realista aplicado: $_selectedTreatment con intensidad $_intensity");
        
      } catch (materialError) {
        print("Error creando material: $materialError");
        _consecutiveErrors++;
        _fallbackTreatmentEffect(anchor, _selectedTreatment, _intensity);
      } finally {
        // Asegurarse de que la bandera se restablezca
        _isEffectBeingApplied = false;
      }
    });
    
    // Establecer un timeout de seguridad de 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      if (_isEffectBeingApplied) {
        print("⏱️ Timeout - Reseteando bandera de efecto");
        _isEffectBeingApplied = false;
      }
    });
    
  } catch (e) {
    print("Error general aplicando efecto realista: $e");
    _isEffectBeingApplied = false;
    _consecutiveErrors++;
    _fallbackTreatmentEffect(anchor, _selectedTreatment, _intensity);
  }
}

// Métodos específicos para cada tipo de efecto
Future<void> _applyMouthEffect(ARKitFaceAnchor anchor, ARKitMaterial material, double intensity) async {
  final completer = Completer<void>();
  
  try {
    // Limitar la cantidad de vértices para evitar problemas
    final maxVertices = 500; // Un número razonable para la mayoría de dispositivos
    
    // En lugar de usar directamente la geometría compleja
    if (_consecutiveErrors > 2) {
      // Usar una geometría simple cuando hay errores previos
      final lipNode = ARKitNode(
        name: "treatment_effect_overlay",
        geometry: ARKitBox(
          width: 0.03 * (1.0 + intensity),
          height: 0.01 * (1.0 + intensity),
          length: 0.01 * (1.0 + intensity * 3.0),
          materials: [material],
        ),
        position: vector.Vector3(0, -0.03, 0.05),
      );
      
      arkitController?.add(lipNode, parentNodeName: anchor.nodeName);
      completer.complete();
    } else {
      // Intentar usar la geometría facial completa
      try {
        final mouthGeometry = ARKitFaceMeshGeometry(
          source: ARKitFaceMeshSource.mouth,
          scaleMultiplier: vector.Vector3(1.0 + intensity, 1.0 + intensity, 1.0 + intensity * 3.0),
        );
        
        // Esperar un momento para permitir que la geometría se inicialice
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) {
          completer.complete();
          return completer.future;
        }
        
        final mouthNode = ARKitNode(
          name: "treatment_effect_overlay",
          geometry: mouthGeometry,
          position: vector.Vector3(0, 0, 0),
        );
        
        // Aplicar material al nodo de manera segura
        try {
          mouthNode.geometry?.materials.value = [material];
        } catch (materialError) {
          print("Error aplicando material al nodo: $materialError");
          // No incrementar errores aquí para evitar transición prematura a fallback
        }
        
        arkitController?.add(mouthNode, parentNodeName: anchor.nodeName);
        completer.complete();
      } catch (geometryError) {
        print("Error creando geometría para labios: $geometryError");
        _consecutiveErrors++;
        
        // Usar fallback dentro del mismo método
        final fallbackNode = ARKitNode(
          name: "treatment_effect_overlay",
          geometry: ARKitBox(
            width: 0.03,
            height: 0.01,
            length: 0.01,
            materials: [material],
          ),
          position: vector.Vector3(0, -0.03, 0.05),
        );
        
        arkitController?.add(fallbackNode, parentNodeName: anchor.nodeName);
        completer.complete();
      }
    }
  } catch (e) {
    print("Error general en applyMouthEffect: $e");
    completer.completeError(e);
  }
  
  return completer.future;
}

Future<void> _applyNoseEffect(ARKitFaceAnchor anchor, ARKitMaterial material, double intensity) async {
  try {
    // Crear un Completer para manejar la asincronía
    final completer = Completer<void>();
    
    // Geometría específica para la nariz con ajustes sutiles
    final noseGeometry = ARKitFaceMeshGeometry(
      source: ARKitFaceMeshSource.nose,
      scaleMultiplier: vector.Vector3(1.0 - intensity * 0.8, 1.0, 1.0 + intensity),
    );
    
    // Esperar un momento para dar tiempo a la geometría a inicializarse
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!mounted) {
      completer.complete();
      return completer.future;
    }
    
    final noseNode = ARKitNode(
      name: "treatment_effect_overlay",
      geometry: noseGeometry,
      position: vector.Vector3(0, 0, 0),
    );
    
    // Aplicar material al nodo
    noseNode.geometry?.materials.value = [material];
    
    // Añadir nodo a la escena
    arkitController?.add(noseNode, parentNodeName: anchor.nodeName);
    
    completer.complete();
    return completer.future;
  } catch (geometryError) {
    print("Error en geometría de nariz: $geometryError");
    _fallbackTreatmentEffect(anchor, 'nose', _intensity);
    return;
  }
}

Future<void> _applyForeheadEffect(ARKitFaceAnchor anchor, ARKitMaterial material, double intensity) async {
  // Implementación similar a los métodos anteriores para la frente
  // ...
  try {
    // Geometría para la frente
    final foreheadGeometry = ARKitFaceMeshGeometry(
      source: ARKitFaceMeshSource.forehead,
      scaleMultiplier: vector.Vector3(1.0, 1.0 + intensity * 0.5, 1.0),
    );
    
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!mounted) return;
    
    final foreheadNode = ARKitNode(
      name: "treatment_effect_overlay",
      geometry: foreheadGeometry,
      position: vector.Vector3(0, 0, 0),
    );
    
    foreheadNode.geometry?.materials.value = [material];
    arkitController?.add(foreheadNode, parentNodeName: anchor.nodeName);
    
  } catch (e) {
    print("Error en geometría de frente: $e");
    _fallbackTreatmentEffect(anchor, 'botox', _intensity);
  }
}

Future<void> _applyCheeksEffect(ARKitFaceAnchor anchor, ARKitMaterial material, double intensity) async {
  try {
    final completer = Completer<void>();
    
    // Geometría específica para las mejillas con ajustes de volumen
    final cheeksGeometry = ARKitFaceMeshGeometry(
      source: ARKitFaceMeshSource.cheeks,
      scaleMultiplier: vector.Vector3(1.0 + intensity * 0.3, 1.0 + intensity * 0.2, 1.0 + intensity * 0.5),
    );
    
    // Esperar un momento para dar tiempo a la geometría a inicializarse
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!mounted) {
      completer.complete();
      return completer.future;
    }
    
    final cheeksNode = ARKitNode(
      name: "treatment_effect_overlay",
      geometry: cheeksGeometry,
      position: vector.Vector3(0, 0, 0),
    );
    
    // Aplicar material al nodo
    cheeksNode.geometry?.materials.value = [material];
    
    // Añadir nodo a la escena
    arkitController?.add(cheeksNode, parentNodeName: anchor.nodeName);
    
    completer.complete();
    return completer.future;
  } catch (geometryError) {
    print("Error en geometría de mejillas: $geometryError");
    _fallbackTreatmentEffect(anchor, 'fillers', _intensity);
    return;
  }
}

Future<void> _applyJawlineEffect(ARKitFaceAnchor anchor, ARKitMaterial material, double intensity) async {
  try {
    final completer = Completer<void>();
    
    // Geometría específica para el contorno de la mandíbula
    final jawlineGeometry = ARKitFaceMeshGeometry(
      source: ARKitFaceMeshSource.jawline,
      // Ligero efecto de lifting - tensiona hacia arriba y atrás
      scaleMultiplier: vector.Vector3(0.98, 1.0 + intensity * 0.2, 0.99),
      // Desplazar ligeramente hacia arriba para simular lifting
      positionOffset: vector.Vector3(0, intensity * 0.004, 0),
    );
    
    // Esperar un momento para dar tiempo a la geometría a inicializarse
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!mounted) {
      completer.complete();
      return completer.future;
    }
    
    final jawlineNode = ARKitNode(
      name: "treatment_effect_overlay",
      geometry: jawlineGeometry,
      position: vector.Vector3(0, 0, 0),
    );
    
    // Aplicar material al nodo
    jawlineNode.geometry?.materials.value = [material];
    
    // Añadir nodo a la escena
    arkitController?.add(jawlineNode, parentNodeName: anchor.nodeName);
    
    completer.complete();
    return completer.future;
  } catch (geometryError) {
    print("Error en geometría de mandíbula: $geometryError");
    _fallbackTreatmentEffect(anchor, 'lifting', _intensity);
    return;
  }
}

Future<void> _applyFaceEffect(ARKitFaceAnchor anchor, ARKitMaterial material, double intensity) async {
  try {
    final completer = Completer<void>();
    
    // Para tratamientos de piel, usamos toda la geometría facial con efecto sutil
    final faceGeometry = ARKitFaceMeshGeometry(
      source: ARKitFaceMeshSource.face,
      // Efecto muy sutil - casi sin deformación
      scaleMultiplier: vector.Vector3(1.0, 1.0, 1.0 + intensity * 0.05),
    );
    
    // Esperar un momento para dar tiempo a la geometría a inicializarse
    await Future.delayed(const Duration(milliseconds: 50));
    
    if (!mounted) {
      completer.complete();
      return completer.future;
    }
    
    final faceNode = ARKitNode(
      name: "treatment_effect_overlay",
      geometry: faceGeometry,
      position: vector.Vector3(0, 0, 0),
    );
    
    // Aplicar material al nodo
    faceNode.geometry?.materials.value = [material];
    
    // Añadir nodo a la escena
    arkitController?.add(faceNode, parentNodeName: anchor.nodeName);
    
    // Para el efecto de skincare, podemos añadir un segundo nodo con glow
    if (intensity > 0.5) {
      final glowNode = ARKitNode(
        name: "skincare_glow_overlay",
        geometry: ARKitSphere(
          radius: 0.12,
          materials: [
            ARKitMaterial(
              diffuse: ARKitMaterialProperty.color(Colors.white.withOpacity(0.01)),
              transparent: ARKitMaterialProperty.color(Colors.white.withOpacity(0.03)),
              transparency: 0.97,
              emission: ARKitMaterialProperty.color(Colors.white.withOpacity(0.03 * intensity)),
              specular: ARKitMaterialProperty.color(Colors.white),
              shininess: 0.9,
              lightingModelName: ARKitLightingModel.constant,
              doubleSided: true,
            )
          ]
        ),
        position: vector.Vector3(0, 0, 0),
      );
      
      arkitController?.add(glowNode, parentNodeName: anchor.nodeName);
    }
    
    completer.complete();
    return completer.future;
  } catch (geometryError) {
    print("Error en geometría facial completa: $geometryError");
    _fallbackTreatmentEffect(anchor, 'skincare', _intensity);
    return;
  }
}


void _applySimpleFallback(ARKitFaceAnchor anchor) {
  try {
    // Eliminar nodos existentes
    arkitController?.remove("treatment_effect_overlay");
    arkitController?.remove("skincare_glow_overlay");
    
    // Crear un nodo extremadamente simple
    // Seleccionar forma diferente según tipo de tratamiento
    late ARKitGeometry geometry;
    late vector.Vector3 position;
    late Color color;
    
    switch (_selectedTreatment) {
      case 'lips':
        color = Colors.red.shade300.withOpacity(0.3);
        geometry = ARKitBox(width: 0.03, height: 0.01, length: 0.01);
        position = vector.Vector3(0, -0.03, 0.05);
        break;
      case 'nose':
        color = Colors.blue.shade200.withOpacity(0.3);
        geometry = ARKitBox(width: 0.01, height: 0.015, length: 0.015);
        position = vector.Vector3(0, -0.01, 0.08);
        break;
      case 'botox':
        color = Colors.purple.shade100.withOpacity(0.2);
        geometry = ARKitBox(width: 0.04, height: 0.02, length: 0.01);
        position = vector.Vector3(0, 0.03, 0.06);
        break;
      case 'fillers':
        color = Colors.amber.shade200.withOpacity(0.2);
        geometry = ARKitSphere(radius: 0.015);
        position = vector.Vector3(0.025, -0.02, 0.06);
        break;
      case 'lifting':
        color = Colors.teal.shade100.withOpacity(0.2);
        geometry = ARKitPlane(width: 0.03, height: 0.04);
        position = vector.Vector3(0.03, -0.03, 0.04);
        break;
      default:
        color = Colors.blue.shade100.withOpacity(0.1);
        geometry = ARKitSphere(radius: 0.01);
        position = vector.Vector3(0, 0, 0.05);
    }
    
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(color),
      transparency: 0.7,
      lightingModelName: ARKitLightingModel.constant,
    );
    
    geometry.materials.value = [material];
    
    final node = ARKitNode(
      name: "treatment_effect_overlay",
      geometry: geometry,
      position: position,
    );
    
    // Añadir a la escena
    arkitController?.add(node, parentNodeName: anchor.nodeName);
    
    print("✅ Efecto fallback aplicado: $_selectedTreatment");
    
    // Resetear contador de errores solo si el fallback funciona
    _consecutiveErrors = 0;
    
  } catch (e) {
    print("Error en fallback simple: $e");
  } finally {
    // SIEMPRE resetear la bandera al finalizar
    _isEffectBeingApplied = false;
  }
}

// Método de respaldo para cuando la geometría personalizada falla
void _fallbackTreatmentEffect(ARKitFaceAnchor anchor, String treatmentType, double intensity) {
  print("⚠️ Usando método de respaldo para tratamiento $treatmentType");
  
  // Eliminar nodos previos
  arkitController?.remove("fallback_treatment_node");
  
  // Escalar intensidad a un rango útil para las geometrías
  final scaledIntensity = 0.01 + (intensity * 0.09);
  
  // Color y materiales según tratamiento
  final color = _getMaterialColor(treatmentType);
  final opacity = _getMaterialOpacity(treatmentType, intensity);
  
  try {
    // Usar un enfoque diferente: aplicar material directamente a la geometría facial
    final effectMaterial = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(color),
      transparent: ARKitMaterialProperty.color(color.withOpacity(opacity * 0.5)),
      transparency: 1.0 - (opacity * 0.7),  // Ajustar transparencia según intensidad
      specular: ARKitMaterialProperty.color(Colors.white),
      shininess: 0.5 + (intensity * 0.4),
      lightingModelName: ARKitLightingModel.physicallyBased,
      doubleSided: true,
    );
    
    // Crear geometrías 3D adicionales para simular el efecto
    switch (treatmentType) {
      case 'lips':
        // Simular aumento de labios con esferas
      final lipUpperNode = ARKitNode(
        name: "fallback_treatment_node_up",
        geometry: ARKitSphere(radius: 0.006 + (intensity * 0.006)),
        position: vector.Vector3(0, -0.025, 0.08),
      );
      lipUpperNode.geometry?.materials.value = [effectMaterial]; 
        
      final lipLowerNode = ARKitNode(
        name: "fallback_treatment_node_low",
        geometry: ARKitSphere(radius: 0.006 + (intensity * 0.006)),
        position: vector.Vector3(0, -0.035, 0.08),
      );
      lipLowerNode.geometry?.materials.value = [effectMaterial]; 
        
        arkitController?.add(lipUpperNode, parentNodeName: anchor.nodeName);
        arkitController?.add(lipLowerNode, parentNodeName: anchor.nodeName);
        break;
        
      case 'nose':
        // Simular rinomodelación con conos
      final bridgeNode = ARKitNode(
        name: "fallback_treatment_node",
        geometry: ARKitCone(
          height: 0.02 + (intensity * 0.01),
          bottomRadius: 0.003 + (intensity * 0.002), // ✅ Usar bottomRadius en su lugar
          // También puedes definir topRadius si es necesario
          // topRadius: 0.001,
        ),
        position: vector.Vector3(0, 0, 0.07),
        eulerAngles: vector.Vector3(1.5, 0, 0),
      );
      bridgeNode.geometry?.materials.value = [effectMaterial];
        
        arkitController?.add(bridgeNode, parentNodeName: anchor.nodeName);
        break;
        
      case 'botox':
        // Simular botox con una capa suave en la frente
      final foreheadNode = ARKitNode(
        name: "fallback_treatment_node",
        geometry: ARKitPlane(
          width: 0.06 + (intensity * 0.02),
          height: 0.03 + (intensity * 0.01),
        ),
        position: vector.Vector3(0, 0.04, 0.06),
        eulerAngles: vector.Vector3(0, 0, 0),
      );
      foreheadNode.geometry?.materials.value = [effectMaterial]; 
        
        arkitController?.add(foreheadNode, parentNodeName: anchor.nodeName);
        break;
        
      case 'fillers':
        // Simular rellenos faciales con esferas en mejillas
        for (int i = -1; i <= 1; i += 2) {
          final cheekNode = ARKitNode(
            name: "fallback_treatment_node_$i",
            geometry: ARKitSphere(radius: 0.01 + (intensity * 0.01)),
            position: vector.Vector3(0.04 * i, -0.01, 0.06),
          );

          cheekNode.geometry?.materials.value = [effectMaterial];
          
          arkitController?.add(cheekNode, parentNodeName: anchor.nodeName);
        }
        break;
        
      case 'lifting':
        // Simular lifting con planos en los contornos faciales
        for (int i = -1; i <= 1; i += 2) {
          final liftNode = ARKitNode(
            name: "fallback_treatment_node_$i",
            geometry: ARKitBox(
              width: 0.003,
              height: 0.03 + (intensity * 0.02),
              length: 0.003,
              materials: [effectMaterial],
            ),
            position: vector.Vector3(0.05 * i, 0.01, 0.05),
            eulerAngles: vector.Vector3(0, 0, -0.3 * i), // Ángulo según lado
          );

          liftNode.geometry?.materials.value = [effectMaterial];    
          
          arkitController?.add(liftNode, parentNodeName: anchor.nodeName);
        }
        break;
        
      case 'skincare':
        // Simular tratamiento de piel con una capa completa sobre el rostro
        final skinNode = ARKitNode(
          name: "fallback_treatment_node",
          geometry: ARKitSphere(radius: 0.1),
          position: vector.Vector3(0, 0, 0),
        );

          skinNode.geometry?.materials.value = [
        ARKitMaterial(
          diffuse: ARKitMaterialProperty.color(Colors.white.withOpacity(0.05)),
          transparent: ARKitMaterialProperty.color(Colors.white.withOpacity(0.1)),
          transparency: 0.95 - (intensity * 0.1),
          emission: ARKitMaterialProperty.color(Colors.white.withOpacity(0.03 * intensity)),
          specular: ARKitMaterialProperty.color(Colors.white),
          shininess: 0.6 + (intensity * 0.3),
          lightingModelName: ARKitLightingModel.constant,
          doubleSided: true,
        )
      ];        
        arkitController?.add(skinNode, parentNodeName: anchor.nodeName);
        break;
    }
  } catch (e) {
    print("Error incluso en modo de respaldo: $e");
    _showSimpleOverlay("No se pudo aplicar el efecto");
  }
}

// Método auxiliar para mostrar mensajes temporales en la interfaz
void _showSimpleOverlay(String message) {
  if (!mounted) return;
  
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
  
  Overlay.of(context).insert(overlayEntry);
  
  // Eliminar después de 2 segundos
  Future.delayed(const Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}

// Métodos de soporte para obtener color y opacidad según tratamiento
Color _getMaterialColor(String treatmentType) {
  switch (treatmentType) {
    case 'lips': return Colors.red.shade300;
    case 'nose': return Colors.blue.shade100;
    case 'botox': return Colors.green.shade100;
    case 'fillers': return Colors.amber.shade100;
    case 'lifting': return Colors.purple.shade100;
    case 'skincare': return Colors.teal.shade50;
    default: return Colors.white;
  }
}

double _getMaterialOpacity(String treatmentType, double intensity) {
  // Base opacity según tratamiento
  double baseOpacity = 0.0;
  switch (treatmentType) {
    case 'lips': baseOpacity = 0.3; break;
    case 'nose': baseOpacity = 0.2; break;
    case 'botox': baseOpacity = 0.15; break;
    case 'fillers': baseOpacity = 0.25; break;
    case 'lifting': baseOpacity = 0.2; break;
    case 'skincare': baseOpacity = 0.1; break;
    default: baseOpacity = 0.2;
  }
  
  // Escalar según intensidad (0.1-1.0)
  return baseOpacity + (intensity * 0.5);
}

 void _applyTreatmentEffect(List<vector.Vector3> vertices, String treatmentType, double intensity) {
  // Multiplicar intensidad para efectos más visibles
  intensity = intensity * 5.0;
  
  // Mapeo de zonas faciales según observaciones en el modelo de ARKit
  // Estos números son aproximados y puedes ajustarlos
  final Map<String, Map<String, dynamic>> treatmentEffects = {
    'lips': {
      'centerIndex': 120, // Centro aproximado de la boca
      'radius': 15,       // Radio de afectación para labios
      'direction': vector.Vector3(0, 0, 3.0), // Proyectar hacia afuera
      'strength': 0.15,   // Factor de intensidad específico
    },
    'nose': {
      'centerIndex': 60,  // Centro aproximado de la nariz
      'radius': 12,
      'direction': vector.Vector3(0, 0, -1.5), // Reducir nariz (hacia adentro)
      'strength': 0.1,
    },
    'botox': {
      'centerIndex': 20,  // Frente
      'radius': 25,
      'direction': vector.Vector3(0, 0.5, 0), // Suavizar arrugas
      'strength': 0.05,
    },
    'fillers': {
      'centerIndex': 90,  // Mejillas
      'radius': 20,
      'direction': vector.Vector3(0.3, 0, 0.3), // Volumen en mejillas
      'strength': 0.1,
    },
    'lifting': {
      'centerIndex': 110, // Contorno facial
      'radius': 35,
      'direction': vector.Vector3(0, 0.3, 0), // Elevar
      'strength': 0.12,
    },
    'skincare': {
      'centerIndex': 0,   // Toda la cara
      'radius': 100,
      'direction': vector.Vector3(0, 0, 0.1), // Suavizar
      'strength': 0.02,
    },
  };
  
  // Obtener configuración para el tratamiento actual
  final effectConfig = treatmentEffects[treatmentType];
  if (effectConfig == null) return;
  
  final centerIndex = effectConfig['centerIndex'] as int;
  final radius = effectConfig['radius'] as double;
  final direction = effectConfig['direction'] as vector.Vector3;
  final strength = effectConfig['strength'] as double;
  
  // Verificar que el centro esté dentro de los límites
  if (centerIndex >= vertices.length) {
    print("Índice central fuera de rango: $centerIndex de ${vertices.length}");
    return;
  }
  
  // Punto central para aplicar el efecto
  final centerPoint = vertices[centerIndex];
  int modifiedCount = 0;
  
  // Aplicar efecto a los vértices dentro del radio
  for (int i = 0; i < vertices.length; i++) {
    final vertex = vertices[i];
    final distance = (vertex - centerPoint).length;
    
    // Si el vértice está dentro del radio de afectación
    if (distance <= radius) {
      // Factor de atenuación basado en la distancia (más efecto en el centro)
      final falloff = 1.0 - (distance / radius);
      
      // Aplicar desplazamiento con atenuación
      final displacement = direction * (intensity * strength * falloff);
      vertices[i] = vertex + displacement;
      modifiedCount++;
    }
  }
  
  print("Tratamiento $treatmentType: $modifiedCount vértices modificados con intensidad $intensity");
} 

  Future<void> _capturePhoto() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      // Cambiar toImage() por snapshot()
      final imageProvider = await arkitController?.snapshot();
      
      if (imageProvider != null) {
        // Convertir ImageProvider a bytes
        final completer = Completer<Uint8List>();
        final ImageStream stream = imageProvider.resolve(const ImageConfiguration());
        
        final listener = ImageStreamListener((ImageInfo info, bool _) async {
          final ByteData? byteData = await info.image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final bytes = byteData.buffer.asUint8List();
            completer.complete(bytes);
          } else {
            completer.completeError('No se pudo convertir la imagen');
          }
        }, onError: completer.completeError);
        
        stream.addListener(listener);
        
        // Esperar por los bytes de la imagen
        final bytes = await completer.future;
        
        // Guardar bytes en archivo
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/ar_treatment_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(bytes);
        
        setState(() {
          _resultImage = imageFile;
          _isCapturing = false;
        });
        
        // Feedback visual de captura (flash)
        _showCaptureFlash();
        
      } else {
        setState(() {
          _isCapturing = false;
        });
        _showError('No se pudo capturar la imagen');
      }
    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      _showError('Error: $e');
    }
  }


  void _hideControlsAfterDelay() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isRecording) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_isRecording) {
      setState(() {
        _showControls = !_showControls;
      });
      
      if (_showControls) {
        _hideControlsAfterDelay();
      }
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoPath == null) return;
    
    _videoController = VideoPlayerController.file(File(_videoPath!));
    
    await _videoController!.initialize();
    
    setState(() {
      _isVideoPlayerInitialized = true;
    });
  }

  Future<void> _saveToGallery() async {
    try {
      if (_resultImage != null) {
        await ImageGallerySaver.saveFile(_resultImage!.path);
        _showMessage('Imagen guardada en la galería');
      } else if (_videoPath != null) {
        await ImageGallerySaver.saveFile(_videoPath!);
        _showMessage('Video guardado en la galería');
      }
    } catch (e) {
      _showError('Error al guardar: $e');
    }
  }

  Future<void> _shareMedia() async {
    try {
      if (_resultImage != null) {
        await Share.share(
          'Mi simulación de tratamiento estético',
          subject: 'Simulación AR',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 10),
        );
      } else if (_videoPath != null) {
              await Share.share(
          'Mi simulación de tratamiento estético',
          subject: 'Simulación AR',
          sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 10),
        );
      }
    } catch (e) {
      _showError('Error al compartir: $e');
    }
  }

void _showCaptureFlash() {
  // Crear una versión simplificada del flash
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: Container(
        color: Colors.white.withOpacity(0.3),
      ),
    ),
  );
  
  // Insertar y eliminar después de un breve momento
  Overlay.of(context).insert(overlayEntry);
  
  // Eliminarlo después de 100ms
  Future.delayed(const Duration(milliseconds: 100), () {
    overlayEntry.remove();
  });
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
      )
    );
  }

  void _resetMedia() {
    setState(() {
      _resultImage = null;
      _videoPath = null;
      _videoController?.dispose();
      _videoController = null;
      _isVideoPlayerInitialized = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Verificar compatibilidad con iOS
    if (!Platform.isIOS) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Simulador AR'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 64, color: Colors.orange),
              SizedBox(height: 24),
              Text(
                'El simulador en tiempo real requiere un dispositivo iOS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    // Si hay una imagen o video capturado, mostrar la pantalla de resultados
    if (_resultImage != null || (_videoPath != null && _isVideoPlayerInitialized)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Resultado'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _resetMedia,
              tooltip: 'Volver al simulador',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: _resultImage != null
                    ? Image.file(_resultImage!)
                    : AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botones de control para video
                    if (_videoController != null) ...[
                      IconButton(
                        icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                      ),
                    ],
                    
                    // Botones para guardar
                    IconButton(
                      icon: const Icon(Icons.save_alt),
                      onPressed: _saveToGallery,
                      tooltip: 'Guardar en galería',
                    ),
                    
                    // Botones para compartir
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: _shareMedia,
                      tooltip: 'Compartir',
                    ),
                    
                    // Botón para volver al simulador
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _resetMedia,
                      tooltip: 'Volver al simulador',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Pantalla principal del simulador AR
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isRecording && !_showControls
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                _treatmentTranslations[_selectedTreatment] ?? 'Simulador AR',
                style: const TextStyle(color: Colors.white, shadows: [
                  Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))
                ]),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Vista AR de pantalla completa
            ARKitSceneView(
              enableTapRecognizer: true,
              showFeaturePoints: false,
              showStatistics: false,
              onARKitViewCreated: _onARKitViewCreated,
              configuration: ARKitConfiguration.faceTracking, // Añadir esta línea
            ),
            
            // Indicador de grabación
            if (_isRecording)
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            // Controles de tratamiento e intensidad
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Slider de intensidad
                        Row(
                          children: [
                            const Icon(Icons.tune, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Slider(
                                value: _intensity,
                                min: 0.1,
                                max: 1.0,
                                divisions: 9,
                                activeColor: Colors.white,
                                inactiveColor: Colors.white30,
                                onChanged: (value) {
                                  setState(() {
                                    _intensity = value;
                                    // Si hay un rostro detectado, actualiza el efecto
                                    if (faceAnchor != null) {
                                      _updateFaceMesh(faceAnchor!);
                                    }
                                  });
                                },
                              ),
                            ),
                            Text(
                              '${(_intensity * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        
                        // Selector de tratamiento
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _treatmentTranslations.entries.map((entry) {
                              final isSelected = _selectedTreatment == entry.key;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedTreatment = entry.key;
                                      // Si hay un rostro detectado, actualiza el efecto
                                      if (faceAnchor != null) {
                                        _updateFaceMesh(faceAnchor!);
                                      }
                                    });
                                  },
                                  backgroundColor: Colors.black26,
                                  selectedColor: Theme.of(context).colorScheme.primary,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Botones de captura y grabación
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Botón de volver
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              color: Colors.white,
                              onPressed: () => Navigator.pop(context),
                            ),
                            
                            // Botón para tomar foto
                            GestureDetector(
                              onTap: _isCapturing ? null : _capturePhoto,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: _isCapturing
                                    ? const CircularProgressIndicator()
                                    : const Icon(Icons.camera_alt, size: 32),
                              ),
                            ),
                            
                            // Botón para grabar video
                            GestureDetector(
                              child: Container(
                                width: _isRecording ? 50 : 40,
                                height: _isRecording ? 50 : 40,
                                decoration: BoxDecoration(
                                  color: _isRecording ? Colors.red : Colors.transparent,
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 3,
                                  ),
                                  shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                                  borderRadius: _isRecording ? BorderRadius.circular(12) : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}