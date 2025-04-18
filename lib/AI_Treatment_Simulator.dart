import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as image;
import 'services/replicate_service.dart';
import 'package:flutter/services.dart';



class AITreatmentSimulator extends StatefulWidget {
  const AITreatmentSimulator({Key? key}) : super(key: key);

  @override
  State<AITreatmentSimulator> createState() => _AITreatmentSimulatorState();
}

class _AITreatmentSimulatorState extends State<AITreatmentSimulator> {
  final ImagePicker _picker = ImagePicker();
  bool _showARView = false; 
  static const platform = MethodChannel('com.yourapp.arkit/face_points');

void _toggleARView() {
  setState(() {
    _showARView = !_showARView;
  });
  // Si necesitas inicializar o detener ARKit, usa el método channel
  if (_showARView) {
    platform.invokeMethod('startARSession');
  } else {
    platform.invokeMethod('stopARSession');
  }
}

  // Estado de la imagen
  File? _selectedImage;
  File? _processedImage;
  bool _showSideBySide = false;
  bool _isProcessing = false;
  String _errorMessage = '';
  
  // Opciones de tratamiento
  String _selectedTreatment = 'lips';
  double _intensity = 0.5;
  
  // Mapeo de tratamientos disponibles
  final Map<String, String> _treatmentOptions = {
    'lips': 'Aumento de labios',
    'nose': 'Rinomodelación',
    'botox': 'Botox',
    'fillers': 'Rellenos faciales',
    'face_shape': 'Modelado Facial',
    'eye_enhance': 'Realce de Ojos',
    'skin_retouch': 'Retoque de Piel',
    'jawline': 'Definición Mandibular',
    'cheeks': 'Aumento de Pómulos',
    'double_chin': 'Reducción de Papada',
  };

