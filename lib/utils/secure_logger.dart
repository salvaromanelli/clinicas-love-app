import 'package:flutter/foundation.dart';

class SecureLogger {
  static void log(String message, {bool sensitive = false}) {
    if (!kDebugMode) return;
    
    if (sensitive) {
      // Ocultar información sensible en logs
      final sanitizedMessage = _maskSensitiveData(message);
      debugPrint('🔒 $sanitizedMessage');
    } else {
      debugPrint('📝 $message');
    }
  }
  
  static String _maskSensitiveData(String message) {
    // Enmascarar UUIDs, emails, tokens, etc.
    return message
      .replaceAllMapped(
        RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 
          caseSensitive: false), 
        (m) => '****-****-****-****-${m[0]!.substring(m[0]!.length - 4)}'
      )
      .replaceAllMapped(
        RegExp(r'[\w-\.]+@([\w-]+\.)+[\w-]{2,4}'), 
        (m) => '****@${m[0]!.split('@')[1]}'
      );
  }
}