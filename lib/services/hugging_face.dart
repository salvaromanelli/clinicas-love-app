import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class HuggingFaceService {
  // Modo de demostración para desarrollo
  bool _useDemoMode = false; // Cambiar a true para modo demo
  
  // API Key de Hugging Face
  static const String apiKey = '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'; // Reemplazar con tu API key
  
  // Modelo más adecuado para modificación de imágenes
  static const String apiEndpoint = 
    'https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-xl-refiner-1.0';
  
  
  /// Procesa una imagen con el modelo seleccionado
  Future<File> processImage({
    required File inputImage,
    required String prompt,
    double strength = 0.5,
    String negativePrompt = 'deformed, distorted, disfigured, bad anatomy, unrealistic, different person, different face, different identity, changed appearance, different age, different gender, different ethnicity, different hairstyle, different eye color, different skin tone, different background, different lighting, cartoon, anime, drawing, painting, illustration, CGI, 3d, render',
  }) async {
    try {
      // 1. Leer los bytes de la imagen
      final List<int> imageBytes = await inputImage.readAsBytes();
      
      // 2. Convertir a base64 con método seguro
      final String base64Image = _safeBase64Encode(imageBytes);
      
      // 3. Depuración
      debugPrint('Tamaño de imagen: ${imageBytes.length} bytes');
      
      // 4. Formato correcto para payload según la documentación de Hugging Face
      final Map<String, dynamic> payload = {
        'inputs': base64Image,
        'parameters': {
          'prompt': prompt,
          'negative_prompt': negativePrompt,
          'guidance_scale': 7.5,      // Aumentado para mayor adherencia al prompt
          'strength': strength * 0.4, // Reducir la intensidad para preservar mejor la identidad
          'num_inference_steps': 30,  // Más pasos = más calidad
          'seed': DateTime.now().millisecondsSinceEpoch, // Añadir semilla aleatoria
        },
        'options': {
          'use_cache': false,
          'wait_for_model': true,
        }
      };
      
      // 5. Enviar solicitud
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      // 6. Validar respuesta
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // La API devuelve la imagen directamente como bytes
        final bytes = response.bodyBytes;
        
        // 7. Guardar localmente
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/hf_processed_${DateTime.now().millisecondsSinceEpoch}.png'
        );
        await tempFile.writeAsBytes(bytes);
        
        return tempFile;
      } else if (response.statusCode == 503) {
        // El modelo puede estar cargando
        final Map<String, dynamic> error = jsonDecode(response.body);
        final int? retryAfter = int.tryParse(
          response.headers['retry-after'] ?? error['estimated_time']?.toString() ?? '30'
        );
        
        throw Exception('El modelo está cargando. Intenta nuevamente en $retryAfter segundos');
      } else {
        debugPrint('Error en API: ${response.statusCode} - ${response.body}');
        throw Exception('Error en Hugging Face API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error en HuggingFaceService: $e');
      rethrow;
    }
  }

  // Método mejorado con reintentos automáticos y modo demo
  Future<File> processImageWithRetry({
    required File inputImage,
    required String prompt,
    double strength = 0.5,
    String negativePrompt = 'deformed, distorted, disfigured, bad anatomy, unrealistic, different person, different face, different identity, changed appearance, different age, different gender, different ethnicity, different hairstyle, different eye color',
    int maxRetries = 3,
  }) async {
    // En modo demo, simular procesamiento
    if (_useDemoMode) {
      debugPrint('Usando modo demo - sin llamada real a la API');
      await Future.delayed(const Duration(seconds: 2));
      return inputImage; // Devolver la misma imagen
    }
    
    int attempts = 0;
    final adjustedStrength = strength.clamp(0.3, 0.6);
    
    while (attempts < maxRetries) {
      try {
        debugPrint('Intento #${attempts+1} - Strength: $adjustedStrength');
        
        // Optimizar y preparar la imagen
        File optimizedImage = await _optimizeImageSize(inputImage);
        File processableImage = await _ensureProcessableImage(optimizedImage);
        
        // Procesar imagen
        return await processImage(
          inputImage: processableImage,
          prompt: prompt,
          strength: adjustedStrength,
          negativePrompt: negativePrompt,
        );
      } catch (e) {
        attempts++;
        if (e.toString().contains('está cargando') && attempts < maxRetries) {
          final retryAfter = RegExp(r'(\d+)').firstMatch(e.toString())?.group(1);
          final seconds = int.tryParse(retryAfter ?? '10') ?? 10;
          
          debugPrint('Esperando $seconds segundos antes de reintentar...');
          await Future.delayed(Duration(seconds: seconds));
        } else if (attempts >= maxRetries) {
          throw Exception('Máximo número de intentos alcanzado: $e');
        } else {
          rethrow;
        }
      }
    }
    
    throw Exception('Máximo número de intentos alcanzado');
  }
  
  /// Optimiza el tamaño de imagen para el modelo
  Future<File> _optimizeImageSize(File imageFile) async {
    try {
      final List<int> bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(Uint8List.fromList(bytes));
      
      if (image == null) {
        debugPrint('No se pudo decodificar la imagen');
        return imageFile;
      }
      
      // Redimensionar si es necesario
      if (image.width > 768 || image.height > 768) {
        int newWidth, newHeight;
        if (image.width > image.height) {
          newWidth = 768;
          newHeight = (image.height * 768 / image.width).round();
        } else {
          newHeight = 768;
          newWidth = (image.width * 768 / image.height).round();
        }
        
        final img.Image resized = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
        );
        
        final List<int> jpgBytes = img.encodeJpg(resized, quality: 90);
        final tempDir = await getTemporaryDirectory();
        final optimizedFile = File('${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await optimizedFile.writeAsBytes(jpgBytes);
        
        debugPrint('Imagen optimizada: ${image.width}x${image.height} -> ${newWidth}x${newHeight}');
        return optimizedFile;
      }
      
      return imageFile;
    } catch (e) {
      debugPrint('Error al optimizar imagen: $e');
      return imageFile;
    }
  }
  
  /// Asegura que la imagen esté en un formato procesable por la API
  Future<File> _ensureProcessableImage(File inputImage) async {
    try {
      final String extension = inputImage.path.split('.').last.toLowerCase();
      
      // Si la imagen ya está en JPEG o PNG, usarla directamente
      if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
        return inputImage;
      }
      
      // Convertir a JPEG en caso contrario
      final img.Image? image = img.decodeImage(await inputImage.readAsBytes());
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      
      // Codificar como JPEG
      final List<int> jpegData = img.encodeJpg(image, quality: 90);
      
      // Guardar temporalmente
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/converted_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(jpegData);
      
      return tempFile;
    } catch (e) {
      debugPrint('Error convirtiendo imagen: $e');
      return inputImage; // En caso de error, devolver la original
    }
  }
  
  // Función auxiliar para codificación segura a base64
  String _safeBase64Encode(List<int> bytes) {
    try {
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error en codificación base64 estándar: $e');
      throw Exception('Error codificando imagen: $e');
    }
  }
}