  // Función consolidada para crear máscara facial
  Future<File?> _createFaceMask(File imageFile, String featureType) async {
    try {
      // En iOS, usar MethodChannel para obtener la máscara desde ARKit
      if (Platform.isIOS) {
        try {
          final base64Mask = await platform.invokeMethod<String>('getFaceMask', featureType);
          if (base64Mask != null && base64Mask.isNotEmpty) {
            // Convertir base64 a archivo
            final tempDir = await getTemporaryDirectory();
            final maskFile = File('${tempDir.path}/arkit_mask_${DateTime.now().millisecondsSinceEpoch}.png');
            await maskFile.writeAsBytes(base64Decode(base64Mask));
            return maskFile;
          }
        } catch (e) {
          debugPrint('Error con ARKit: $e, usando generación por ML Kit');
        }
      }
      
      // Usar ML Kit como método principal o respaldo
      final inputImage = InputImage.fromFile(imageFile);
      final options = FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableContours: true,
        enableLandmarks: true,
      );
      final faceDetector = FaceDetector(options: options);
      
      try {
        final faces = await faceDetector.processImage(inputImage);
        if (faces.isEmpty) {
          debugPrint('No se detectó ningún rostro, usando máscara genérica');
          return _createGenericMask(imageFile, featureType);
        }
        
        // Tomar el primer rostro detectado
        final face = faces.first;
        
        // Crear máscara
        final bytes = await imageFile.readAsBytes();
        final originalImage = image.decodeImage(bytes);
        
        if (originalImage == null) {
          throw Exception('No se pudo decodificar la imagen original');
        }
        
        // Crear imagen para máscara
        final mask = image.Image(width: originalImage.width, height: originalImage.height);
        image.fill(mask, color: image.ColorRgba8(0, 0, 0, 255));
        
        // Rellenar el área específica
        _fillFeatureArea(mask, face, featureType);
        
        // Guardar máscara
        final tempDir = await getTemporaryDirectory();
        final maskFile = File('${tempDir.path}/mask_${DateTime.now().millisecondsSinceEpoch}.png');
        await maskFile.writeAsBytes(image.encodePng(mask));
        
        return maskFile;
      } finally {
        faceDetector.close();
      }
    } catch (e) {
      debugPrint('Error creando máscara: $e, usando máscara genérica');
      return _createGenericMask(imageFile, featureType);
    }
  }

  // Método simplificado para crear una máscara genérica
  Future<File> _createGenericMask(File imageFile, String featureType) async {
    final bytes = await imageFile.readAsBytes();
    final originalImage = image.decodeImage(bytes);
    
    if (originalImage == null) {
      throw Exception('No se pudo decodificar la imagen original');
    }
    
    final mask = image.Image(width: originalImage.width, height: originalImage.height);
    image.fill(mask, color: image.ColorRgba8(0, 0, 0, 255));
    
    // Área central para el tratamiento
    final centerX = originalImage.width ~/ 2;
    final centerY = originalImage.height ~/ 2;
    int width, height, left, top;
    
    switch (featureType) {
      case 'lips':
        width = originalImage.width ~/ 4;
        height = originalImage.height ~/ 10;
        left = centerX - (width ~/ 2);
        top = centerY + (originalImage.height ~/ 10);
        break;
      case 'nose':
        width = originalImage.width ~/ 6;
        height = originalImage.height ~/ 5;
        left = centerX - (width ~/ 2);
        top = centerY - (height ~/ 2);
        break;
      default:
        width = originalImage.width ~/ 3;
        height = originalImage.height ~/ 3;
        left = centerX - (width ~/ 2);
        top = centerY - (height ~/ 2);
    }
    
    // Dibujar área blanca
    for (int y = top; y < top + height; y++) {
      for (int x = left; x < left + width; x++) {
        if (x >= 0 && x < mask.width && y >= 0 && y < mask.height) {
          mask.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
    
    // Guardar máscara
    final tempDir = await getTemporaryDirectory();
    final maskFile = File('${tempDir.path}/generic_mask_${DateTime.now().millisecondsSinceEpoch}.png');
    await maskFile.writeAsBytes(image.encodePng(mask));
    
    return maskFile;
  }
  
  // Rellena el área específica del rostro en la máscara
  void _fillFeatureArea(image.Image mask, Face face, String featureType, {int offsetX = 0, int offsetY = 0}) {
    
    // Valor entero del color blanco (0xFFFFFF o 16777215)
    final whiteValue = 0xFFFFFF;
    
    switch (featureType) {
    case 'lips':
      // Usar los puntos del contorno de labios
      final upperLipBottom = face.contours[FaceContourType.upperLipBottom]?.points;
      final lowerLipTop = face.contours[FaceContourType.lowerLipTop]?.points;
      final upperLipTop = face.contours[FaceContourType.upperLipTop]?.points;
      final lowerLipBottom = face.contours[FaceContourType.lowerLipBottom]?.points;
      
      print('Debug: Puntos de labio superior: ${upperLipTop?.length ?? 0}');
      print('Debug: Puntos de labio inferior: ${lowerLipBottom?.length ?? 0}');
      
      if (upperLipBottom != null && lowerLipTop != null && 
          upperLipTop != null && lowerLipBottom != null &&
          upperLipTop.isNotEmpty && lowerLipBottom.isNotEmpty) {
        // Crear polígono para los labios
        _fillPolygon(mask, [...upperLipTop, ...upperLipBottom, ...lowerLipTop, ...lowerLipBottom], whiteValue);
      } else {
      // RESPALDO: Crear un área rectangular simple para los labios
      final faceBox = face.boundingBox;
      final centerX = faceBox.left + faceBox.width / 2;
      final lipY = faceBox.top + faceBox.height * 0.75; 
      
      final lipWidth = faceBox.width * 0.4;
      final lipHeight = faceBox.height * 0.1;
      
      print('Debug: Usando método de respaldo para labios');
      print('Debug: FaceBox: left=${faceBox.left}, top=${faceBox.top}, width=${faceBox.width}, height=${faceBox.height}');
      print('Debug: Offset: X=$offsetX, Y=$offsetY');
      
      // Asegurar que las coordenadas estén dentro de la imagen
      final left = max(0, min((centerX - lipWidth/2 + offsetX).toInt(), mask.width - 1));
      final right = max(0, min((centerX + lipWidth/2 + offsetX).toInt(), mask.width - 1));
      final top = max(0, min((lipY - lipHeight/2 + offsetY).toInt(), mask.height - 1));
      final bottom = max(0, min((lipY + lipHeight/2 + offsetY).toInt(), mask.height - 1));
      
      print('Debug: Rectángulo: left=$left, right=$right, top=$top, bottom=$bottom');
      
      // Crear un rectángulo más grande para asegurar visibilidad
      for (int y = top; y <= bottom; y++) {
        for (int x = left; x <= right; x++) {
          mask.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
      
      // Verificar después de rellenar
      int pixelsDrawn = 0;
      for (int y = top; y <= bottom; y++) {
        for (int x = left; x <= right; x++) {
          if (mask.getPixel(x, y) == 0xFFFFFFFF) {
            pixelsDrawn++;
          }
        }
      }
      print('Debug: Pixels dibujados en área de respaldo: $pixelsDrawn');
    }
      break;
        
      case 'nose':
        // Usar puntos de la nariz
        final noseBridge = face.contours[FaceContourType.noseBridge]?.points;
        final noseBottom = face.contours[FaceContourType.noseBottom]?.points;
        
        if (noseBridge != null && noseBottom != null) {
          // Expandir ligeramente el área para cubrir toda la nariz
          final expandedPoints = [...noseBridge, ...noseBottom];
          _expandPolygonArea(expandedPoints, 5); // Expandir 5px
          _fillPolygon(mask, expandedPoints, whiteValue); // Cambiado white → whiteValue
        }
        break;
        
      case 'botox':
        // Áreas típicas de botox: frente y patas de gallo
        final faceContour = face.contours[FaceContourType.face]?.points;
        if (faceContour != null) {
          // Calcular zona de la frente (tercio superior del rostro)
          final topY = faceContour.map((p) => p.y).reduce(min);
          final bottomY = face.landmarks[FaceLandmarkType.leftEye]?.position.y ?? 
                        (face.boundingBox.top + face.boundingBox.height * 0.4);
          
          // Rellenar área de la frente
          for (int y = topY.toInt(); y < bottomY.toInt(); y++) {
            for (int x = face.boundingBox.left.toInt(); x < face.boundingBox.right.toInt(); x++) {
              if (_isPointInFace(x, y, faceContour)) {
                mask.setPixelRgba(x, y, 255, 255, 255, 255);
              }
            }
          }
        }
        break;
        
      case 'jawline':
        final jawline = face.contours[FaceContourType.face]?.points;
        if (jawline != null) {
          // Tomar solo los puntos inferiores del contorno facial (mandíbula)
          final jawPoints = jawline.where((p) => 
            p.y > (face.boundingBox.top + face.boundingBox.height * 0.6)).toList();
          
          // Expandir y rellenar
          _expandPolygonArea(jawPoints, 10);
          _fillPolygon(mask, jawPoints, whiteValue); // Cambiado white → whiteValue
        }
        break;
        
      case 'cheeks':
        // Pómulos - basados en los ojos y la nariz
        final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
        final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
        final leftCheek = face.landmarks[FaceLandmarkType.leftCheek]?.position;
        final rightCheek = face.landmarks[FaceLandmarkType.rightCheek]?.position;
        
        if (leftEye != null && rightEye != null && leftCheek != null && rightCheek != null) {
          // Área de pómulo izquierdo
          _fillCircleArea(mask, leftCheek.x.toInt(), leftCheek.y.toInt(), 30, whiteValue); // Cambiado white → whiteValue
          
          // Área de pómulo derecho
          _fillCircleArea(mask, rightCheek.x.toInt(), rightCheek.y.toInt(), 30, whiteValue); // Cambiado white → whiteValue
        }
        break;
        
      default:
        // Para otros tratamientos, crear una máscara más genérica
        final faceContour = face.contours[FaceContourType.face]?.points;
        if (faceContour != null) {
          _fillPolygon(mask, faceContour, whiteValue); // Cambiado white → whiteValue
        }
    }
  }
  
  // Métodos auxiliares para manipulación de la máscara
  
  // Verifica si un punto está dentro del polígono facial
  bool _isPointInFace(int x, int y, List<Point<int>> facePoints) {
    bool inside = false;
    int j = facePoints.length - 1;
    
    for (int i = 0; i < facePoints.length; i++) {
      if (((facePoints[i].y > y) != (facePoints[j].y > y)) &&
          (x < facePoints[i].x + (facePoints[j].x - facePoints[i].x) * (y - facePoints[i].y) / 
          (facePoints[j].y - facePoints[i].y))) {
        inside = !inside;
      }
      j = i;
    }
    
    return inside;
  }
  
  // Rellena un polígono en la imagen
  void _fillPolygon(image.Image img, List<Point<int>> points, int color) {
    // Encontrar límites del polígono
    int minX = points.map((p) => p.x).reduce(min).toInt();
    int maxX = points.map((p) => p.x).reduce(max).toInt();
    int minY = points.map((p) => p.y).reduce(min).toInt();
    int maxY = points.map((p) => p.y).reduce(max).toInt();
    
    // Asegurar que los límites están dentro de la imagen
    minX = max(0, minX);
    minY = max(0, minY);
    maxX = min(img.width - 1, maxX);
    maxY = min(img.height - 1, maxY);
    
    // Rellenar el polígono
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (_isPointInFace(x, y, points)) {
          // Usar blanco OPACO para áreas a modificar
          img.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
  }
  
  // Rellena un área circular
  void _fillCircleArea(image.Image img, int centerX, int centerY, int radius, int color) {
    for (int y = centerY - radius; y <= centerY + radius; y++) {
      if (y < 0 || y >= img.height) continue;
      
      for (int x = centerX - radius; x <= centerX + radius; x++) {
        if (x < 0 || x >= img.width) continue;
        
        if (sqrt(pow(x - centerX, 2) + pow(y - centerY, 2)) <= radius) {
          // Reemplazar setPixel por setPixelRgba
          img.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }
  }
  
  // Expande los puntos de un polígono
  void _expandPolygonArea(List<Point<int>> points, int expansion) {
    // Calcular el centroide del polígono
    double centerX = points.map((p) => p.x).reduce((a, b) => a + b) / points.length;
    double centerY = points.map((p) => p.y).reduce((a, b) => a + b) / points.length;
    
    // Expandir puntos desde el centro
    for (int i = 0; i < points.length; i++) {
      final dirX = points[i].x - centerX;
      final dirY = points[i].y - centerY;
      final len = sqrt(dirX * dirX + dirY * dirY);
      
      if (len > 0) {
        points[i] = Point(
          (points[i].x + dirX / len * expansion).toInt(),
          (points[i].y + dirY / len * expansion).toInt()
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024, // Limitar tamaño para optimizar envío a API
        maxHeight: 1024,
        imageQuality: 95,
      );
      
      if (pickedFile == null) {
        return;
      }
      
      setState(() {
        _selectedImage = File(pickedFile.path);
        _processedImage = null;
        _showSideBySide = false;
      });
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
    }
  }
  
  Future<void> _applyTreatment() async {
    if (_selectedImage == null) {
      _showError('Selecciona una imagen primero');
      return;
    }

    final replicateApiKey = dotenv.env['REPLICATE_API_KEY'];
    if (replicateApiKey == null || replicateApiKey.isEmpty) {
      _showError('API key de Replicate no configurada');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      // Generar máscara usando la función consolidada
      final maskFile = await _createFaceMask(_selectedImage!, _selectedTreatment);
      if (maskFile == null) {
        _showError('No se pudo generar la máscara');
        return;
      }
      
      final maskBytes = await maskFile.readAsBytes();
      final base64Mask = base64Encode(maskBytes);

      // Leer imagen como base64
      final imageBytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Envía la imagen y la máscara a Replicate (ControlNet)
      final outputUrl = await ReplicateService.sendToControlNet(
        apiKey: replicateApiKey,
        base64Image: base64Image,
        base64Mask: base64Mask,
        prompt: _createPromptForTreatment(
          treatmentType: _selectedTreatment,
          intensity: _intensity,
        ),
        versionId: '90a4a3604cd637cb9f1a2bdae1cfa9ed869362ca028814cdce310a78e27daade',
        guidance: 7.5,
        numInferenceSteps: 30,
        controlMode: 0,
        controlType: 'scribble',
      );

      if (outputUrl != null) {
        // Descargar la imagen resultante
        final service = ReplicateService(apiKey: replicateApiKey);
        final bytes = await service.downloadImage(outputUrl);
        
        // Guardar en un archivo temporal
        final tempDir = await getTemporaryDirectory();
        final processedFile = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.png');
        await processedFile.writeAsBytes(bytes);

        setState(() {
          _processedImage = processedFile;
          _showSideBySide = true;
        });
      } else {
        _showError('No se pudo procesar la imagen');
      }
    } catch (e) {
      _showError('Error al aplicar tratamiento: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
    
  String _createPromptForTreatment({
    required String treatmentType,
    required double intensity,
  }) {
    // Determinar nivel de intensidad en texto
    final intensityText = intensity <= 0.3 ? 'subtle' : 
                        intensity <= 0.7 ? 'moderate' : 'pronounced';
    
    // Prompts específicos OPTIMIZADOS para ControlNet (más restrictivos)
    final Map<String, String> treatmentPrompts = {
      'lips': 'same exact person with $intensityText fuller lips, do not change anything else',
      'nose': 'same exact person with $intensityText refined nose shape, do not change anything else',
      'botox': 'same exact person with $intensityText smoother skin around wrinkles, do not change anything else',
      'fillers': 'same exact person with $intensityText added volume to face, do not change anything else',
      'jawline': 'same exact person with $intensityText defined jawline, do not change anything else',
      'cheeks': 'same exact person with $intensityText enhanced cheekbones, do not change anything else',
    };
    
    // Base del prompt (mucho más restrictiva)
    String basePrompt = treatmentPrompts[treatmentType] ?? 
        'same exact person with $intensityText enhancement, do not change anything else';
    
    // Añadir instrucciones restrictivas
    return '''$basePrompt, preserve exact identity, same lighting, same background, same pose, same hair, photorealistic, high detail, preserve all facial features except the modified area, clinical aesthetic treatment''';
  }
  
  Future<void> _saveToGallery() async {
    if (_processedImage == null) {
      _showError('No hay imagen para guardar');
      return;
    }
    
    try {
      await ImageGallerySaver.saveFile(_processedImage!.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen guardada en la galería'))
      );
    } catch (e) {
      _showError('Error al guardar en galería: $e');
    }
  }
  
  Future<void> _shareImage() async {
    if (_processedImage == null) {
      _showError('No hay imagen para compartir');
      return;
    }
    
    try {
      await Share.shareXFiles(
        [XFile(_processedImage!.path)],
        text: 'Mi simulación de ${_treatmentOptions[_selectedTreatment]}',
      );
    } catch (e) {
      _showError('Error al compartir: $e');
    }
  }
  
  void _resetImage() {
    setState(() {
      _processedImage = null;
      _showSideBySide = false;
    });
  }
  
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador con IA Avanzada'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Sección de selección de tratamiento
          _buildTreatmentSelector(),
          
          // Sección principal - imagen o carga
          Expanded(
            child: _buildImageSection(),
          ),
          
          // Sección de controles
          _buildControlsSection(),
        ],
      ),
    );
  }

  Widget _buildTreatmentSelector() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Selector de categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryButton('Tratamientos Faciales', 
                  ['lips', 'nose', 'botox', 'fillers', 'face_shape']),
                const SizedBox(width: 8),
                _buildCategoryButton('Mejoras Estéticas',
                  ['eye_enhance', 'skin_retouch', 'jawline', 'cheeks', 'double_chin']),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Dropdown de tratamientos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              dropdownColor: Colors.grey[900],
              decoration: const InputDecoration(
                labelText: 'Tipo de tratamiento',
                labelStyle: TextStyle(color: Colors.white),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              value: _selectedTreatment,
              items: _treatmentOptions.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedTreatment = value;
                    _processedImage = null;
                    _showSideBySide = false;
                  });
                }
              },
            ),
          ),
          
          // Slider de intensidad
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Text('Intensidad:', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _intensity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: (_intensity * 100).toInt().toString() + '%',
                    onChanged: (value) {
                      setState(() {
                        _intensity = value;
                      });
                    },
                  ),
                ),
                Text('${(_intensity * 100).toInt()}%', 
                     style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageSection() {
    if (_isProcessing) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Procesando con IA avanzada...', 
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              Text('Esto puede tardar hasta 20 segundos', 
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _errorMessage,
            style: TextStyle(color: Colors.red[300]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    if (_selectedImage == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_a_photo,
                size: 80,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto'),
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Abrir galería'),
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_showSideBySide && _processedImage != null) {
      // Mostrar comparación lado a lado
      return _buildSideBySideView();
    }
    
    // Mostrar solo la imagen seleccionada
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
  
  Widget _buildSideBySideView() {
    return Row(
      children: [
        // Imagen original
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _selectedImage!,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: const Text(
                      'Original',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Divisor
        Container(width: 2, color: Colors.white),
        
        // Imagen procesada
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _processedImage!,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(
                      _treatmentOptions[_selectedTreatment] ?? 'Procesada',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Añadir indicador de intensidad
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(
                      'Intensidad: ${(_intensity * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                // Indicador de IA
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: Colors.purple), // Cambiar color a púrpura para SD
                        SizedBox(width: 4),
                        Text(
                          'Stable Diffusion', // Cambiar el texto de GPT-4 a Stable Diffusion
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String title, List<String> treatments) {
    final bool isSelected = treatments.contains(_selectedTreatment);
    
    return OutlinedButton(
      onPressed: () {
        // Mostrar bottom sheet con opciones de tratamiento
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.grey[900],
          builder: (context) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: treatments.length,
                      itemBuilder: (context, index) {
                        final treatment = treatments[index];
                        return ListTile(
                          title: Text(
                            _treatmentOptions[treatment] ?? treatment,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: treatment == _selectedTreatment
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                          onTap: () {
                            setState(() {
                              _selectedTreatment = treatment;
                              _processedImage = null;
                              _showSideBySide = false;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildControlsSection() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mostrar resultados o botón para aplicar
          if (_processedImage != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón de guardar
                IconButton(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  tooltip: 'Guardar en galería',
                ),

                // Añade este botón de AR solo en iOS
                if (Platform.isIOS)
                IconButton(
                  onPressed: _toggleARView,
                  icon: Icon(
                    Icons.face_retouching_natural,
                    color: _showARView ? Colors.blue : Colors.white,
                  ),
                  tooltip: 'Probar con AR',
                ),
                
                // Botón de compartir
                IconButton(
                  onPressed: _shareImage,
                  icon: const Icon(Icons.share, color: Colors.white),
                  tooltip: 'Compartir imagen',
                ),
                
                // Botón de reiniciar
                IconButton(
                  onPressed: _resetImage,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Reiniciar',
                ),
                
                // Botón para cambiar imagen
                IconButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  tooltip: 'Cambiar imagen',
                ),
              ],
            )
          else
            Column(
              children: [
                // Botón para aplicar el tratamiento
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text('Simular ${_treatmentOptions[_selectedTreatment] ?? "tratamiento"}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isProcessing ? null : _applyTreatment,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botón para cambiar imagen
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library, color: Colors.white70),
                      label: const Text('Otra imagen', style: TextStyle(color: Colors.white70)),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    // Botón para tomar otra foto
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt, color: Colors.white70),
                      label: const Text('Otra foto', style: TextStyle(color: Colors.white70)),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}