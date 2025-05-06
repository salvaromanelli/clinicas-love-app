import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../main.dart'; // Para acceder al navigatorKey global

class AuthInterceptor extends http.BaseClient {
  final http.Client _inner;
  final AuthService _authService;
  final int maxRetries;
  
  AuthInterceptor(this._inner, this._authService, {this.maxRetries = 2});
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request, {int retryCount = 0}) async {
    try {
      // 1. Verificar preventivamente si el token necesita renovación
      final isValid = await _authService.refreshTokenIfNeeded();
      if (!isValid) {
        debugPrint('❌ Token inválido y no se pudo renovar');
        _handleSessionExpiration();
        throw Exception('Sesión expirada');
      }
      
      // 2. Añadir automáticamente el token de autorización si no está presente
      if (!request.headers.containsKey('Authorization')) {
        final token = await _authService.getToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
          debugPrint('🔐 Token añadido a la petición');
        }
      }
      
      // 3. Enviar la solicitud
      final response = await _inner.send(request);
      
      // 4. Verificar si hay error 401 en la respuesta
      if (response.statusCode == 401 && retryCount < maxRetries) {
        debugPrint('⚠️ 401 Unauthorized recibido, intentando renovar token...');
        
        // Intentar renovar el token forzosamente
        final tokenRenewed = await _authService.refreshTokenIfNeeded(forceRefresh: true);
        
        if (tokenRenewed) {
          debugPrint('✅ Token renovado, reintentando solicitud (intento ${retryCount + 1})');
          // Si se renovó con éxito, recrear la solicitud con el nuevo token
          final newRequest = await _recreateRequest(request);
          // Reintentar la solicitud (incrementando el contador)
          return send(newRequest, retryCount: retryCount + 1);
        } else {
          debugPrint('❌ No se pudo renovar el token después de recibir 401');
          _handleSessionExpiration();
        }
      }
      
      return response;
    } catch (e) {
      debugPrint('🛑 Error en interceptor HTTP: $e');
      // Si es un error de autenticación conocido, manejar la expiración
      if (e.toString().toLowerCase().contains('unauthorized') || 
          e.toString().toLowerCase().contains('401') ||
          e.toString().toLowerCase().contains('sesión expirada')) {
        _handleSessionExpiration();
      }
      rethrow;
    }
  }
  
  /// Recrea una solicitud HTTP para reutilizar sus parámetros
  Future<http.BaseRequest> _recreateRequest(http.BaseRequest original) async {
    final request = http.Request(original.method, original.url);
    
    // Copiar cabeceras, pero actualizar el token
    request.headers.addAll(Map<String, String>.from(original.headers));
    
    // Actualizar el token
    final newToken = await _authService.getToken();
    if (newToken != null && newToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $newToken';
    }
    
    // Copiar el cuerpo si es una solicitud con cuerpo
    if (original is http.Request) {
      request.body = (original).body;
    }
    
    return request;
  }
  
  /// Maneja el caso donde la sesión ha expirado definitivamente
  void _handleSessionExpiration() {
    debugPrint('👋 Cerrando sesión por token expirado');
    // Cerrar sesión
    _authService.logout();
    
    // Redirigir al login (usando navigatorKey global para acceder al Navigator sin contexto)
    Future.microtask(() {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }
  
  @override
  void close() {
    _inner.close();
    super.close();
  }
}