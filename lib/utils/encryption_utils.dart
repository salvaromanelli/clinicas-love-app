import 'dart:convert';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/foundation.dart';

class EncryptionUtils {
  /// Genera el id_token necesario para la autenticación con YouCam API
  static String? generateYouCamIdToken({
    required String clientId,
    required String secretKey,
  }) {
    try {
      // 1. Generar el timestamp actual en milisegundos
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 2. Crear la cadena que se va a firmar
      final dataToSign = 'client_id=$clientId&timestamp=$timestamp';
      debugPrint('Datos a firmar: $dataToSign');
      
      // 3. Convertir la clave secreta de formato PEM a un objeto RSAPrivateKey
      String formattedKey = _formatRSAKey(secretKey);
      
      // 4. Crear un par de claves RSA a partir de la clave secreta
      final privateKey = CryptoUtils.rsaPrivateKeyFromPem(formattedKey);
      
      // 5. FIRMA los datos en lugar de encriptarlos
      final signature = CryptoUtils.rsaSign(
        privateKey,
        Uint8List.fromList(utf8.encode(dataToSign)),
        algorithmName: 'SHA-256' 
      );
      
      // 6. Codificar la firma en Base64
      return base64Encode(signature);
    } catch (e) {
      debugPrint('Error al generar id_token: $e');
      return null;
    }
  }
  
  /// Formatea una clave RSA para asegurar que tiene el formato PEM correcto
  static String _formatRSAKey(String key) {
    // Limpiar la clave de cualquier encabezado/pie de página existente
    String cleanKey = key
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    
    // Dividir la clave en líneas de 64 caracteres (formato PEM estándar)
    final List<String> lines = [];
    for (int i = 0; i < cleanKey.length; i += 64) {
      int end = (i + 64 < cleanKey.length) ? i + 64 : cleanKey.length;
      lines.add(cleanKey.substring(i, end));
    }
    
    // Reformatear con el encabezado/pie de página PEM correcto - ELIMINA ESPACIOS ADICIONALES
    return '''-----BEGIN RSA PRIVATE KEY-----
  ${lines.join('\n')}
  -----END RSA PRIVATE KEY-----''';
  }
}