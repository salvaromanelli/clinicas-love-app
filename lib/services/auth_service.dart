// auth_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'supabase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/user_provider.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _supabaseService = SupabaseService();
  
  // Método para sincronizar usuario con UserProvider
  static void syncUserWithProvider(BuildContext context) async {
    final authService = AuthService();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Verificar si hay un usuario autenticado
    final userId = await authService.getCurrentUserId();
    
    if (userId != null) {
      try {
        // Obtener datos del perfil del usuario desde Supabase
        final userData = await authService._supabaseService.client
            .from('profiles')
            .select('full_name, profile_image_url')
            .eq('id', userId)
            .single();
        
        // Actualizar el UserProvider con los datos obtenidos
        userProvider.setUser(UserModel(
          userId: userId,
          name: userData['full_name'],
          profileImageUrl: userData['profile_image_url'],
        ));
        
        debugPrint('✅ Usuario sincronizado con ID: $userId');
      } catch (e) {
        // Si no podemos obtener datos adicionales, usar solo el ID
        userProvider.setUser(UserModel(
          userId: userId,
          name: 'Usuario', // Nombre genérico
          profileImageUrl: null, // Sin imagen
        ));
        
        debugPrint('⚠️ Sincronización parcial: $e');
      }
    } else {
      // No hay usuario autenticado
      userProvider.logout();
      debugPrint('🚫 No hay usuario autenticado para sincronizar');
    }
  }

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
  Future<void> saveToken(String token, {BuildContext? context}) async {
    await _storage.write(key: 'auth_token', value: token);
    
    // Si se proporciona el contexto, sincronizar el usuario
    if (context != null) {
      syncUserWithProvider(context);
    }
  }
  
  // Verificar si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  // MODIFICADO: Cerrar sesión y limpiar UserProvider
  Future<void> logout({BuildContext? context}) async {
    await _supabaseService.signOut();
    await _storage.delete(key: 'auth_token');
    
    // Limpiar UserProvider si se proporciona el contexto
    if (context != null) {
      Provider.of<UserProvider>(context, listen: false).logout();
    }
  }
}