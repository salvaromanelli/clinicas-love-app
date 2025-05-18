// Crear un archivo en lib/services/analytics_service.dart
import 'package:flutter/material.dart';
import 'supabase.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart' show navigatorKey;
import 'package:uuid/uuid.dart';
import '../utils/security_utils.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

    // Método para sanitizar datos antes de envío
  Map<String, dynamic> _sanitizeAnalyticsData(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is String) {
        result[key] = SecurityUtils.sanitizeText(value);
      } else if (value is num || value is bool) {
        result[key] = value;
      } else if (value is Map) {
        result[key] = _sanitizeAnalyticsData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is String) return SecurityUtils.sanitizeText(item);
          return item;
        }).toList();
      } else {
        // Valores null o tipos no reconocidos
        result[key] = value;
      }
    });
    
    return result;
  }
  
  // Registrar vista de página
  Future<void> logPageView(String pageName) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id ?? 'anonymous';
      
      await SupabaseService().client.from('analytics_events').insert({
        'user_id': userId,
        'event_type': 'page_view',
        'event_name': pageName,
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': await _getDeviceInfo(),
      });
      
      debugPrint('✅ Analytics: Page view logged - $pageName');
    } catch (e) {
      debugPrint('❌ Error logging page view: $e');
    }
  }
  
  // Registrar una interacción con el chatbot

  Future<String?> logChatbotConversation({
    required String userMessage,
    required String botResponse,
    String? sessionId,
    Map<String, dynamic>? metadata,
    String? conversationId,
  }) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id ?? 'anonymous';
      final newConversationId = conversationId ?? const Uuid().v4();
      
      // Consulta SQL con conversión explícita de tipos
      final result = await SupabaseService().client.rpc(
        'insert_chatbot_message',
        params: {
          'p_user_id': userId,
          'p_conversation_id': newConversationId,
          'p_message_text': userMessage,
          'p_response_text': botResponse,
          'p_timestamp': DateTime.now().toIso8601String(),
          'p_message_metadata': metadata,
          'p_session_id': sessionId,
          'p_device_info': await _getDeviceInfo(),
        }
      );
      
      // También registrar como evento de interacción para mantener consistencia
      await logInteraction('chatbot_conversation', {
        'conversation_id': newConversationId,
        'message_length': userMessage.length,
        'response_length': botResponse.length,
      });
      
      debugPrint('✅ Analytics: Chatbot conversation logged');
      return newConversationId; // Devolver ID para continuar la conversación
    } catch (e) {
      debugPrint('❌ Error logging chatbot conversation: $e');
      return null;
    }
  }

  // Obtener historial de conversaciones del chatbot para un usuario

  Future<List<Map<String, dynamic>>> getChatbotHistory({
    int limit = 20,
    int offset = 0,
    String? conversationId,
  }) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) return [];
      
      // Usar RPC que maneja la conversión de tipos
      final data = await SupabaseService().client.rpc(
        'get_chatbot_history',
        params: {
          'p_user_id': userId,
          'p_conversation_id': conversationId,
          'p_limit': limit,
          'p_offset': offset
        }
      );
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error obteniendo historial de chatbot: $e');
      return [];
    }
  }

  // Obtener todas las conversaciones agrupadas por ID de conversación

  Future<Map<String, List<Map<String, dynamic>>>> getChatbotConversations({
    int limit = 10,
  }) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) return {};
      
      // Usar RPC para manejar la conversión de tipos
      final data = await SupabaseService().client.rpc(
        'get_chatbot_conversations',
        params: {
          'p_user_id': userId,
          'p_limit': limit
        }
      );
      
      // Convertir la respuesta al formato esperado
      Map<String, List<Map<String, dynamic>>> conversations = {};
      for (var entry in data) {
        String convId = entry['conversation_id'];
        if (!conversations.containsKey(convId)) {
          conversations[convId] = [];
        }
        conversations[convId]!.add(Map<String, dynamic>.from(entry));
      }
      
      return conversations;
    } catch (e) {
      debugPrint('❌ Error obteniendo conversaciones de chatbot: $e');
      return {};
    }
  }

  // Registrar evento de conversión
  Future<void> logConversion(String eventName, Map<String, dynamic> properties) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id ?? 'anonymous';
      
      await SupabaseService().client.from('analytics_events').insert({
        'user_id': userId,
        'event_type': 'conversion',
        'event_name': eventName,
        'properties': properties,
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': await _getDeviceInfo(),
      });
      
      debugPrint('✅ Analytics: Conversion logged - $eventName');
    } catch (e) {
      debugPrint('❌ Error logging conversion: $e');
    }
  }
  
  // Registrar interacción de usuario
  Future<void> logInteraction(String eventName, Map<String, dynamic> properties) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id ?? 'anonymous';
      
      // Sanitizar datos antes de insertar en la base de datos
      final sanitizedEventName = SecurityUtils.sanitizeText(eventName);
      final sanitizedProperties = _sanitizeAnalyticsData(properties);
      
      await SupabaseService().client.from('analytics_events').insert({
        'user_id': userId,
        'event_type': 'interaction',
        'event_name': sanitizedEventName, // Usar el nombre sanitizado
        'properties': sanitizedProperties, // Usar las propiedades sanitizadas
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': await _getDeviceInfo(),
      });
      
      debugPrint('✅ Analytics: Interaction logged - $sanitizedEventName');
    } catch (e) {
      debugPrint('❌ Error logging interaction: $e');
    }
  }
  
  // Método auxiliar para obtener info del dispositivo
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    Map<String, dynamic> deviceData = {};
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      if (Theme.of(navigatorKey.currentContext!).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          'platform': 'iOS',
          'os_version': iosInfo.systemVersion,
          'model': iosInfo.model,
          'app_version': packageInfo.version,
          'screen_size': '${MediaQuery.of(navigatorKey.currentContext!).size.width.toInt()}x${MediaQuery.of(navigatorKey.currentContext!).size.height.toInt()}'
        };
      } else {
        final androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          'platform': 'Android',
          'os_version': androidInfo.version.release,
          'model': androidInfo.model,
          'app_version': packageInfo.version,
          'screen_size': '${MediaQuery.of(navigatorKey.currentContext!).size.width.toInt()}x${MediaQuery.of(navigatorKey.currentContext!).size.height.toInt()}'
        };
      }
    } catch (e) {
      deviceData = {
        'platform': 'unknown',
        'app_version': 'unknown',
        'error': e.toString()
      };
    }
    
    return deviceData;
  }
}