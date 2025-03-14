import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart' show Point;
import 'package:image/image.dart' show Pixel;

class MLKitService {
  // Singleton pattern
  static final MLKitService _instance = MLKitService._internal();
  factory MLKitService() => _instance;
  
  // Inicializa el detector de rostros en el constructor interno
  late final FaceDetector _faceDetector;
  
  MLKitService._internal() {
    // Inicializar el detector de rostros con opciones predeterminadas
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
  }

  // Intenta detectar rostros con múltiples estrategias
  Future<List<Face>> _detectFacesWithMultipleStrategies(File imageFile) async {
    try {
      print("Iniciando detección de rostros avanzada");
      
      // 1. Verificar que la imagen es válida
      final bool fileExists = await imageFile.exists();
      final int fileSize = await imageFile.length();
      
      print('Verificando imagen: Existe=$fileExists, Tamaño=$fileSize bytes');
      
      if (!fileExists || fileSize == 0) {
        throw Exception('Archivo de imagen inválido o vacío');
      }
      
      // 2. Intento estándar
      print("Intentando detección con detector normal");
      final inputImage = InputImage.fromFile(imageFile);
      List<Face> faces = await _faceDetector.processImage(inputImage);
      if (faces.isNotEmpty) {
        print("Rostros detectados con método estándar: ${faces.length}");
        return faces;
      }
      
      // 3. Intento con detector menos estricto
      print("Primer intento: No se detectaron rostros, intentando con opciones menos estrictas");
      final lessStrictDetector = _createLessStrictDetector();
      faces = await lessStrictDetector.processImage(inputImage);
      lessStrictDetector.close();
      if (faces.isNotEmpty) {
        print("Rostros detectados con detector menos estricto: ${faces.length}");
        return faces;
      }
      
      // 4. Ajustes fuertes de imagen para mejorar detección
      print("Segundo intento: Aplicando mejoras avanzadas a la imagen");
      final enhancedFile = await _enhanceImageForFaceDetection(imageFile);
      final enhancedInput = InputImage.fromFile(enhancedFile);
      
      // Probar con detector normal en imagen mejorada
      faces = await _faceDetector.processImage(enhancedInput);
      if (faces.isNotEmpty) {
        print("Rostros detectados con imagen mejorada: ${faces.length}");
        return faces;
      }
      
      // Probar con detector menos estricto en imagen mejorada
      faces = await lessStrictDetector.processImage(enhancedInput);
      if (faces.isNotEmpty) {
        print("Rostros detectados con imagen mejorada y detector menos estricto: ${faces.length}");
        lessStrictDetector.close();
        return faces;
      }
      
      // 5. Intentar con diferentes rotaciones
      for (int angle in [90, 270, 180]) {
        print("Intentando con rotación de $angle grados");
        final rotatedFile = await _rotateImage(imageFile, angle);
        final rotatedInput = InputImage.fromFile(rotatedFile);
        
        // Probar con detector normal
        List<Face> rotatedFaces = await _faceDetector.processImage(rotatedInput);
        if (rotatedFaces.isNotEmpty) {
          print("Rostros detectados con rotación de $angle grados: ${rotatedFaces.length}");
          return rotatedFaces;
        }
        
        // Probar con detector menos estricto
        rotatedFaces = await lessStrictDetector.processImage(rotatedInput);
        if (rotatedFaces.isNotEmpty) {
          print("Rostros detectados con rotación de $angle grados y detector menos estricto: ${rotatedFaces.length}");
          return rotatedFaces;
        }
        
        // Probar con imagen mejorada y rotada
        final enhancedRotatedFile = await _enhanceImageForFaceDetection(rotatedFile);
        final enhancedRotatedInput = InputImage.fromFile(enhancedRotatedFile);
        
        rotatedFaces = await _faceDetector.processImage(enhancedRotatedInput);
        if (rotatedFaces.isNotEmpty) {
          print("Rostros detectados con imagen mejorada y rotación de $angle grados: ${rotatedFaces.length}");
          return rotatedFaces;
        }
      }
      
      // 6. Probar con redimensionamiento de imagen
      print("Intentando con imagen redimensionada");
      final resizedFile = await _resizeImage(imageFile, 0.8); // 80% del tamaño original
      final resizedInput = InputImage.fromFile(resizedFile);
      
      faces = await _faceDetector.processImage(resizedInput);
      if (faces.isNotEmpty) {
        print("Rostros detectados con imagen redimensionada: ${faces.length}");
        return faces;
      }
      
      // Si llegamos aquí, no se detectaron rostros
      print("No se pudieron detectar rostros después de todas las estrategias");
      lessStrictDetector.close();
      return [];
    } catch (e) {
      print("Error durante detección de rostros: $e");
      return [];
    }
  }

  // Nueva función para redimensionar imagen
  Future<File> _resizeImage(File imageFile, double scale) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;
      
