import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReplicateService {
  final String apiKey;
  final String baseUrl = 'https://api.replicate.com/v1';
  
  ReplicateService({required this.apiKey});
  
  // Obtener instancia usando la API key del archivo .env
  factory ReplicateService.fromEnv() {
    final apiKey = dotenv.env['REPLICATE_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('REPLICATE_API_KEY no configurada en el archivo .env');
    }
    return ReplicateService(apiKey: apiKey);
  }
  
  // Encabezados HTTP comunes
  Map<String, String> get _headers => {
    'Authorization': 'Token $apiKey',
    'Content-Type': 'application/json',
  };
  
  // Crear una predicción (enviar imágenes para procesamiento)
  Future<String> createPrediction({
    required String modelVersion,
    required String prompt,
    required String imageBase64,
    required String maskBase64,
    required String controlType,
    double guidance = 7.5,
    int steps = 30,
    int controlMode = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predictions'),
      headers: _headers,
      body: jsonEncode({
        'version': modelVersion,
        'input': {
          'prompt': prompt,
          'image': 'data:image/png;base64,$imageBase64',
          'control_image': 'data:image/png;base64,$maskBase64',
          'control_type': controlType, 
          'guidance_scale': guidance,
          'num_inference_steps': steps,
          'control_mode': controlMode,
          'negative_prompt': 'deformed, distorted, disfigured, poorly drawn, bad anatomy, unrealistic',
        },
      }),
    );
    
    debugPrint('MASK BASE64 LENGTH: ${maskBase64.length}');

    if (response.statusCode != 201) {
      debugPrint('Error en API Replicate: ${response.statusCode}, ${response.body}');
      throw Exception('Error al crear predicción: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['id'] as String;
  }
  
  // Obtener resultado de una predicción
  Future<Map<String, dynamic>> getPrediction(String predictionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/predictions/$predictionId'),
      headers: _headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Error al obtener predicción: ${response.statusCode}');
    }
    
    return jsonDecode(response.body);
  }
  
  // Esperar a que una predicción se complete
  Future<String?> waitForPrediction(String predictionId, {int maxAttempts = 30, int delaySeconds = 3}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(Duration(seconds: delaySeconds));
      
      try {
        final prediction = await getPrediction(predictionId);
        final status = prediction['status'];
        
        if (status == 'succeeded') {
          return prediction['output'][0]; // URL de la imagen resultante
        } else if (status == 'failed') {
          throw Exception('La predicción falló: ${prediction['error']}');
        }
        // Continuar esperando si está en "processing" o "starting"
      } catch (e) {
        debugPrint('Error consultando predicción: $e');
        // Seguir intentando a pesar de errores transitorios
      }
    }
    
    throw Exception('Tiempo de espera agotado para la predicción');
  }
  
  // Obtener una imagen a partir de su URL
  Future<List<int>> downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    
    if (response.statusCode != 200) {
      throw Exception('Error al descargar imagen: ${response.statusCode}');
    }
    
    return response.bodyBytes;
  }

  // Método estático para facilitar el uso con ControlNet
  static Future<String?> sendToControlNet({
    required String apiKey,
    required String base64Image,
    required String base64Mask,
    required String prompt,
    required String versionId,
    required String controlType,
    double guidance = 7.5,
    int numInferenceSteps = 30,
    int controlMode = 0,
  }) async {
    final service = ReplicateService(apiKey: apiKey);
    
    // Crear la predicción con parámetros específicos para ControlNet
    final predictionId = await service.createPrediction(
      modelVersion: versionId,
      prompt: prompt,
      imageBase64: base64Image,
      maskBase64: base64Mask,
      controlType: controlType,
      guidance: guidance,
      steps: numInferenceSteps,
      controlMode: controlMode,
    );
    
    // Esperar y obtener el resultado
    return await service.waitForPrediction(predictionId);
  }

}