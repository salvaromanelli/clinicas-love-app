// auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'supabase.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _supabaseService = SupabaseService();
  
    // Método para obtener el ID del usuario actual
  Future<String?> getCurrentUserId() async {
    try {
      // Verificar el usuario actual de Supabase
      final currentUser = _supabaseService.client.auth.currentUser;
      
      // Si hay un usuario autenticado, devolver su ID
      if (currentUser != null) {
        return currentUser.id;
      }
      
      // Intentar refrescar la sesión
      try {
        final session = await _supabaseService.client.auth.refreshSession();
        return session.user?.id;
      } catch (e) {
        print('Error al refrescar sesión: $e');
      }
      
      return null;
    } catch (e) {
      print('Error al obtener ID de usuario: $e');
      return null;
    }
  }
  
  // Obtener token almacenado
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
  
  // Guardar token de sesión
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }
  
  // Verificar si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  // Cerrar sesión
  Future<void> logout() async {
    await _supabaseService.signOut();
    await _storage.delete(key: 'auth_token');
  }
}