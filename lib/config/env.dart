import 'package:flutter/foundation.dart';

class Env {
  // API Keys
  static final String openAIApiKey = _getOpenAIKey();
  
  // Configuración de entorno
  static final bool isProduction = false; // Cambiar a true para producción
  
  // Opciones de servicios
  static final bool useAITestMode = false; // Cambiar a true para usar respuestas simuladas
  
  // Obtener la clave API según el entorno
  static String _getOpenAIKey() {
    // En producción, usaría una clave real
    if (isProduction) {
      return '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'; // Reemplaza con tu clave de API real
    } else {
      // Clave para desarrollo o pruebas con la API real
      return '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'; // Reemplaza con tu clave de desarrollo
    }
  }
}