import 'package:flutter/material.dart';

class SecurityUtils {
  // Lista de rutas permitidas (whitelist)
  static final Set<String> validRoutes = {
    '/home', '/assistant', '/simulation', '/clinicas',
    '/integracion-redes', '/educacion-contenido', '/login', 
    '/register', '/appointments', '/reviews', '/language-settings', 
    '/profile', '/book-appointment', '/ofertas-promo', 
    '/recomendaciones', '/boton-asistente'
  };

  // Validar ruta antes de navegación
  static bool isValidRoute(String? route) {
    if (route == null) return false;
    return validRoutes.contains(route);
  }
  
  // Navegación segura
  static void navigateToSafely(BuildContext context, String route) {
    if (isValidRoute(route)) {
      Navigator.of(context).pushNamed(route);
    } else {
      debugPrint('⚠️ Intento de navegación a ruta no permitida: $route');
      // Opcionalmente mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta no válida'))
      );
    }
  }
  
  // Sanitizar texto general
  static String sanitizeText(String? input) {
    if (input == null) return '';
    
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remover HTML tags
        .replaceAll("'", "''")              // Escapar comillas SQL
        .replaceAll(r'\', r'\\')            // Escapar backslashes
        .trim();
  }
}