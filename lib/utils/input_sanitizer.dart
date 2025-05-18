import 'package:html_unescape/html_unescape.dart';

class InputSanitizer {
  static final HtmlUnescape _htmlUnescape = HtmlUnescape();
  
  /// Sanitiza texto para prevenir XSS
  static String sanitizeUserInput(String? input) {
    if (input == null || input.isEmpty) return '';
    
    // Primero decodificar caracteres HTML para evitar doble codificación
    var text = _htmlUnescape.convert(input);
    
    // Eliminar etiquetas HTML
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Escapar caracteres HTML para evitar inyecciones
    text = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll("/", '&#x2F;');
    
    return text;
  }
  
  /// Validar texto para asegurar que solo contiene caracteres permitidos
  static bool isValidInput(String? input) {
    if (input == null || input.isEmpty) return false;
    
    // Permitir solo caracteres de texto común, números, espacios y puntuación básica
    final RegExp validPattern = RegExp('^[a-zA-ZáéíóúÁÉÍÓÚüÜñÑ0-9\\s.,¿?¡!:;()\\-_\'"]+\$');
    
    return validPattern.hasMatch(input);
  }
  
  /// Sanitizar datos para analytics
  static Map<String, dynamic> sanitizeAnalyticsData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is String) {
        result[key] = sanitizeUserInput(value);
      } else if (value is Map) {
        result[key] = sanitizeAnalyticsData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is String) return sanitizeUserInput(item);
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }
}