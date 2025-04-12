import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import 'dart:math';

class FaceMeshTreatmentSimulator extends StatefulWidget {
  final String initialTreatment;
  final double initialIntensity;
  
  const FaceMeshTreatmentSimulator({
    Key? key, 
    required this.initialTreatment,
    required this.initialIntensity,
  }) : super(key: key);

  @override
  State<FaceMeshTreatmentSimulator> createState() => _FaceMeshTreatmentSimulatorState();
}

class _FaceMeshTreatmentSimulatorState extends State<FaceMeshTreatmentSimulator> with WidgetsBindingObserver {
  CameraController? _cameraController;

final FaceMeshDetector _faceMeshDetector = FaceMeshDetector(
  option: FaceMeshDetectorOptions.faceMesh
);

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    )
  );
    
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _isFaceDetected = false;
  String _selectedTreatment = 'lips';
  double _intensity = 0.5;
  File? _capturedImage;
  String _errorMessage = '';
  
  List<FaceMesh>? _detectedMeshes;
  List<Face>? _detectedFaces;
  
  // Variables para grabación de video
  bool _isRecording = false;
  
  // Mapeo de tratamientos disponibles
  final Map<String, String> _treatmentOptions = {
    'lips': 'Aumento de labios',
    'nose': 'Rinomodelación',
    'botox': 'Botox',
    'fillers': 'Rellenos faciales',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTreatment = widget.initialTreatment;
    _intensity = widget.initialIntensity;
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _faceMeshDetector.close();
    _faceDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid 
            ? ImageFormatGroup.yuv420 
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      
      _cameraController!.startImageStream((image) {
        if (!_isProcessing) {
          _isProcessing = true;
          _processImage(image);
        }
      });

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      _showError("Error iniciando cámara: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    // Si ya estamos procesando, saltamos este frame
    if (_isProcessing) return;
    
    _isProcessing = true;
    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }
      
      // Primero detectar si hay una cara (más rápido)
      final faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _isFaceDetected = false;
            _isProcessing = false;
          });
        }
        return;
      }
      
      // Solo si hay cara, procesamos la malla completa (más costoso)
      final meshes = await _faceMeshDetector.processImage(inputImage);
      
      if (mounted) {
        setState(() {
          _detectedMeshes = meshes;
          _detectedFaces = faces;
          _isFaceDetected = meshes.isNotEmpty && faces.isNotEmpty;
          _isProcessing = false;
        });
      }
    } catch (e) {
      print("Error procesando imagen: $e");
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    
    // Determinar la rotación correcta
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      // En Android, compensar rotación según orientación del dispositivo
      final deviceOrientation = MediaQuery.of(context).orientation;
      int rotationCompensation = 0;
      
      if (deviceOrientation == Orientation.portrait) {
        rotationCompensation = 0;
      } else if (deviceOrientation == Orientation.landscape) {
        rotationCompensation = 90;
      }
      
      if (camera.lensDirection == CameraLensDirection.front) {
        // Cámara frontal
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // Cámara trasera
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    
    if (rotation == null) return null;
    
    // Verificar formato
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    
    // Para estos formatos, usamos solo el primer plano
    if (image.planes.length < 1) return null;
    final plane = image.planes.first;
    
    // Crear InputImage con el enfoque actualizado
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // Solo usado en Android
        format: format, // Solo usado en iOS
        bytesPerRow: plane.bytesPerRow, // Solo usado en iOS
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_isCameraInitialized || !_isFaceDetected) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Pausar el streaming
      await _cameraController!.stopImageStream();
      
      // Capturar la imagen
      final XFile rawImage = await _cameraController!.takePicture();
      
      // Aplicar efecto a la imagen capturada
      final processedImage = await _applyEffectsToImage(File(rawImage.path));
      
      setState(() {
        _capturedImage = processedImage;
        _isProcessing = false;
      });
    } catch (e) {
      _showError("Error capturando imagen: $e");
      setState(() {
        _isProcessing = false;
      });
      
      // Reiniciar streaming en caso de error
      _resumeCamera();
    }
  }
  
  void _resumeCamera() {
    _cameraController?.startImageStream((image) {
      if (!_isProcessing) {
        _isProcessing = true;
        _processImage(image);
      }
    });
  }

  Future<File> _applyEffectsToImage(File imageFile) async {
    // Cargar imagen
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    
    if (image == null) {
      return imageFile;
    }
    
    // Aplicar efecto según el tratamiento seleccionado
    if (_selectedTreatment == 'lips' && _detectedMeshes != null) {
      image = await _applyLipEnhancement(image, _intensity);
    } 
    else if (_selectedTreatment == 'nose' && _detectedMeshes != null) {
      image = await _applyNoseRefinement(image, _intensity);
    } 
    else if (_selectedTreatment == 'botox' && _detectedMeshes != null) {
      image = await _applyBotoxEffect(image, _intensity);
    } 
    else if (_selectedTreatment == 'fillers' && _detectedMeshes != null) {
      image = await _applyFillersEffect(image, _intensity);
    }
    
    // Guardar imagen procesada
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/processed_image.jpg';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(image));
    
    return outputFile;
  }
  
  Future<img.Image> _applyLipEnhancement(img.Image image, double intensity) async {
    // Implementación del efecto
    if (_detectedMeshes == null || _detectedMeshes!.isEmpty) return image;
    
    final faceMesh = _detectedMeshes!.first;
    final List<Point<int>> lipPoints = [];
    
    // Encontrar puntos de los labios - índices específicos para labios en la malla facial
    // Face Mesh tiene ~468 puntos, los labios generalmente están entre los puntos 0-12
    final lipRegion = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291, 375, 321, 405, 314, 17, 84, 181, 91, 146];
    
    for (final index in lipRegion) {
      if (faceMesh.points.length > index) {
        final point = faceMesh.points[index];
        lipPoints.add(Point<int>(point.x.toInt(), point.y.toInt()));
      }
    }
    
    if (lipPoints.isEmpty) return image;
    
    // Calcular centro de los labios
    int sumX = 0, sumY = 0;
    for (final point in lipPoints) {
      sumX += point.x;
      sumY += point.y;
    }
    
    final centerX = sumX ~/ lipPoints.length;
    final centerY = sumY ~/ lipPoints.length;
    
    // Color para los labios
    final lipColor = img.ColorRgba8(255, 105, 105, (255 * intensity).toInt());
    
    // Radius depende de la intensidad
    final lipRadius = (35 * intensity).toInt();
    
    // Aplicar color a la región de los labios
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final distance = _calculateDistance(x, y, centerX, centerY);
        if (distance < lipRadius) {
          // Aplicar color con transparencia basada en la distancia
          final alpha = 1.0 - (distance / lipRadius);
          final blendFactor = alpha * intensity;
          
          final pixel = image.getPixel(x, y);
          final currentColor = pixel.a.toInt() << 24 | pixel.r.toInt() << 16 | pixel.g.toInt() << 8 | pixel.b.toInt();
          final lipColorValue = (lipColor.a.toInt() << 24) | (lipColor.r.toInt() << 16) | 
                                (lipColor.g.toInt() << 8) | lipColor.b.toInt();
          final newColor = _blendColors(currentColor, lipColorValue, blendFactor);

          final newR = (newColor >> 16) & 0xFF;
          final newG = (newColor >> 8) & 0xFF;
          final newB = newColor & 0xFF;
          final newA = (newColor >> 24) & 0xFF;
          image.setPixel(x, y, img.ColorRgba8(newR, newG, newB, newA));

        }
      }
    }
    
    return image;
  }
  
  
  Future<img.Image> _applyNoseRefinement(img.Image image, double intensity) async {
    if (_detectedMeshes == null || _detectedMeshes!.isEmpty) return image;
    
    final faceMesh = _detectedMeshes!.first;
    final noseRegion = [168, 6, 197, 195, 5, 4, 1, 19, 94, 2];
    
    // Obtener puntos de la nariz
    int sumX = 0, sumY = 0;
    int count = 0;
    
    for (final index in noseRegion) {
      if (faceMesh.points.length > index) {
        final point = faceMesh.points[index];
        sumX += point.x.toInt();
        sumY += point.y.toInt();
        count++;
      }
    }
    
    if (count == 0) return image;
    
    final centerX = sumX ~/ count;
    final centerY = sumY ~/ count;
    
    // Aplicar adelgazamiento de nariz
    final noseWidth = 30;
    
    // Crear una máscara para la región de la nariz
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final distance = _calculateDistance(x, y, centerX, centerY);
        
        if (distance < noseWidth) {
          // Aplicar transformación (adelgazamiento)
          final offsetX = ((x - centerX) * (1.0 - intensity * 0.5)).toInt();
          final newX = centerX + offsetX;
          
          // Asegurar que las coordenadas están dentro de los límites
          if (newX >= 0 && newX < image.width) {
            // Copiar color del pixel desplazado
            final sourceColor = image.getPixel(newX, y);
            image.setPixel(x, y, sourceColor);
          }
        }
      }
    }
    
    return image;
  }
  
  Future<img.Image> _applyBotoxEffect(img.Image image, double intensity) async {
    if (_detectedMeshes == null || _detectedMeshes!.isEmpty) return image;
    
    // Aplicar suavizado (efecto botox)
    const radius = 3;
    final tempImage = image.clone();
    
    for (int y = radius; y < image.height - radius; y++) {
      for (int x = radius; x < image.width - radius; x++) {
        // Ubicar puntos de la frente
        bool isInForeheadRegion = false;
        
        // Simplificación: definir una región rectangular para la frente
        if (_detectedFaces != null && _detectedFaces!.isNotEmpty) {
          final face = _detectedFaces!.first;
          final box = face.boundingBox;
          
          // La frente es aproximadamente el tercio superior de la cara
          if (y > box.top && y < box.top + box.height / 3 &&
              x > box.left && x < box.right) {
            isInForeheadRegion = true;
          }
        }
        
        if (isInForeheadRegion) {
          // Aplicar filtro de suavizado basado en intensidad
          int r = 0, g = 0, b = 0;
          int count = 0;
          
          // Tamaño del kernel basado en intensidad
          final blurRadius = (radius * intensity).toInt() + 1;
          
          for (int ky = -blurRadius; ky <= blurRadius; ky++) {
            for (int kx = -blurRadius; kx <= blurRadius; kx++) {
              final newX = x + kx;
              final newY = y + ky;
              
              if (newX >= 0 && newX < image.width && newY >= 0 && newY < image.height) {
              final pixel = tempImage.getPixel(newX, newY);
              r += pixel.r.toInt();
              g += pixel.g.toInt();
              b += pixel.b.toInt();
                count++;
              }
            }
          }
          
          if (count > 0) {
            r ~/= count;
            g ~/= count;
            b ~/= count;
            
            image.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
          }
        }
      }
    }
    
    return image;
  }
  
  Future<img.Image> _applyFillersEffect(img.Image image, double intensity) async {
    // Implementación para rellenos faciales
    if (_detectedMeshes == null || _detectedMeshes!.isEmpty) return image;
    
    // Puntos para las mejillas
    final cheekRegion = [117, 118, 119, 120, 347, 348, 349, 350];
    
    // Implementar aumento de volumen en las mejillas
    
    return image;
  }
  
  double _calculateDistance(int x1, int y1, int x2, int y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }
  
  double sqrt(num value) => value <= 0 ? 0 : math.sqrt(value);
  double pow(num a, num b) => math.pow(a, b).toDouble();
  
  int _blendColors(int baseColor, int overlayColor, double alpha) {
    final baseR = (baseColor >> 16) & 0xFF;
    final baseG = (baseColor >> 8) & 0xFF;
    final baseB = baseColor & 0xFF;
    
    final overlayR = (overlayColor >> 16) & 0xFF;
    final overlayG = (overlayColor >> 8) & 0xFF;
    final overlayB = overlayColor & 0xFF;
    
    final r = (baseR * (1 - alpha) + overlayR * alpha).toInt().clamp(0, 255);
    final g = (baseG * (1 - alpha) + overlayG * alpha).toInt().clamp(0, 255);
    final b = (baseB * (1 - alpha) + overlayB * alpha).toInt().clamp(0, 255);
    
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }

  

  Future<void> _saveImage() async {
    if (_capturedImage == null) return;
    
    try {
      final result = await ImageGallerySaver.saveFile(_capturedImage!.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen guardada en la galería'))
      );
    } catch (e) {
      _showError("Error guardando imagen: $e");
    }
  }

  Future<void> _shareImage() async {
    if (_capturedImage == null) return;
    
    try {
      await Share.shareXFiles(
        [XFile(_capturedImage!.path)],
        text: 'Mi simulación de ${_treatmentOptions[_selectedTreatment]}',
      );
    } catch (e) {
      _showError("Error al compartir: $e");
    }
  }

  void _discardImage() {
    setState(() {
      _capturedImage = null;
    });
    
    _resumeCamera();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_treatmentOptions[_selectedTreatment] ?? 'Simulador'),
        backgroundColor: Colors.black54,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Vista principal
          _capturedImage == null 
              ? (_isCameraInitialized 
                  ? CameraPreview(_cameraController!) 
                  : const Center(child: CircularProgressIndicator()))
              : Image.file(_capturedImage!, fit: BoxFit.cover),
          
          // Malla facial (para depuración)
          if (_isFaceDetected && _capturedImage == null && _detectedMeshes != null)
            CustomPaint(
              painter: FaceMeshPainter(
                _detectedMeshes!, 
                _detectedFaces ?? [], 
                _selectedTreatment, 
                _intensity
              ),
              size: Size.infinite,
            ),
          
          // Indicador de detección facial
          if (!_isFaceDetected && _isCameraInitialized && _capturedImage == null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withOpacity(0.7),
                child: const Text(
                  'No se detecta rostro',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          
          // Mensaje de error
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: 150,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.withOpacity(0.7),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          
          // Panel de controles
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Selector de tratamiento
                    if (_capturedImage == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _treatmentOptions.keys.map((treatment) => 
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedTreatment = treatment;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _selectedTreatment == treatment 
                                        ? Colors.white 
                                        : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    _treatmentOptions[treatment] ?? treatment,
                                    style: TextStyle(
                                      color: _selectedTreatment == treatment 
                                        ? Colors.white 
                                        : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ).toList(),
                        ),
                      ),
                    ),
                    
                    // Slider de intensidad
                    if (_capturedImage == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            const Text(
                              'Intensidad:', 
                              style: TextStyle(color: Colors.white)
                            ),
                            Expanded(
                              child: Slider(
                                value: _intensity,
                                min: 0.0,
                                max: 1.0,
                                activeColor: Colors.white,
                                inactiveColor: Colors.grey,
                                onChanged: (value) {
                                  setState(() {
                                    _intensity = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Botones de acción
                    if (_capturedImage == null && _isCameraInitialized)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Botón de captura de foto
                          GestureDetector(
                            onTap: (_isFaceDetected && !_isProcessing) ? _capturePhoto : null,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: (_isFaceDetected && !_isProcessing) ? Colors.white : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (_isFaceDetected && !_isProcessing) ? Colors.white : Colors.grey,
                                  width: 3,
                                ),
                              ),
                              child: _isProcessing 
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.camera_alt, size: 32),
                            ),
                          ),
                        ],
                      )
                    else if (_capturedImage != null)
                      // Botones para la imagen capturada
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: _discardImage,
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: 'Descartar',
                          ),
                          IconButton(
                            onPressed: _saveImage,
                            icon: const Icon(Icons.save, color: Colors.white),
                            tooltip: 'Guardar',
                          ),
                          IconButton(
                            onPressed: _shareImage,
                            icon: const Icon(Icons.share, color: Colors.white),
                            tooltip: 'Compartir',
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
    );
  }
}

