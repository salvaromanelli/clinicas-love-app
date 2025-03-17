import 'package:flutter/foundation.dart';

class Env {
  // API Keys
  static final String openAIApiKey = _getOpenAIKey();
  
  // Configuración de entorno
  static final bool isProduction = false; // Cambiar a true para producción
  
  // Opciones de servicios
  static final bool useAITestMode = kDebugMode || !isProduction;
  
  // Obtener la clave API según el entorno
  static String _getOpenAIKey() {
    // En producción, usaría una clave real
    if (isProduction) {
      return 'sk-tu-clave-de-produccion'; // Reemplaza con tu clave de API real
    } else {
      // Clave para desarrollo o pruebas con la API real
      return 'sk-tu-clave-de-desarrollo'; // Reemplaza con tu clave de desarrollo
    }
  }
}