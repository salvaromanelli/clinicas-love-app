import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'dart:async';

class YouCamService {
  final String apiKey;
  final String baseUrl = 'https://yce-api-01.perfectcorp.com';
  final bool testMode; 

  // Constructor que acepta el parámetro nombrado apiKey
    YouCamService({
    required this.apiKey, 
    this.testMode = false  // Parámetro opcional con valor predeterminado
  });

    Future<bool> _isImageCompatible(File imageFile) async {
    // Verificar formato
    final extension = path.extension(imageFile.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png'].contains(extension)) {
      return false;
    }
    
    // Verificar tamaño
    final fileSize = await imageFile.length();
    if (fileSize > 10 * 1024 * 1024) { // 10MB (ajusta según los límites de la API)
      return false;
    }
    
    return true;
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
    required Map<String, dynamic> params,
  }) async {
    // En modo de prueba, devolver la misma imagen
    if (testMode) {
      debugPrint('Modo de prueba: simulando aplicación de tratamiento');
      await Future.delayed(const Duration(seconds: 2));
      return image;
    }
    
    try {
      // Verificar si la imagen es compatible
      if (!await _isImageCompatible(image)) {
        debugPrint('La imagen no es compatible para applyTreatment');
        return null;
      }

      // Seleccionar el endpoint correcto según el tipo de tratamiento
      String endpoint;
      switch (treatmentType) {
        case 'lips':
        case 'nose':
          endpoint = '/s2s/v1.0/task/enhance';
          break;
        case 'botox':
        case 'fillers':
        case 'skincare':
        case 'lifting':
        default:
          endpoint = '/youcam-makeup/api/v2/skincare';
      }
      
      final uri = Uri.parse('$baseUrl$endpoint');
      debugPrint('URL de tratamiento: $uri');
      
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
      params.forEach((key, value) {
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
}
