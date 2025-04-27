// Crear un archivo en lib/services/analytics_service.dart
import 'package:flutter/material.dart';
import 'supabase.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart' show navigatorKey;

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();
  
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
      
      await SupabaseService().client.from('analytics_events').insert({
        'user_id': userId,
        'event_type': 'interaction',
        'event_name': eventName,
        'properties': properties,
        'timestamp': DateTime.now().toIso8601String(),
        'device_info': await _getDeviceInfo(),
      });
      
      debugPrint('✅ Analytics: Interaction logged - $eventName');
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