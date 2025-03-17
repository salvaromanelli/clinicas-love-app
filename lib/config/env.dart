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