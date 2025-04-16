import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as image;
import 'package:http_parser/http_parser.dart';

class TreatmentResult {
  final File processedImage;
  final Map<String, dynamic>? metadata;

  TreatmentResult({
    required this.processedImage,
    this.metadata,
  });
}

class AITreatmentSimulator extends StatefulWidget {
  const AITreatmentSimulator({Key? key}) : super(key: key);

  @override
  State<AITreatmentSimulator> createState() => _AITreatmentSimulatorState();
}

class _AITreatmentSimulatorState extends State<AITreatmentSimulator> {
  final ImagePicker _picker = ImagePicker();
  String? _openaiApiKey;

  @override
  void initState() {
    super.initState();
    
    // Obtener API key de OpenAI del archivo .env
    _openaiApiKey = dotenv.env['OPENAI_API_KEY'];
    
    if (_openaiApiKey == null || _openaiApiKey!.isEmpty) {
      debugPrint('⚠️ ADVERTENCIA: No se encontró API key para OpenAI');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OpenAI API no configurada - la simulación no funcionará'),
            backgroundColor: Colors.red,
          ),
        );
      });
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

    // Función para detectar rostros y crear máscaras
  Future<File?> _createFaceMask(File imageFile, String featureType) async {
    // Declarar faceDetector fuera del bloque try
    FaceDetector? faceDetector;
    
    try {
      // Cargar imagen
      final inputImage = InputImage.fromFilePath(imageFile.path);
      
      // Inicializar detector facial
      final options = FaceDetectorOptions(
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      );
      faceDetector = FaceDetector(options: options);
      
      // Detectar rostros
      final faces = await faceDetector.processImage(inputImage);
      
      // Si no hay rostros, retornar null
      if (faces.isEmpty) {
        debugPrint('No se detectaron rostros en la imagen');
        return null;
      }
      
      // Usar el primer rostro detectado (principal)
      final face = faces.first;
      
      // Cargar la imagen original para sus dimensiones
      final originalImage = await decodeImageFromList(await imageFile.readAsBytes());
      
      // Crear una imagen en blanco (negro) como base para la máscara
      final mask = image.Image(width: originalImage.width, height: originalImage.height);
      
      // Rellenar puntos específicos según el tipo de característica
      _fillFeatureArea(mask, face, featureType);
      
      // Guardar la máscara como archivo
      final tempDir = await getTemporaryDirectory();
      final maskFile = File('${tempDir.path}/mask_${DateTime.now().millisecondsSinceEpoch}.png');
      await maskFile.writeAsBytes(image.encodePng(mask));
      
      return maskFile;
    } catch (e) {
      debugPrint('Error al crear máscara facial: $e');
      return null;
    } finally {
      // Verificar que faceDetector no sea nulo antes de cerrarlo
      if (faceDetector != null) {
        await faceDetector.close();
      }
    }
  }
  
  // Rellena el área específica del rostro en la máscara
  void _fillFeatureArea(image.Image mask, Face face, String featureType) {
    // Color blanco para las áreas a modificar
    final white = image.ColorRgb8(255, 255, 255);
    // Valor entero del color blanco (0xFFFFFF o 16777215)
    final whiteValue = 0xFFFFFF;
    
    switch (featureType) {
      case 'lips':
        // Usar los puntos del contorno de labios
        final upperLipBottom = face.contours[FaceContourType.upperLipBottom]?.points;
        final lowerLipTop = face.contours[FaceContourType.lowerLipTop]?.points;
        final upperLipTop = face.contours[FaceContourType.upperLipTop]?.points;
        final lowerLipBottom = face.contours[FaceContourType.lowerLipBottom]?.points;
        
        if (upperLipBottom != null && lowerLipTop != null && 
            upperLipTop != null && lowerLipBottom != null) {
          // Crear polígono para los labios
          _fillPolygon(mask, [...upperLipTop, ...upperLipBottom, ...lowerLipTop, ...lowerLipBottom], whiteValue);
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
          // Reemplazar setPixel por setPixelRgba
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
    
    if (_openaiApiKey == null || _openaiApiKey!.isEmpty) {
      _showError('API key de OpenAI no configurada');
      return;
    }
    
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = '';
      });
      
      final result = await _applyTreatmentWithGPT4(
        image: _selectedImage!,
        treatmentType: _selectedTreatment,
        intensity: _intensity,
      );
      
      if (result != null) {
        setState(() {
          _processedImage = result.processedImage;
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
  
  Future<TreatmentResult?> _applyTreatmentWithGPT4({
    required File image,
    required String treatmentType,
    required double intensity,
  }) async {
    try {
      // Generar máscara para el área facial específica
      final maskFile = await _createFaceMask(image, treatmentType);
      
      if (maskFile == null) {
        _showError('No se pudo detectar el rostro correctamente');
        return null;
      }
      
      // Crear prompt basado en el tipo de tratamiento y parámetros
      final prompt = _createPromptForTreatment(
        treatmentType: treatmentType, 
        intensity: intensity,
      );
      
      debugPrint('Enviando imagen a OpenAI para edición: $treatmentType');
      
      // Preparar request para la API de edición de OpenAI
      final request = http.MultipartRequest('POST', 
        Uri.parse('https://api.openai.com/v1/images/edits'));
      
      // Autenticación
      request.headers['Authorization'] = 'Bearer $_openaiApiKey';
      
      // Añadir campos requeridos
      request.fields['prompt'] = prompt;
      request.fields['n'] = '1';
      request.fields['size'] = '1024x1024';
      request.fields['response_format'] = 'b64_json';
      
      // Añadir imagen original (debe ser PNG)
      final pngImage = await _convertToTransparentPng(image);
      request.files.add(await http.MultipartFile.fromPath(
        'image', pngImage.path, contentType: MediaType('image', 'png')));
      
      // Añadir máscara
      request.files.add(await http.MultipartFile.fromPath(
        'mask', maskFile.path, contentType: MediaType('image', 'png')));
      
      // Enviar solicitud
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Extraer la imagen en base64 de la respuesta
        final String? imageData = data['data']?[0]?['b64_json'];
        
        if (imageData == null) {
          debugPrint('Error: No se encontró imagen en la respuesta');
          return null;
        }
        
        // Guardar imagen generada en archivo temporal
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(base64Decode(imageData));
        
        return TreatmentResult(
          processedImage: file,
          metadata: {'treatment': treatmentType, 'intensity': intensity.toString()},
        );
      } else {
        debugPrint('Error en API OpenAI: ${response.statusCode}, ${response.body}');
        throw Exception('Error en API OpenAI: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error con API de OpenAI: $e');
      rethrow;
    }
  }
  
  // Método auxiliar para convertir imágenes a PNG con transparencia
  Future<File> _convertToTransparentPng(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalImage = image.decodeImage(bytes);
    
    if (originalImage == null) {
      throw Exception('No se pudo decodificar la imagen original');
    }
    
    // Crear una imagen con canal alfa usando el método correcto para la versión 4.0+
    final pngImage = image.copyResize(
      originalImage,
      width: originalImage.width,
      height: originalImage.height,
    );
    
    // Guardar como PNG
    final tempDir = await getTemporaryDirectory();
    final pngFile = File('${tempDir.path}/input_${DateTime.now().millisecondsSinceEpoch}.png');
    await pngFile.writeAsBytes(image.encodePng(pngImage));
    
    return pngFile;
  }
  
  String _createPromptForTreatment({
    required String treatmentType,
    required double intensity,
  }) {
    // Determinar nivel de intensidad en texto
    final intensityText = intensity <= 0.3 ? 'sutil' : 
                         intensity <= 0.7 ? 'moderado' : 'pronunciado';
    
    // Prompts específicos para cada tratamiento, enfocados en la región enmascarada
    final Map<String, String> treatmentPrompts = {
      'lips': 'Haz que los labios se vean más carnosos y simétricos con un aumento $intensityText. '
              'Mantén el color natural pero intensifica ligeramente el volumen y la definición.',
      
      'nose': 'Refina la nariz de forma $intensityText. Suaviza el puente nasal y refina la punta '
              'para que sea más simétrica sin cambiar drásticamente su carácter.',
      
      'botox': 'Aplica un efecto de botox $intensityText en esta zona. Suaviza las líneas de expresión '
               'y arrugas pero mantén la expresividad natural del rostro.',
      
      'fillers': 'Aplica rellenos $intensityText en esta zona. Añade volumen de forma natural '
                'y suaviza los surcos sin exagerar.',
      
      'jawline': 'Define la línea de la mandíbula de manera $intensityText. Crea un contorno más marcado '
                'y definido pero natural.',
                
      'cheeks': 'Realza los pómulos de manera $intensityText. Añade volumen y definición para un '
               'aspecto más esculpido pero natural.',
    };
    
    // Base del prompt
    final basePrompt = treatmentPrompts[treatmentType] ?? 
        'Mejora esta área específica con un efecto $intensityText y natural';
    
    // Prompt adaptado para el endpoint de edición (inpainting)
    return '''
    Realiza un $intensityText tratamiento estético en la zona enmascarada:
    
    $basePrompt
    
    Mantenla totalmente armónica con el rostro original. El resultado debe ser fotorrealista y médicamente plausible.
    Preserva exactamente el mismo estilo, luz, sombras y textura de piel de la imagen original.
    Modifica SOLO el área enmascarada, dejando el resto perfectamente intacto.
    ''';
  }
  
  Future<void> _saveToGallery() async {
    if (_processedImage == null) {
      _showError('No hay imagen para guardar');
      return;
    }
    
    try {
      final result = await ImageGallerySaver.saveFile(_processedImage!.path);
      
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
                        Icon(Icons.auto_awesome, size: 14, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'GPT-4',
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