      // Redimensionar imagen
      img.Image resized = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round()
      );
      
      // Guardar imagen redimensionada
      final tempDir = await getTemporaryDirectory();
      final resizedPath = '${tempDir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resizedFile = File(resizedPath);
      await resizedFile.writeAsBytes(img.encodeJpg(resized, quality: 90));
      
      return resizedFile;
    } catch (e) {
      print("Error redimensionando imagen: $e");
      return imageFile;
    }
  }

  // Mejora la imagen para aumentar probabilidad de detección de rostros
  Future<File> _enhanceImageForFaceDetection(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;
      
      // Aplicar mejoras específicas para detección facial
      image = img.adjustColor(
        image,
        contrast: 1.2,   // Mayor contraste
        brightness: 0.1, // Ligeramente más brillante
        saturation: 0.9, // Menos saturación para reducir influencia del color
        gamma: 0.95      // Ajuste gamma para mejorar detalles en sombras
      );
      
      // Ecualización de histograma personalizada para mejorar contraste local
      image = _histogramEqualization(image);
      
      // Guardar imagen mejorada
      final tempDir = await getTemporaryDirectory();
      final enhancedPath = '${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final enhancedFile = File(enhancedPath);
      await enhancedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      
      return enhancedFile;
    } catch (e) {
      print("Error mejorando imagen: $e");
      return imageFile;
    }
  }
  
  // Implementación personalizada de ecualización de histograma
  img.Image _histogramEqualization(img.Image image) {
    // Convertir a escala de grises para trabajar con luminosidad
    final grayImage = img.grayscale(image);
    
    // Calcular histograma
    final List<int> histogram = List.filled(256, 0);
    for (int y = 0; y < grayImage.height; y++) {
      for (int x = 0; x < grayImage.width; x++) {
        final pixel = grayImage.getPixel(x, y);
        final intensity = pixel.r; // En imagen en escala de grises, R=G=B
        histogram[intensity.toInt()]++;
      }
    }
    
    // Calcular distribución acumulativa
    final List<int> cdf = List.filled(256, 0);
    cdf[0] = histogram[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }
    
    // Normalizar CDF
    final double cdfMin = cdf.firstWhere((value) => value > 0, orElse: () => 0).toDouble();
    final double normFactor = 255.0 / (grayImage.width * grayImage.height - cdfMin);
    final List<int> lookupTable = List.filled(256, 0);
    
    for (int i = 0; i < 256; i++) {
      lookupTable[i] = ((cdf[i] - cdfMin) * normFactor).round().clamp(0, 255);
    }
    
    // Crear imagen ecualizada manteniendo color
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final originalPixel = image.getPixel(x, y);
        final grayPixel = grayImage.getPixel(x, y);
        
        // Obtener luminosidad original y ecualizada
        final originalIntensity = grayPixel.r.toInt();
        final equalizedIntensity = lookupTable[originalIntensity];
        
        // Calcular factor de ajuste
        final double factor = originalIntensity == 0 
            ? 1.0 
            : equalizedIntensity / originalIntensity.toDouble();
        
        // Ajustar cada canal manteniendo tono y saturación
        result.setPixel(x, y, img.ColorRgba8(
          (originalPixel.r * factor).round().clamp(0, 255),
          (originalPixel.g * factor).round().clamp(0, 255),
          (originalPixel.b * factor).round().clamp(0, 255),
          originalPixel.a.toInt()
        ));
      }
    }
    
    return result;
  }
  
  // Rota la imagen un ángulo específico
  Future<File> _rotateImage(File imageFile, int angle) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;
      
      // Rotar imagen
      img.Image rotated = img.copyRotate(image, angle: angle);
      
      // Guardar imagen rotada
      final tempDir = await getTemporaryDirectory();
      final rotatedPath = '${tempDir.path}/rotated_${angle}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rotatedFile = File(rotatedPath);
      await rotatedFile.writeAsBytes(img.encodeJpg(rotated, quality: 90));
      
      return rotatedFile;
    } catch (e) {
      print("Error rotando imagen: $e");
      return imageFile;
    }
  }

  // Detector con opciones menos estrictas
  FaceDetector _createLessStrictDetector() {
    return FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1, // Valor más pequeño para detectar rostros más lejanos
        enableTracking: false
      ),
    );
  }

  // Preprocesamiento de imagen para mejorar detección facial
  Future<File> preprocessImage(File imageFile) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));
      
      if (image == null) {
        print('Error: No se pudo decodificar la imagen en preprocessImage');
        return imageFile;  // Devolver original si hay error
      }
      
      // 1. Normalizar tamaño (si es muy grande, reducir manteniendo proporción)
      if (image.width > 1280 || image.height > 1280) {
        print('Redimensionando imagen grande: ${image.width}x${image.height}');
        double ratio = image.width > image.height 
            ? 1280 / image.width
            : 1280 / image.height;
        
        image = img.copyResize(
          image, 
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
        );
      }
      
      // 2. Normalizar brillo y contraste para mejorar detección
      image = img.adjustColor(
        image,
        contrast: 1.1,  // Ligero aumento de contraste
        brightness: 0.05  // Ligero aumento de brillo
      );
      
      // 3. Guardar imagen preprocesada
      final tempDir = await getTemporaryDirectory();
      final preprocessedPath = '${tempDir.path}/preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final preprocessedFile = File(preprocessedPath);
      await preprocessedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      
      print('Imagen preprocesada: ${preprocessedPath}');
      return preprocessedFile;
    } catch (e) {
      print('Error en preprocessImage: $e');
      return imageFile;  // Devolver original si hay error
    }
  }
  
  // Método principal para procesar imagen
  Future<File> simulateTreatment({
    required File imageFile,
    required String treatmentType,
    required double intensity,
  }) async {
    try {
      // Validar imagen
      final bool fileExists = await imageFile.exists();
      final int fileSize = await imageFile.length();
      
      print('Verificando imagen: Existe=$fileExists, Tamaño=$fileSize bytes');
      
      if (!fileExists || fileSize == 0) {
        throw Exception('Archivo de imagen inválido o vacío');
      }
      
      // 1. Preprocesar imagen
      print('Preprocesando imagen...');
      final preprocessedFile = await preprocessImage(imageFile);
      
      // 2. Detectar rostros con estrategia mejorada
      print('Detectando rostros...');
      final List<Face> faces = await _detectFacesWithMultipleStrategies(preprocessedFile);
      
      if (faces.isEmpty) {
        print('No se detectaron rostros después de múltiples intentos');
        throw Exception("No se detectó ningún rostro en la imagen después de múltiples intentos.");
      }
      
      print('Rostros detectados: ${faces.length}');
      
      // 3. Usar el primer rostro detectado
      final face = faces.first;
      
      // 4. Cargar imagen original para mantener calidad
      print('Cargando imagen original...');
      final List<int> imageBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(Uint8List.fromList(imageBytes));
      
      if (originalImage == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      
      // 5. Aplicar transformación según el tipo de tratamiento
      print('Aplicando tratamiento: $treatmentType con intensidad: $intensity');
      final img.Image processedImage = await _applyTreatment(
        originalImage, 
        face, 
        treatmentType, 
        intensity
      );
      
      // 6. Guardar resultado
      print('Guardando resultado...');
      final String resultPath = await _saveProcessedImage(processedImage);
      print('Imagen procesada guardada en: $resultPath');
      
      return File(resultPath);
    } catch (e) {
      print('Error detallado en MLKitService: $e');
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Error en procesamiento de imagen: $e');
      }
    }
  } 

    Future<File> debugFaceDetection(File imageFile) async {
    try {
      // 1. Preprocesar imagen
      final preprocessedFile = await preprocessImage(imageFile);
      
      // 2. Convertir archivo a formato utilizable por ML Kit
      final inputImage = InputImage.fromFile(preprocessedFile);
      
      // 3. Intentar con detector normal
      print("Debug: Intentando detección con detector normal");
      var faces = await _faceDetector.processImage(inputImage);
      
      // 4. Si no hay rostros, intentar con detector menos estricto
      if (faces.isEmpty) {
        print("Debug: No se detectaron rostros con detector normal, intentando con menos restricciones");
        final lessStrictDetector = _createLessStrictDetector();
        faces = await lessStrictDetector.processImage(inputImage);
        lessStrictDetector.close();
        
        if (faces.isNotEmpty) {
          print("Debug: Se encontraron ${faces.length} rostros con detector menos estricto");
        } else {
          print("Debug: No se encontraron rostros con detector menos estricto");
        }
      } else {
        print("Debug: Se detectaron ${faces.length} rostros con detector normal");
      }
      
      // 5. Cargar la imagen para dibujar contornos
      final bytes = await preprocessedFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      
      // 6. Crear imagen de depuración
      final debugImage = img.Image(width: image.width, height: image.height);
      img.compositeImage(debugImage, image);
      
      // 7. Dibujar rectángulos para cada rostro detectado
      for (var face in faces) {
        final rect = face.boundingBox;
        
        // Dibujar rectángulo rojo alrededor del rostro
        _drawRectangle(
          debugImage,
          rect.left.round(),
          rect.top.round(),
          rect.width.round(),
          rect.height.round(),
          img.ColorRgba8(255, 0, 0, 255)
        );
        
        // Dibujar puntos faciales importantes (landmarks)
        face.landmarks.forEach((type, landmark) {
          if (landmark != null) {
            _drawCircle(
              debugImage,
              landmark.position.x.round(),
              landmark.position.y.round(),
              5,
              img.ColorRgba8(0, 255, 0, 255)
            );
          }
        });
        
        // Dibujar contornos si están disponibles
        face.contours.forEach((type, contour) {
          if (contour != null) {
            for (var i = 0; i < contour.points.length; i++) {
              final point = contour.points[i];
              _drawCircle(
                debugImage,
                point.x.round(),
                point.y.round(),
                2,
                img.ColorRgba8(0, 0, 255, 255)
              );
              
              // Conectar puntos consecutivos
              if (i < contour.points.length - 1) {
                final nextPoint = contour.points[i + 1];
                _drawLine(
                  debugImage,
                  point.x.round(),
                  point.y.round(),
                  nextPoint.x.round(),
                  nextPoint.y.round(),
                  img.ColorRgba8(0, 0, 255, 255)
                );
              }
            }
          }
        });
      }
      
      // 8. Agregar texto informativo a la imagen
      _drawText(debugImage, "Rostros detectados: ${faces.length}", 10, 30, img.ColorRgba8(255, 255, 0, 255));
      
      if (faces.isEmpty) {
        _drawText(debugImage, "NO SE DETECTARON ROSTROS", 10, 60, img.ColorRgba8(255, 0, 0, 255));
      }
      
      // 9. Guardar imagen con anotaciones
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/debug_faces_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final debugFile = File(tempFilePath);
      
      await debugFile.writeAsBytes(img.encodeJpg(debugImage, quality: 90));
      return debugFile;
    } catch (e) {
      print('Error en depuración de rostros: $e');
      rethrow;
    }
  }

  // Función auxiliar para dibujar un rectángulo
  void _drawRectangle(img.Image image, int x, int y, int width, int height, img.Color color) {
    // Dibujar líneas horizontales
    for (int i = 0; i < width; i++) {
      int px = x + i;
      if (px >= 0 && px < image.width) {
        if (y >= 0 && y < image.height) image.setPixel(px, y, color);
        if (y + height >= 0 && y + height < image.height) image.setPixel(px, y + height, color);
      }
    }
    
    // Dibujar líneas verticales
    for (int i = 0; i < height; i++) {
      int py = y + i;
      if (py >= 0 && py < image.height) {
        if (x >= 0 && x < image.width) image.setPixel(x, py, color);
        if (x + width >= 0 && x + width < image.width) image.setPixel(x + width, py, color);
      }
    }
  }

  // Función auxiliar para dibujar un círculo
  void _drawCircle(img.Image image, int x, int y, int radius, img.Color color) {
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy <= radius * radius) {
          int px = x + dx;
          int py = y + dy;
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            image.setPixel(px, py, color);
          }
        }
      }
    }
  }

  // Función auxiliar para dibujar una línea
  void _drawLine(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
    int dx = (x2 - x1).abs();
    int dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1;
    int sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (x1 >= 0 && x1 < image.width && y1 >= 0 && y1 < image.height) {
        image.setPixel(x1, y1, color);
      }
      
      if (x1 == x2 && y1 == y2) break;
      
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y1 += sy;
      }
    }
  }

  // Función para dibujar texto (simplificada)
  void _drawText(img.Image image, String text, int x, int y, img.Color color) {
    // Esta es una implementación muy básica
    // En producción podrías usar un paquete más completo para esto
    int posX = x;
    for (int i = 0; i < text.length; i++) {
      // Dibujar un punto por cada caracter (representación simple)
      _drawCircle(image, posX, y, 2, color);
      posX += 10;
    }
  }
  
  Future<img.Image> _applyTreatment(
    img.Image original, 
    Face face, 
    String treatmentType, 
    double intensity
  ) async {
    // Copia la imagen para modificarla
    final img.Image result = img.copyResize(
      original, 
      width: original.width, 
      height: original.height
    );
    
    switch (treatmentType.toLowerCase()) {
      case 'aumento de labios':
        return _applyLipEnhancementAdvanced(result, face, intensity);
      case 'rinomodelación':
        return _applyNoseReshaping(result, face, intensity);
      case 'rejuvenecimiento':
        return _applySkinRejuvenation(result, face, intensity);
      case 'botox':
        return _applyBotoxEffect(result, face, intensity);
      default:
        return original; // Sin cambios si no hay tratamiento específico
    }
  }
  
    // Función para convertir Point<int> a Offset
  List<Offset> _pointsToOffsets(List<dynamic>? points) {
    if (points == null) return [];
    return points.map((point) => Offset(point.x.toDouble(), point.y.toDouble())).toList();
  }

  // Versión mejorada para aumento de labios con resultados ultra naturales
  img.Image _applyLipEnhancementAdvanced(img.Image image, Face face, double intensity) {
    // Verificar contornos de labios disponibles
    final upperLipTop = face.contours[FaceContourType.upperLipTop];
    final upperLipBottom = face.contours[FaceContourType.upperLipBottom];
    final lowerLipTop = face.contours[FaceContourType.lowerLipTop];
    final lowerLipBottom = face.contours[FaceContourType.lowerLipBottom];
    
    if (upperLipTop == null || upperLipBottom == null || 
        lowerLipTop == null || lowerLipBottom == null) {
      return image;
    }

    // 1. Crear máscaras separadas para labio superior e inferior
    final lipMask = img.Image(width: image.width, height: image.height, numChannels: 1);
    final upperLipMask = img.Image(width: image.width, height: image.height, numChannels: 1);
    final lowerLipMask = img.Image(width: image.width, height: image.height, numChannels: 1);
    
    // Rellenar máscaras
    _fillPolygon(upperLipMask, [..._pointsToOffsets(upperLipTop.points), ..._pointsToOffsets(upperLipBottom.points).reversed], 255);
    _fillPolygon(lowerLipMask, [..._pointsToOffsets(lowerLipTop.points), ..._pointsToOffsets(lowerLipBottom.points).reversed], 255);
    _fillPolygon(lipMask, [..._pointsToOffsets(upperLipTop.points), ..._pointsToOffsets(upperLipBottom.points).reversed], 255);
    _fillPolygon(lipMask, [..._pointsToOffsets(lowerLipTop.points), ..._pointsToOffsets(lowerLipBottom.points).reversed], 255);
    
    // 2. Crear imagen resultado
    final result = img.Image(width: image.width, height: image.height);
    img.compositeImage(result, image); 
    
    // 3. Calcular centros
    Offset upperCenter = _calculateWeightedCenter(_pointsToOffsets(upperLipTop.points), _pointsToOffsets(upperLipBottom.points));
    Offset lowerCenter = _calculateWeightedCenter(_pointsToOffsets(lowerLipTop.points), _pointsToOffsets(lowerLipBottom.points));
    
    // 4. Calcular vector de desplazamiento natural para cada labio
    Offset upperDirection = Offset(0, -1.0); // Hacia arriba
    Offset lowerDirection = Offset(0, 1.0);  // Hacia abajo
    
    // 5. Aplicar desplazamiento adaptativo (más natural en los bordes)
    const int margin = 5; // Margen de seguridad
    for (int y = margin; y < image.height - margin; y++) {
      for (int x = margin; x < image.width - margin; x++) {
        // Verificar si estamos en labio superior o inferior
        bool inUpperLip = upperLipMask.getPixel(x, y)[0] > 0;
        bool inLowerLip = lowerLipMask.getPixel(x, y)[0] > 0;
        
        if (inUpperLip || inLowerLip) {
          // Seleccionar centro y dirección según el labio
          Offset center = inUpperLip ? upperCenter : lowerCenter;
          Offset direction = inUpperLip ? upperDirection : lowerDirection;
          
          // Calcular distancia al centro del labio
          double dx = x - center.dx;
          double dy = y - center.dy;
          double distToCenter = math.sqrt(dx * dx + dy * dy);
          
          // Calcular distancia al borde del labio en la dirección de desplazamiento
          double distToBorder = _calculateDistanceToBorder(x, y, direction, 
              inUpperLip ? upperLipMask : lowerLipMask);
          
          // Factor de desplazamiento que disminuye cerca del borde
          double displaceFactor = (1.0 - math.pow(distToBorder / 20.0, 2)).clamp(0.0, 1.0);
          double maxDisplacement = intensity * 5.0 * displaceFactor;
          
          // Aplicar desplazamiento no lineal para efecto 3D natural
          double actualDisplacement = maxDisplacement * (1.0 - math.exp(-distToCenter / 15.0));
          
          // Coordenadas de origen para el pixel
          int srcX = (x - direction.dx * actualDisplacement).round();
          int srcY = (y - direction.dy * actualDisplacement).round();
          
          // Verificar límites
          if (srcX >= 0 && srcX < image.width && srcY >= 0 && srcY < image.height) {
            result.setPixel(x, y, image.getPixel(srcX, srcY));
          }
        }
      }
    }
    
    // 6. Aplicar mejoras de color para labios más realistas
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (lipMask.getPixel(x, y).r > 0) {  // Usar .r en lugar de [0]
          // Obtener los valores de pixel actuales
          final pixelColor = result.getPixel(x, y);
          
          // Convertir a HSV (usando propiedades del objeto Pixel)
          List<double> hsv = _rgbToHsv([
            pixelColor.r.toInt(), // Asegurar que sean int
            pixelColor.g.toInt(), // Asegurar que sean int
            pixelColor.b.toInt()  // Asegurar que sean int
          ]);
          
          // Aumentar ligeramente la saturación para labios más vivos
          hsv[1] = math.min(1.0, hsv[1] + intensity * 0.1);
          
          // Aumentar ligeramente el brillo
          hsv[2] = math.min(1.0, hsv[2] + intensity * 0.05);
          
          // Convertir de vuelta a RGB
          List<int> enhancedColor = _hsvToRgb(hsv);
          
          // Preservar canal alpha
          // Crear un nuevo Pixel con los colores mejorados
          result.setPixel(x, y, img.ColorRgba8(
            enhancedColor[0],  // r
            enhancedColor[1],  // g
            enhancedColor[2],  // b
            pixelColor.a.toInt()  // a - preservar alpha original (convertido a int)
          ));
        }
      }
    }
    
    // 7. Suavizar bordes para transición natural
    return _smoothEdges(result, lipMask, image);
  }

  // Calcular centro de labio ponderado para forma más natural
  Offset _calculateWeightedCenter(List<Offset> topPoints, List<Offset> bottomPoints) {
    double sumX = 0, sumY = 0;
    int count = 0;
    
    // Dar más peso a los puntos del medio
    for (int i = 0; i < topPoints.length; i++) {
      double weight = 1.0 - (2.0 * (i - topPoints.length / 2).abs() / topPoints.length);
      weight = math.max(0.1, weight); // Mínimo peso
      
      sumX += topPoints[i].dx * weight;
      sumY += topPoints[i].dy * weight;
      count += weight.round();
    }
    
    for (int i = 0; i < bottomPoints.length; i++) {
      double weight = 1.0 - (2.0 * (i - bottomPoints.length / 2).abs() / bottomPoints.length);
      weight = math.max(0.1, weight);
      
      sumX += bottomPoints[i].dx * weight;
      sumY += bottomPoints[i].dy * weight;
      count += weight.round();
    }
    
    return Offset(sumX / count, sumY / count);
  }

  // Calcular distancia al borde en una dirección específica
  double _calculateDistanceToBorder(int x, int y, Offset direction, img.Image mask) {
    double distance = 0;
    int maxDistance = 30; // Límite de búsqueda
    
    for (int i = 1; i <= maxDistance; i++) {
      int checkX = (x + direction.dx * i).round();
      int checkY = (y + direction.dy * i).round();
      
      if (checkX < 0 || checkX >= mask.width || checkY < 0 || checkY >= mask.height || 
          mask.getPixel(checkX, checkY)[0] == 0) {
        distance = i - 1;
        break;
      }
    }
    
    return distance;
  }

  void _dilateImage(img.Image image, int radius) {
    // Create a temporary copy of the original image
    final original = img.Image(width: image.width, height: image.height, numChannels: image.numChannels);
    img.compositeImage(original, image);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int maxValue = 0;
        
        // Find maximum value in the neighborhood
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            int nx = x + dx;
            int ny = y + dy;
            
            if (nx >= 0 && nx < original.width && ny >= 0 && ny < original.height) {
              final pixel = original.getPixel(nx, ny);
              int pixelValue = pixel.r.toInt(); // CORREGIDO: usar .r y .toInt()
              maxValue = math.max(maxValue, pixelValue);
            }
          }
        }
        
        // Set the maximum value (dilation)
        image.setPixel(x, y, img.ColorRgba8(maxValue, 0, 0, 255));
      }
    }
  }

  // Función para suavizar bordes
  img.Image _smoothEdges(img.Image result, img.Image mask, img.Image original) {
    // Diluir los bordes para transición suave
    final dilatedMask = img.Image(width: mask.width, height: mask.height, numChannels: 1);
    img.compositeImage(dilatedMask, mask);
    _dilateImage(dilatedMask, 3);
    
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final originalColor = original.getPixel(x, y);
        final resultColor = result.getPixel(x, y);
        final maskValue = mask.getPixel(x, y)[0];
        final dilatedValue = dilatedMask.getPixel(x, y)[0];
        
        // Si estamos en el borde dilatado pero no en la máscara original, aplicar blend
        if (dilatedValue > 0 && maskValue == 0) {
          final blendFactor = dilatedValue / 255.0;
          
          // Convertir Pixel a List<int> antes de llamar a _blendColors
          final originalRgba = [originalColor.r.toInt(), originalColor.g.toInt(), originalColor.b.toInt(), originalColor.a.toInt()];
          final resultRgba = [resultColor.r.toInt(), resultColor.g.toInt(), resultColor.b.toInt(), resultColor.a.toInt()];
          
          final blendedColor = _blendColors(originalRgba, resultRgba, 1.0 - blendFactor);
          
          result.setPixel(x, y, img.ColorRgba8(
            blendedColor[0],  // r
            blendedColor[1],  // g
            blendedColor[2],  // b
            blendedColor.length > 3 ? blendedColor[3] : 255  // a
          ));
        }
      }
    }
    
    return result;
  }
  
  // Función para verificar si un punto está en el área de los labios
  bool _isPointInLipArea(double x, double y, List<Offset> upperPoints, List<Offset> lowerPoints) {
    // Creamos un polígono completo con los puntos de los labios
    final List<Offset> lipPolygon = [...upperPoints, ...lowerPoints.reversed];
    
    // Algoritmo ray-casting para determinar si el punto está dentro del polígono
    bool isInside = false;
    int j = lipPolygon.length - 1;
    
    for (int i = 0; i < lipPolygon.length; i++) {
      if ((lipPolygon[i].dy > y) != (lipPolygon[j].dy > y) &&
          (x < lipPolygon[i].dx + (lipPolygon[j].dx - lipPolygon[i].dx) * 
          (y - lipPolygon[i].dy) / (lipPolygon[j].dy - lipPolygon[i].dy))) {
        isInside = !isInside;
      }
      j = i;
    }
    
    return isInside;
  }
  
    // Implementaciones para otros tratamientos
  img.Image _applyNoseReshaping(img.Image image, Face face, double intensity) {
    // Obtener los puntos del contorno de la nariz
    final noseBottom = face.landmarks[FaceLandmarkType.noseBase];
    final noseBridge = face.contours[FaceContourType.noseBridge];
    
    if (noseBottom == null || noseBridge == null) {
      return image;
    }
    
    // Puntos de referencia para nariz
    final noseBasePoint = noseBottom.position;
    final noseBridgePoints = noseBridge.points;
    
    // Calcular punto más alto del puente
    Offset noseTip = Offset(
      noseBridgePoints[noseBridgePoints.length ~/ 2].x.toDouble(),
      noseBridgePoints[noseBridgePoints.length ~/ 2].y.toDouble()
    );

    
    // Crear copia de la imagen para modificar
    final result = img.Image(width: image.width, height: image.height);
    img.compositeImage(result, image);
    
    // Obtener puntos laterales de la nariz usando contornos faciales
    final faceOval = face.contours[FaceContourType.face];
    if (faceOval == null) return image;
    
    // Estimar ancho de nariz estimado (ajustar según precisión de ML Kit)
    Offset noseBaseOffset = Offset(noseBasePoint.x.toDouble(), noseBasePoint.y.toDouble());
    double noseWidth = (noseBaseOffset.dx - noseTip.dx) * 2.5;
    
    // Crear máscara del área nasal
    final noseMask = img.Image(width: image.width, height: image.height, numChannels: 1);
    
    // Definir polígono de la nariz
    List<Offset> nosePolygon = [];
    
    // Punto central superior de la nariz (entrecejo)
        Offset noseBridgeTop = Offset(
      noseBridgePoints.first.x.toDouble(), 
      noseBridgePoints.first.y.toDouble()
    );
    
    // Estimar puntos laterales
    Offset leftNostril = Offset(noseBaseOffset.dx - noseWidth/2, noseBaseOffset.dy);
    Offset rightNostril = Offset(noseBaseOffset.dx + noseWidth/2, noseBaseOffset.dy);
    
    // Crear forma aproximada de la nariz
    nosePolygon.add(noseBridgeTop);
    // Agregar puntos laterales izquierdos
    nosePolygon.add(Offset(leftNostril.dx - noseWidth*0.2, leftNostril.dy - noseWidth*0.5));
    nosePolygon.add(leftNostril);
    // Agregar base de la nariz
    nosePolygon.add(noseBaseOffset);
    // Agregar puntos laterales derechos
    nosePolygon.add(rightNostril);
    nosePolygon.add(Offset(rightNostril.dx + noseWidth*0.2, rightNostril.dy - noseWidth*0.5));
    
    // Dibujar el área nasal en la máscara
    _fillPolygon(noseMask, nosePolygon, 255);
    
    // Vector de transformación según tipo de rinomodelación
    double bridgeRaise = intensity * 0.15; // Elevación del puente
    double tipRaise = intensity * 0.1;    // Elevación de la punta
    double narrowing = intensity * 0.2;   // Estrechamiento lateral
    
    // Aplicar transformación nasal
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (noseMask.getPixel(x, y)[0] > 0) {
      
          // Convertir el punto del puente nasal a Offset
          Offset noseBridgeOffset = Offset(
            noseBridgePoints.first.x.toDouble(), 
            noseBridgePoints.first.y.toDouble()
          );

          // Usar las propiedades correctas de los objetos Offset
          double relY = (y - noseBridgeOffset.dy) / (noseBaseOffset.dy - noseBridgeOffset.dy);
          double relX = (x - noseBaseOffset.dx) / (noseWidth/2);
          // Calcular transformación vertical (puente)
          double verticalEffect = 0;
          if (relY >= 0 && relY <= 1) {
            // Efecto de arco en el puente (máximo en el medio)
            verticalEffect = bridgeRaise * math.sin(relY * math.pi);
          }
          
          // Calcular transformación horizontal (estrechamiento)
          double horizontalEffect = 0;
          if ((relX).abs() < 1.0) {  // Use Dart's built-in .abs() method on a double
            // Estrechamiento proporcional a la distancia del centro
            horizontalEffect = narrowing * relX * relX * (relX < 0 ? 1 : -1);
          }
          
          // Transformar puntos proporcionalmente según su posición
          int srcX = (x + horizontalEffect * noseWidth).round();
          int srcY = (y + verticalEffect * (noseBaseOffset.dy - noseBridgeOffset.dy)).round();
          
          // Verificar límites
          if (srcX >= 0 && srcX < image.width && srcY >= 0 && srcY < image.height) {
            result.setPixel(x, y, image.getPixel(srcX, srcY));
          }
        }
      }
    }
    
    // Suavizar bordes para efecto natural
    return _smoothEdges(result, noseMask, image);
  }
  
  img.Image _applySkinRejuvenation(img.Image image, Face face, double intensity) {
    // Crear imagen de resultado
    var result = img.Image(width: image.width, height: image.height);
    img.compositeImage(result, image);
    
    // Crear máscara facial (excluir ojos, boca, etc.)
    final faceMask = img.Image(width: image.width, height: image.height, numChannels: 1);
    
    // Obtener contorno facial completo
    final faceOval = face.contours[FaceContourType.face];
    if (faceOval == null) return image;
    
    // Dibujar contorno facial en la máscara
    _fillPolygon(faceMask, _pointsToOffsets(faceOval.points), 255);
    
    // Excluir ojos y boca de la máscara
    _excludeFeatureFromMask(faceMask, _pointsToOffsets(face.contours[FaceContourType.leftEye]?.points));
    _excludeFeatureFromMask(faceMask, _pointsToOffsets(face.contours[FaceContourType.rightEye]?.points));
    _excludeFeatureFromMask(faceMask, [
      ..._pointsToOffsets(face.contours[FaceContourType.upperLipTop]?.points), 
      ..._pointsToOffsets(face.contours[FaceContourType.lowerLipBottom]?.points).reversed
    ]);
    // Crear versión suavizada para piel
    img.Image smoothedSkin = img.Image(width: image.width, height: image.height);
    img.compositeImage(result, image);
    
    // Aplicar suavizado bilateral para preservar bordes
    smoothedSkin = _bilateralFilter(smoothedSkin, radius: (intensity * 5).round(), 
                                sigmaColor: 30.0, sigmaSpace: 30.0);
    
    // Crear máscara para arrugas
    img.Image wrinkleMask = _detectWrinkles(image, face);
    
    // Aplicar corrección de tono y textura
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (faceMask.getPixel(x, y)[0] > 0) {
          final originalPixel = image.getPixel(x, y);
          final smoothPixel = smoothedSkin.getPixel(x, y);
          final wrinkleValue = wrinkleMask.getPixel(x, y)[0] / 255.0;

          // Intensidad adicional para áreas con arrugas
          double blendFactor = intensity * (0.5 + wrinkleValue * 0.5);

          // Asegurar que no superamos 1.0
          blendFactor = math.min(blendFactor, 1.0);

          // Convertir Pixel a List<int> antes de llamar a _blendColors
          final originalRgba = [originalPixel.r.toInt(), originalPixel.g.toInt(), originalPixel.b.toInt(), originalPixel.a.toInt()];
          final smoothRgba = [smoothPixel.r.toInt(), smoothPixel.g.toInt(), smoothPixel.b.toInt(), smoothPixel.a.toInt()];

          // Mezclar pixeles originales con suavizados
          final blendedColor = _blendColors(originalRgba, smoothRgba, blendFactor);
        }
      }
    }
    
    // Aplicar toque final de brillo y contraste
    result = _adjustBrightnessContrast(result, brightness: intensity * 0.05, contrast: intensity * 0.1);
    
    return result;
  }

  // Función para excluir características faciales de la máscara
  void _excludeFeatureFromMask(img.Image mask, List<Offset>? featurePoints) {
    if (featurePoints == null || featurePoints.isEmpty) return;
    _fillPolygon(mask, featurePoints, 0); // 0 = excluir
  }

  // Detección de arrugas basada en gradientes de la imagen
  img.Image _detectWrinkles(img.Image image, Face face) {
    final wrinkleMask = img.Image(width: image.width, height: image.height, numChannels: 1);
    
    // Convertir a escala de grises para análisis
    final grayImage = img.grayscale(image);
    
    // Aplicar filtro de bordes para detectar cambios bruscos de intensidad (arrugas)
    final edges = img.sobel(grayImage);
    
    // Crear mapa de posibles arrugas según edad detectada
    final double smileScore = face.smilingProbability ?? 0;
    
    // Definir regiones con más probabilidad de arrugas
    final faceContour = face.contours[FaceContourType.face];
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    
    if (faceContour == null || leftEye == null || rightEye == null || nose == null) {
      return wrinkleMask;
    }
    
    // Función para acentuar arrugas en una región específica
    void accentuateWrinklesInRegion(Rect region, double factor) {
      for (int y = region.top.round(); y < region.bottom.round(); y++) {
        for (int x = region.left.round(); x < region.right.round(); x++) {
          if (x >= 0 && x < edges.width && y >= 0 && y < edges.height) {
            final edgeValue = edges.getPixel(x, y)[0];
            int wrinkleValue = math.min(255, (edgeValue * factor).round());
            wrinkleMask.setPixel(x, y, img.ColorRgba8(wrinkleValue, 0, 0, 255));
          }
        }
      }
    }
    
      // Región de "patas de gallo" (ojos)
      accentuateWrinklesInRegion(
        Rect.fromCenter(
          center: Offset(
            leftEye.position.x.toDouble() + (leftEye.position.x * 0.15),
            leftEye.position.y.toDouble()
          ),
          width: leftEye.position.x * 0.4,
          height: leftEye.position.y * 0.3
        ),
        1.5 + smileScore * 0.5
      );
      
      accentuateWrinklesInRegion(
        Rect.fromCenter(
          center: Offset(
            rightEye.position.x.toDouble() - (rightEye.position.x * 0.15),
            rightEye.position.y.toDouble()
          ),
          width: rightEye.position.x * 0.4,
          height: rightEye.position.y * 0.3
        ),
        1.5 + smileScore * 0.5
      );
      
      // Región nasolabial
      accentuateWrinklesInRegion(
        Rect.fromCenter(
          center: Offset(
            nose.position.x.toDouble() + (nose.position.x * 0.3),
            nose.position.y.toDouble() + (nose.position.y * 0.3)
          ),
          width: nose.position.x * 0.3,
          height: nose.position.y * 0.6
        ),
        1.2 + smileScore * 0.7
      );
    
      accentuateWrinklesInRegion(
        Rect.fromCenter(
          center: Offset(
            nose.position.x.toDouble() + (nose.position.x * 0.3),
            nose.position.y.toDouble() + (nose.position.y * 0.3)
          ),
          width: nose.position.x * 0.3,
          height: nose.position.y * 0.6
        ),
        1.2 + smileScore * 0.7
      );
    
    // Región frente
      accentuateWrinklesInRegion(
        Rect.fromCenter(
          center: Offset(
            (leftEye.position.x + rightEye.position.x) / 2.0, 
            faceContour.points[0].y + (leftEye.position.y - faceContour.points[0].y) / 2.0
          ).translate(0, 0),
          width: (rightEye.position.x - leftEye.position.x) * 1.5,
          height: (leftEye.position.y - faceContour.points[0].y) * 0.8
        ),
        0.9
      );
    
    return wrinkleMask;
  }

  img.Image _applyBotoxEffect(img.Image image, Face face, double intensity) {
    // Crear imagen resultado
    final result = img.Image(width: image.width, height: image.height);
    img.compositeImage(result, image);
    
    // Áreas específicas para aplicación de botox
    final botoxAreas = <String, Rect>{};
    
    // Configurar regiones para Botox basadas en landmarks faciales
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final leftEyebrow = face.contours[FaceContourType.leftEyebrowTop];
    final rightEyebrow = face.contours[FaceContourType.rightEyebrowTop];
    final faceContour = face.contours[FaceContourType.face];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    
    if (leftEye == null || rightEye == null || leftEyebrow == null || 
        rightEyebrow == null || faceContour == null || nose == null) {
      return image;
    }
    
    // Región entrecejo (glabela)
    botoxAreas['glabela'] = Rect.fromCenter(
      center: Offset(
        (leftEye.position.x + rightEye.position.x) / 2, 
        (leftEyebrow.points.last.y + rightEyebrow.points.first.y) / 2
      ),
      width: (rightEye.position.x - leftEye.position.x) * 0.4,
      height: leftEye.position.y * 0.3
    );
    
    // Región frente
    botoxAreas['forehead'] = Rect.fromLTRB(
      leftEyebrow.points.first.x.toDouble(),
      faceContour.points[0].y.toDouble(),
      rightEyebrow.points.last.x.toDouble(),
      (leftEyebrow.points.first.y + rightEyebrow.points.first.y) / 2.0
    );
    
    // Región patas de gallo (ojos)
    botoxAreas['crows_left'] = Rect.fromCenter(
      center: Offset(
        leftEye.position.x.toDouble() + (leftEye.position.x * 0.2),
        leftEye.position.y.toDouble()
      ),
      width: leftEye.position.x * 0.5,
      height: leftEye.position.y * 0.5
    );
    
    botoxAreas['crows_right'] = Rect.fromCenter(
      center: Offset(
        rightEye.position.x.toDouble() - (rightEye.position.x * 0.2),
        rightEye.position.y.toDouble()
      ),
      width: rightEye.position.x * 0.5,
      height: rightEye.position.y * 0.5
    );

    // Crear máscara para detección de arrugas en esas áreas
    img.Image wrinkleMask = _detectWrinkles(image, face);
    
    // Por cada área de aplicación de Botox
    botoxAreas.forEach((areaName, rect) {
      // Crear máscara para esta área específica
      img.Image areaMask = img.Image(width: image.width, height: image.height, numChannels: 1);
      
      // Rellenar el área en la máscara
      for (int y = rect.top.round(); y <= rect.bottom.round(); y++) {
        for (int x = rect.left.round(); x <= rect.right.round(); x++) {
          if (x >= 0 && x < areaMask.width && y >= 0 && y < areaMask.height) {
            areaMask.setPixel(x, y, img.ColorRgba8(255, 0, 0, 255));
          }
        }
      }
      
      // Factores de efecto específicos para cada área
      double smoothFactor = intensity;
      if (areaName == 'glabela') smoothFactor *= 1.3; // Efecto más fuerte en entrecejo
      if (areaName == 'forehead') smoothFactor *= 1.0; // Normal en frente
      if (areaName.contains('crows')) smoothFactor *= 1.2; // Fuerte en patas de gallo
      
      // Versión suavizada de esta región
      img.Image smoothedArea = img.Image(width: image.width, height: image.height);
      img.compositeImage(smoothedArea, image);
      
      // Suavizado gaussiano adaptativo (más suave donde hay arrugas)
      smoothedArea = _bilateralFilter(smoothedArea, radius: (3 + intensity * 3).round(), 
                                    sigmaColor: 15.0 + intensity * 15.0, 
                                    sigmaSpace: 15.0 + intensity * 15.0);
      
      // Aplicar el efecto solo en las áreas con arrugas dentro de la región definida
      for (int y = rect.top.round(); y <= rect.bottom.round(); y++) {
        for (int x = rect.left.round(); x <= rect.right.round(); x++) {
          if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
            final originalColor = image.getPixel(x, y);
            final smoothColor = smoothedArea.getPixel(x, y);
            final wrinkleValue = wrinkleMask.getPixel(x, y)[0] / 255.0;
            
            // Factor de mezcla basado en intensidad de arrugas
            final blendFactor = math.min(1.0, smoothFactor * (0.3 + wrinkleValue * 0.7));
            
            // Aplicamos la mezcla si hay arrugas considerables
            if (wrinkleValue > 0.15) {
              final originalRgba = [originalColor.r.toInt(), originalColor.g.toInt(), originalColor.b.toInt(), originalColor.a.toInt()];
              final smoothRgba = [smoothColor.r.toInt(), smoothColor.g.toInt(), smoothColor.b.toInt(), smoothColor.a.toInt()];
              final blendedColor = _blendColors(originalRgba, smoothRgba, blendFactor);

              result.setPixel(x, y, img.ColorRgba8(
                blendedColor[0],  // r
                blendedColor[1],  // g
                blendedColor[2],  // b
                blendedColor.length > 3 ? blendedColor[3] : 255  // a
              ));
            }
          }
        }
      }
    });
    
    // Ajuste sutil de luz para simular piel más tersa
    return _adjustBrightnessContrast(result, brightness: intensity * 0.05, contrast: intensity * 0.05);
  }

  // Guardar la imagen procesada
  Future<String> _saveProcessedImage(img.Image processedImage) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'treatment_simulation_${DateTime.now().millisecondsSinceEpoch}.png';
    final File file = File('${tempDir.path}/$fileName');
    
    await file.writeAsBytes(img.encodePng(processedImage));
    return file.path;
  }
  
  // Funciones auxiliares
  double sqrt(double value) {
    return math.sqrt(value);
  }
  
  // Asegúrate de liberar recursos
  void dispose() {
    _faceDetector.close();
  }

  // Implementación de relleno de polígono
  void _fillPolygon(img.Image image, List<Offset> points, int value) {
    if (points.isEmpty) return;
    
    // Encontrar los límites del polígono
    double minX = double.infinity;
    double maxX = double.negativeInfinity;
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    
    for (final point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    
    // Limitar al tamaño de la imagen
    minX = math.max(0, minX.floor().toDouble());
    minY = math.max(0, minY.floor().toDouble());
    maxX = math.min(image.width - 1, maxX.ceil().toDouble());
    maxY = math.min(image.height - 1, maxY.ceil().toDouble());
    
    // Algoritmo de relleno scanline
    for (int y = minY.toInt(); y <= maxY; y++) {
      List<double> nodeX = [];
      
      // Crear lista de intersecciones
      int j = points.length - 1;
      for (int i = 0; i < points.length; i++) {
        if ((points[i].dy <= y && points[j].dy > y) || 
            (points[j].dy <= y && points[i].dy > y)) {
          nodeX.add(points[i].dx + 
            (points[j].dx - points[i].dx) * 
            (y - points[i].dy) / 
            (points[j].dy - points[i].dy));
        }
        j = i;
      }
      
      // Ordenar intersecciones
      nodeX.sort();
      
      // Rellenar pares de intersecciones
      for (int i = 0; i < nodeX.length; i += 2) {
        if (i + 1 < nodeX.length) {
          int startX = math.max(0, nodeX[i].round());
          int endX = math.min(image.width - 1, nodeX[i + 1].round());
          
          for (int x = startX; x <= endX; x++) {
            final pixel = image.getPixel(x, y);
            // Crear un nuevo ColorRgba8 conservando los otros canales
            image.setPixel(x, y, img.ColorRgba8(
              value,                 // r (o valor para canal único)
              pixel.g.toInt(),       // g 
              pixel.b.toInt(),       // b
              pixel.a.toInt()        // a
            ));
          }
        }
      }
    }
  }

  // Implementación de mezcla de colores
  List<int> _blendColors(List<int> color1, List<int> color2, double factor) {
    List<int> result = [];
    for (int i = 0; i < math.min(color1.length, color2.length); i++) {
      result.add((color1[i] * (1 - factor) + color2[i] * factor).round().clamp(0, 255));
    }
    return result;
  }

  // Conversión RGB a HSV
  List<double> _rgbToHsv(List<int> rgb) {
    double r = rgb[0] / 255.0;
    double g = rgb[1] / 255.0;
    double b = rgb[2] / 255.0;
    
    double max = math.max(r, math.max(g, b));
    double min = math.min(r, math.min(g, b));
    double delta = max - min;
    
    double h = 0;
    double s = max == 0 ? 0 : delta / max;
    double v = max;
    
    if (delta == 0) {
      h = 0;
    } else if (max == r) {
      h = ((g - b) / delta) % 6;
    } else if (max == g) {
      h = ((b - r) / delta) + 2;
    } else {
      h = ((r - g) / delta) + 4;
    }
    
    h = (h * 60) % 360;
    if (h < 0) h += 360;
    
    return [h, s, v];
  }

  // Conversión HSV a RGB
  List<int> _hsvToRgb(List<double> hsv) {
    double h = hsv[0];
    double s = hsv[1];
    double v = hsv[2];
    
    double c = v * s;
    double x = c * (1 - (((h / 60) % 2) - 1).abs());
    double m = v - c;
    
    List<double> rgb = [];
    
    if (h < 60) {
      rgb = [c, x, 0];
    } else if (h < 120) {
      rgb = [x, c, 0];
    } else if (h < 180) {
      rgb = [0, c, x];
    } else if (h < 240) {
      rgb = [0, x, c];
    } else if (h < 300) {
      rgb = [x, 0, c];
    } else {
      rgb = [c, 0, x];
    }
    
    return [
      ((rgb[0] + m) * 255).round().clamp(0, 255),
      ((rgb[1] + m) * 255).round().clamp(0, 255),
      ((rgb[2] + m) * 255).round().clamp(0, 255),
    ];
  }

  // Implementación del filtro bilateral para preservar bordes
  img.Image _bilateralFilter(img.Image image, {
    int radius = 5,
    double sigmaColor = 20.0,
    double sigmaSpace = 20.0,
  }) {
    final result = img.Image(width: image.width, height: image.height);
    
    // Varianzas para espacio y color
    double varColor = sigmaColor * sigmaColor * 2;
    double varSpace = sigmaSpace * sigmaSpace * 2;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final centerColor = image.getPixel(x, y);
        
        double sumR = 0, sumG = 0, sumB = 0, sumWeight = 0;
        
        for (int ky = -radius; ky <= radius; ky++) {
          for (int kx = -radius; kx <= radius; kx++) {
            int nx = x + kx;
            int ny = y + ky;
            
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final neighborColor = image.getPixel(nx, ny);
              
              // Calcular diferencia espacial
              double spatialDist = (kx * kx + ky * ky).toDouble();
              double spatialWeight = math.exp(-spatialDist / varSpace);

              // Calcular diferencia de color
              double colorDist = 0;
              for (int i = 0; i < 3; i++) {
                double diff = (centerColor[i] - neighborColor[i]).toDouble();
                colorDist += diff * diff;
              }
              double colorWeight = math.exp(-colorDist / varColor);
              
              // Peso combinado
              double weight = spatialWeight * colorWeight;
              
              // Acumular valores ponderados
              sumR += neighborColor[0] * weight;
              sumG += neighborColor[1] * weight;
              sumB += neighborColor[2] * weight;
              sumWeight += weight;
            }
          }
        }
        
        // Normalizar valores
        if (sumWeight > 0) {
          result.setPixel(x, y, img.ColorRgba8(
            (sumR / sumWeight).round().clamp(0, 255),
            (sumG / sumWeight).round().clamp(0, 255),
            (sumB / sumWeight).round().clamp(0, 255),
            centerColor.a.toInt()  // Usar la propiedad .a directamente
          ));
        }
      }
    }
    
    return result;
  }

  // Ajuste de brillo y contraste
  img.Image _adjustBrightnessContrast(img.Image image, {double brightness = 0.0, double contrast = 0.0}) {
    final result = img.Image(width: image.width, height: image.height);
    img.compositeImage(result, image);
    
    // Factor de contraste
    double factor = (259.0 * (contrast + 1.0)) / (255.0 * (1.0 - contrast));
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        
        // Convertir los valores a una lista para procesarlos
        List<int> colorValues = [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        List<int> newPixel = [];
        
        for (int i = 0; i < 3; i++) {
          // Aplicar contraste
          int value = colorValues[i];
          value = ((factor * (value - 128)) + 128).round();
          
          // Aplicar brillo
          value += (brightness * 255).round();
          
          // Asegurar rango válido
          value = value.clamp(0, 255);
          newPixel.add(value);
        }
        
        // Mantener alpha
        int alpha = pixel.a.toInt();
        
        result.setPixel(x, y, img.ColorRgba8(
          newPixel[0],
          newPixel[1],
          newPixel[2],
          alpha
        ));
      }
    }
    
    return result;
  }
  
}