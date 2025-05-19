import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;


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

  /// Valida si una ruta de archivo es segura
  static bool isValidFilePath(String filePath) {
    // Verificar que no contiene secuencias de escape o caracteres peligrosos
    if (filePath.contains('..') || 
        filePath.contains('|') || 
        filePath.contains(';') ||
        filePath.contains('&') ||
        filePath.contains('<') ||
        filePath.contains('>')) {
      return false;
    }
    
    // Verificar extensiones permitidas
    final ext = path.extension(filePath).toLowerCase();
    final allowedExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.gif'];
    return allowedExtensions.contains(ext);
  }

  /// Valida un código generado
  static bool isValidCode(String code) {
    final validPattern = RegExp(r'^[A-Z0-9]{6}$');
    return validPattern.hasMatch(code);
  }

  /// Sanitiza texto para evitar inyecciones
  static String sanitizeInput(String input) {
    // Eliminar caracteres HTML y scripts
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Valida datos antes de enviarlos a la base de datos
  static bool isValidSubmission(Map<String, dynamic> data) {
    // Validación básica de datos
    if (data.containsKey('instagram_username')) {
      final username = data['instagram_username'] as String;
      if (!isValidSocialUsername(username)) {
        return false;
      }
    }
    
    // Validar código si existe
    if (data.containsKey('code')) {
      final code = data['code'] as String;
      if (!code.startsWith('CL-')) {
        return false;
      }
    }
    
    return true;
  }

  /// Verifica si un nombre de usuario de redes sociales es válido
  static bool isValidSocialUsername(String username) {
    // Permitir solo letras, números, puntos y guiones bajos
    final validPattern = RegExp(r'^[a-zA-Z0-9._]{1,30}$');
    
    // No permitir nombres sospechosos
    final suspiciousPatterns = [
      'admin', 'root', 'system', 'null', 'undefined',
      'javascript', 'script', 'alert', 'console'
    ];
    
    final lowerUsername = username.toLowerCase();
    return validPattern.hasMatch(username) && 
          !suspiciousPatterns.any((pattern) => lowerUsername.contains(pattern));
  }

  /// Sanitiza nombres de usuario de redes sociales eliminando caracteres no permitidos
  static String sanitizeSocialUsername(String input) {
    return RegExp(r'[a-zA-Z0-9._]+').stringMatch(input) ?? '';
  }

  /// Verifica si el dispositivo está rooteado (Android) o tiene jailbreak (iOS)
  static Future<bool> isDeviceRooted() async {
    try {
      if (Platform.isAndroid) {
        // Verificar archivos comunes en dispositivos rooteados
        final paths = [
          '/system/app/Superuser.apk',
          '/system/xbin/su',
          '/sbin/su',
          '/system/bin/su'
        ];
        
        for (final path in paths) {
          if (await File(path).exists()) {
            return true;
          }
        }
        
      } else if (Platform.isIOS) {
        // Verificar archivos comunes en dispositivos con jailbreak
        final paths = [
          '/Applications/Cydia.app',
          '/Library/MobileSubstrate/MobileSubstrate.dylib',
          '/bin/bash',
          '/etc/apt'
        ];
        
        for (final path in paths) {
          if (await File(path).exists()) {
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      // En caso de error, asumimos que no hay root/jailbreak
      print('Error detectando root/jailbreak: $e');
      return false;
    }
  }
}