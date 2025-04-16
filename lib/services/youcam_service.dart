import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/encryption_utils.dart';



class TreatmentResult {
  final File processedImage;
  final Map<String, dynamic>? metadata;
  final double confidenceScore;
  
  TreatmentResult({
    required this.processedImage, 
    this.metadata, 
    this.confidenceScore = 1.0
  });
}

class YouCamService {
  final String apiKey;
  final String baseUrl = 'https://yce-api-01.perfectcorp.com';
  final bool testMode; 

  // Constructor que acepta el parámetro nombrado apiKey
    YouCamService({
    required this.apiKey, 
    this.testMode = false  // Parámetro opcional con valor predeterminado
  });

  Future<String?> authenticate() async {
    try {
      debugPrint('Iniciando proceso de autenticación con YouCam API');
      final url = Uri.parse('https://yce-api-01.perfectcorp.com/s2s/v1.0/client/auth');
      
      final clientId = dotenv.env['YOUCAM_API_KEY'];
      final secretKey = dotenv.env['YOUCAM_SECRET_KEY'];
      
      if (clientId == null || secretKey == null) {
        debugPrint('Error: YOUCAM_API_KEY o YOUCAM_SECRET_KEY no están configurados');
        return null;
      }
      
      // Generar el id_token mediante encriptación RSA
      final idToken = EncryptionUtils.generateYouCamIdToken(
        clientId: clientId,
        secretKey: secretKey,
      );
      
      if (idToken == null) {
        debugPrint('Error al generar el id_token');
        return null;
      }
      
      debugPrint('id_token generado correctamente');
      
      final Map<String, dynamic> authBody = {
        'client_id': clientId,
        'id_token': idToken
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(authBody),
      );
      
      debugPrint('Respuesta de autenticación: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        debugPrint('Autenticación exitosa. Token: ${accessToken.substring(0, 10)}...');
        return accessToken;
      } else {
        debugPrint('Error al autenticar: ${response.statusCode}, ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Excepción al autenticar: $e');
      return null;
    }
  }

  Future<bool> _isImageCompatible(File imageFile) async {
    try {
      // Verificar formato (según documentación)
      final extension = path.extension(imageFile.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png'].contains(extension)) {
        debugPrint('Formato de archivo no soportado: $extension');
        return false;
      }
      
      // Verificar tamaño máximo (10MB según documentación)
      final fileSize = await imageFile.length();
      final maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        debugPrint('Archivo demasiado grande: ${fileSize / 1024 / 1024}MB (máx: ${maxSize / 1024 / 1024}MB)');
        return false;
      }
      
      // También podrías verificar las dimensiones si la API tiene restricciones
      // Esto requeriría una dependencia como 'image' para leer las dimensiones
      
      return true;
    } catch (e) {
      debugPrint('Error al verificar compatibilidad de imagen: $e');
      return false;
    }
  }