// Painter para visualizar la malla facial
class FaceMeshPainter extends CustomPainter {
  final List<FaceMesh> faceMeshes;
  final List<Face> faces;
  final String selectedTreatment;
  final double intensity;
  
  FaceMeshPainter(this.faceMeshes, this.faces, this.selectedTreatment, this.intensity);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (faceMeshes.isEmpty) return;
    
    final Paint paint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final Paint highlightPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3 * intensity)
      ..style = PaintingStyle.fill;
    
    // Dibujar solo algunos puntos clave para no saturar la visualización
    for (final mesh in faceMeshes) {
      // Dibujar solo cada 5 puntos para que sea más ligero
      for (int i = 0; i < mesh.points.length; i += 5) {
        final point = mesh.points[i];
        canvas.drawCircle(
          Offset(point.x, point.y),
          1.5,
          paint
        );
      }
      
      // Basado en el tratamiento seleccionado, resaltar áreas específicas
      if (selectedTreatment == 'lips') {
        _highlightLips(canvas, mesh, highlightPaint);
      } else if (selectedTreatment == 'nose') {
        _highlightNose(canvas, mesh, highlightPaint);
      } else if (selectedTreatment == 'botox') {
        _highlightForehead(canvas, mesh, highlightPaint);
      } else if (selectedTreatment == 'fillers') {
        _highlightCheeks(canvas, mesh, highlightPaint);
      }
    }
  }
  
  void _highlightLips(Canvas canvas, FaceMesh mesh, Paint paint) {
    // Índices de puntos que corresponden a los labios
    final lipIndices = [61, 185, 40, 39, 37, 0, 267, 269, 270, 409, 291, 375, 321, 405, 314, 17, 84, 181, 91, 146];
    
    final Path path = Path();
    bool firstPoint = true;
    
    for (final index in lipIndices) {
      if (mesh.points.length > index) {
        final point = mesh.points[index];
        if (firstPoint) {
          path.moveTo(point.x, point.y);
          firstPoint = false;
        } else {
          path.lineTo(point.x, point.y);
        }
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
  
  void _highlightNose(Canvas canvas, FaceMesh mesh, Paint paint) {
    // Índices para la nariz
    final noseIndices = [168, 6, 197, 195, 5, 4, 1, 19, 94, 2];
    
    final Path path = Path();
    bool firstPoint = true;
    
    for (final index in noseIndices) {
      if (mesh.points.length > index) {
        final point = mesh.points[index];
        if (firstPoint) {
          path.moveTo(point.x, point.y);
          firstPoint = false;
        } else {
          path.lineTo(point.x, point.y);
        }
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
  
  void _highlightForehead(Canvas canvas, FaceMesh mesh, Paint paint) {
    // Puntos de la frente
    final foreheadIndices = [10, 151, 9, 8, 109, 67, 103, 104];
    
    final Path path = Path();
    bool firstPoint = true;
    
    for (final index in foreheadIndices) {
      if (mesh.points.length > index) {
        final point = mesh.points[index];
        if (firstPoint) {
          path.moveTo(point.x, point.y);
          firstPoint = false;
        } else {
          path.lineTo(point.x, point.y);
        }
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
  
  void _highlightCheeks(Canvas canvas, FaceMesh mesh, Paint paint) {
    // Puntos de las mejillas
    if (mesh.points.length > 117 && mesh.points.length > 347) {
      final leftCheek = mesh.points[117];
      final rightCheek = mesh.points[347];
      
      canvas.drawCircle(
        Offset(leftCheek.x, leftCheek.y),
        30 * intensity,
        paint
      );
      
      canvas.drawCircle(
        Offset(rightCheek.x, rightCheek.y),
        30 * intensity,
        paint
      );
    }
  }
  
  @override
  bool shouldRepaint(FaceMeshPainter oldDelegate) {
    return oldDelegate.faceMeshes != faceMeshes || 
           oldDelegate.selectedTreatment != selectedTreatment ||
           oldDelegate.intensity != intensity;
  }
}

