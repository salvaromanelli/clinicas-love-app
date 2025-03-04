// auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _supabaseService = SupabaseService();
  
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