  String _getMimeType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.heic':
      case '.heif':
        return 'image/heic'; // Aunque deberíamos convertir estas antes
      default:
        return 'image/jpeg'; // Por defecto
    }
  }
    
  // Método para aplicar tratamiento a una imagen
  Future<File?> applyTreatment({
    required File image, 
    required String treatmentType,
    Map<String, dynamic>? params, // Opcional ahora
    double intensity = 0.5,
  }) async {
    // En modo de prueba, devolver la misma imagen
    if (testMode) {
      debugPrint('Modo de prueba: simulando aplicación de tratamiento');
      await Future.delayed(const Duration(seconds: 2));
      return image;
    }
    
    // Verificar si es un tratamiento de AI Photo Enhance
    bool isAIEnhanceTreatment = treatmentType.startsWith('face_') || 
                                treatmentType == 'eye_enhance' || 
                                treatmentType == 'skin_retouch';
    
    // Para tratamientos AI, usar el método con JSON
    if (isAIEnhanceTreatment) {
      try {
        // Usar el método que ya funciona con JSON
        final result = await applyTreatmentWithMetadata(
          image: image,
          treatmentType: treatmentType,
          intensity: intensity,
          params: params ?? {},
        );
        
        return result?.processedImage;
      } catch (e) {
        debugPrint('Error al aplicar tratamiento AI: $e');
        return null;
      }
    }
    
    // Usar el mapeo automático si no se proporcionan parámetros
    final effectParams = params ?? _getTreatmentParams(treatmentType, intensity);
    
    try {
      // Verificar si la imagen es compatible
      if (!await _isImageCompatible(image)) {
        debugPrint('La imagen no es compatible para applyTreatment');
        return null;
      }
            
      String endpoint = _getEndpointForTreatment(treatmentType);
      final uri = Uri.parse('$baseUrl$endpoint');
      
      // Crear una solicitud multipart
      final request = http.MultipartRequest('POST', uri);
      
      // Añadir la API key y headers
      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Accept'] = 'application/json';
      debugPrint('Headers: ${request.headers}');
      
      // Añadir la imagen al request
      String filename = path.basename(image.path);
      String mimeType = _getMimeType(image.path);
      debugPrint('Tipo MIME: $mimeType');
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
      
      // Añadir los parámetros del tratamiento
      effectParams.forEach((key, value) {
        request.fields[key] = value.toString();
      });
      debugPrint('Parámetros: ${request.fields}');
      
      // Enviar la solicitud con timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('La solicitud ha excedido el tiempo límite');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('Código de respuesta: ${response.statusCode}');
      debugPrint('Cuerpo de respuesta: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        String? processedImageData;
        if (data.containsKey('image_url')) {
          debugPrint('Descargando imagen desde URL');
          final imageResponse = await http.get(Uri.parse(data['image_url']));
          processedImageData = base64Encode(imageResponse.bodyBytes);
        } else if (data.containsKey('image_base64')) {
          debugPrint('Usando imagen en base64 de la respuesta');
          processedImageData = data['image_base64'];
        } else {
          throw Exception('La API no devolvió datos de imagen');
        }
        
        if (processedImageData != null) {
          // Guardar la imagen procesada en un archivo temporal
          final tempDir = await Directory.systemTemp.createTemp('youcam_results');
          final resultFile = File(
            '${tempDir.path}/result_${DateTime.now().millisecondsSinceEpoch}.jpg'
          );
          
          await resultFile.writeAsBytes(base64Decode(processedImageData));
          debugPrint('Imagen de resultado guardada en: ${resultFile.path}');
          return resultFile;
        }
      } else if (response.statusCode == 500) {
        debugPrint('Error 500 del servidor. Puede ser un problema temporal.');
        // Si es un error del servidor, intentamos devolver la imagen original
        // para que la aplicación no se bloquee
        return image;
      } else {
        debugPrint('Error en applyTreatment: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Excepción en applyTreatment: $e');
    }
    
    return null;
  }

    // Método para extraer metadatos de la respuesta
  Map<String, dynamic>? _extractMetadata(Map<String, dynamic> responseData) {
    final metadata = <String, dynamic>{};
    
    // Extraer datos útiles que podrían estar en la respuesta
    if (responseData.containsKey('face_count')) {
      metadata['faceCount'] = responseData['face_count'];
    }
    
    if (responseData.containsKey('detection_score')) {
      metadata['detectionScore'] = responseData['detection_score'];
    }
    
    if (responseData.containsKey('processing_time')) {
      metadata['processingTime'] = responseData['processing_time'];
    }
    
    return metadata.isNotEmpty ? metadata : null;
  }

  // Caché de resultados para evitar procesamiento repetido
  final Map<String, File> _resultCache = {};

  // Método que intenta usar caché primero
  Future<File?> getFromCacheOrApply({
    required File image,
    required String treatmentType,
    double intensity = 0.5,
    Map<String, dynamic>? params,
  }) async {
    // Crear una clave única para este tratamiento
    final cacheKey = '${image.path}|$treatmentType|$intensity';
    
    // Verificar caché primero
    if (_resultCache.containsKey(cacheKey)) {
      debugPrint('Usando resultado en caché para: $cacheKey');
      return _resultCache[cacheKey];
    }
    
    // Si no está en caché, aplicar tratamiento
    final result = await applyTreatment(
      image: image, 
      treatmentType: treatmentType, 
      intensity: intensity,
      params: params,
    );
    
    // Guardar en caché si es exitoso
    if (result != null) {
      _resultCache[cacheKey] = result;
      debugPrint('Guardado en caché: $cacheKey');
    }
    
    return result;
  }

  Future<TreatmentResult?> applyTreatmentWithMetadata({
    required File image,
    required String treatmentType,
    required double intensity,
    required Map<String, dynamic> params,
  }) async {
    try {
      // PASO 1: Autenticar y obtener un token válido
      String? accessToken = await authenticate();
      
      if (accessToken == null) {
        throw Exception('No se pudo obtener un token de acceso válido');
      }
      
      // El resto del código continúa igual pero usando el token autenticado
      final createUrl = Uri.parse('https://yce-api-01.perfectcorp.com/s2s/v1.0/task/enhance');
      
      // Leer la imagen como bytes y codificar
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      // Estructura EXACTA según la documentación
      final Map<String, dynamic> jsonBody = {
        'request_id': DateTime.now().millisecondsSinceEpoch % 10000, // ID único numérico
        'payload': {
          'image': base64Image,  // Envío directo de la imagen en base64
          'actions': [
            {
              'id': 0, // ID numérico (importante: debe ser un entero, no un string)
              'method': params['method'] ?? 'enhance',
              'part': params['part'] ?? 'face',
              'intensity': intensity,
            }
          ]
        }
      };
      
      // Añadir enhanceType si existe
      if (params.containsKey('enhanceType')) {
        jsonBody['payload']['actions'][0]['enhanceType'] = params['enhanceType'];
      }
      
      final jsonString = jsonEncode(jsonBody);
      
      debugPrint('Enviando solicitud con estructura exacta de documentación');
      
      final response = await http.post(
        createUrl,
        headers: {
          'Authorization': 'Bearer $accessToken', // Usar el token autenticado
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonString,
      );
      
      debugPrint('Código de respuesta: ${response.statusCode}');
      debugPrint('Cuerpo de respuesta: ${response.body}');
      
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw Exception('Error al crear tarea: ${response.statusCode}, ${response.body}');
      }
      
      // Analizar la respuesta para obtener el task_id
      final data = jsonDecode(response.body);
      final String? taskId = data['task_id'];
      
      if (taskId == null) {
        throw Exception('No se recibió task_id en la respuesta');
      }
      
      debugPrint('Tarea creada con éxito. Task ID: $taskId');
      
      // PASO 2: Esperar y consultar el resultado de la tarea
      // Este es el formato que muestra el ejemplo de JavaScript
      final getUrl = Uri.parse('https://yce-api-01.perfectcorp.com/s2s/v1.0/task/enhance?task_id=$taskId');
      
      // Esperar a que se complete la tarea (con retroceso exponencial)
      bool isTaskCompleted = false;
      int retryCount = 0;
      Map<String, dynamic> resultData = {};
      
      while (!isTaskCompleted && retryCount < 10) {
        // Esperar antes de consultar (aumentar tiempo de espera con cada intento)
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        
        final getResponse = await http.get(
          getUrl,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Accept': 'application/json',
          },
        );
        
        debugPrint('Consulta de estado #${retryCount + 1}: ${getResponse.statusCode}');
        
        if (getResponse.statusCode == 200) {
          resultData = jsonDecode(getResponse.body);
          
          // Verificar si la tarea está completa
          if (resultData.containsKey('status') && 
              (resultData['status'] == 'completed' || resultData['status'] == 'success')) {
            isTaskCompleted = true;
            debugPrint('Tarea completada con éxito');
          } else if (resultData.containsKey('result')) {
            // También podría estar completada si tiene resultado
            isTaskCompleted = true;
            debugPrint('Tarea contiene resultado');
          }
        }
        
        retryCount++;
      }
      
      if (!isTaskCompleted) {
        throw Exception('La tarea no se completó después de varios intentos');
      }
      
      // Procesar el resultado
      String? processedImageData;
      
      if (resultData.containsKey('result') && resultData['result'] is Map) {
        final result = resultData['result'];
        
        if (result.containsKey('image')) {
          processedImageData = result['image'];
        } else if (result.containsKey('image_url')) {
          final imageResponse = await http.get(Uri.parse(result['image_url']));
          processedImageData = base64Encode(imageResponse.bodyBytes);
        }
      } else if (resultData.containsKey('image')) {
        processedImageData = resultData['image'];
      } else if (resultData.containsKey('image_url')) {
        final imageResponse = await http.get(Uri.parse(resultData['image_url']));
        processedImageData = base64Encode(imageResponse.bodyBytes);
      }
      
      if (processedImageData != null) {
        // Guardar imagen en archivo temporal
        final tempDir = await getTemporaryDirectory();
        final resultFile = File('${tempDir.path}/result_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await resultFile.writeAsBytes(base64Decode(processedImageData));
        
        return TreatmentResult(
          processedImage: resultFile,
          metadata: _extractMetadata(resultData),
          confidenceScore: 1.0,
        );
      }
      
      return null;
    } catch (e) {
      debugPrint('Error en applyTreatment: $e');
      return null;
    }
  }

    // Método para traducir los tipos de tratamiento internos a parámetros específicos de YouCam

  Map<String, dynamic> _getTreatmentParams(String treatmentType, double intensity) {
    final params = <String, dynamic>{};
    
    switch (treatmentType) {
      case 'lips':
        params['feature'] = 'makeup';
        params['type'] = 'lips';
        params['intensity'] = intensity.toStringAsFixed(2);
        params['color'] = '#FF3366'; // Color para los labios
        break;
      
      case 'nose':
        params['feature'] = 'reshape';
        params['type'] = 'nose';
        params['slimming_level'] = (intensity * 100).toInt().toString();
        break;
        
      case 'botox':
        params['feature'] = 'skincare';
        params['type'] = 'wrinkle_removal';
        params['strength'] = (intensity * 100).toInt().toString();
        break;
        
      case 'fillers':
        params['feature'] = 'skincare';
        params['type'] = 'contour';
        params['region'] = 'cheek';
        params['intensity'] = intensity.toStringAsFixed(2);
        break;
        
      case 'skincare':
        params['feature'] = 'skincare';
        params['skin_smoothing'] = (intensity * 100).toInt().toString();
        break;
        
      default:
        params['feature'] = 'beauty';
        params['intensity'] = intensity.toStringAsFixed(2);
    }
    
    return params;
  }

    String _getEndpointForTreatment(String treatmentType) {
    switch (treatmentType) {
      case 'lips':
        return '/s2s/v1.0/task/makeup';
      case 'nose':
        return '/s2s/v1.0/task/reshape';
      case 'botox':
      case 'skincare':
        return '/s2s/v1.0/task/skincare';
      case 'fillers':
        return '/s2s/v1.0/task/contour';
      case 'lifting':
        return '/s2s/v1.0/task/facelift';
      default:
        return '/s2s/v1.0/task/enhance';
    }
  }
}
