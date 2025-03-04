import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'supabase.dart';

class ProfileService {
  final _supabaseService = SupabaseService();
  
Future<Profile?> getProfile(String? token) async {
  try {
    final user = _supabaseService.client.auth.currentUser;
    
    if (user == null) {
      print("No hay usuario autenticado");
      return null;
    }
    
    print("Obteniendo perfil para usuario: ${user.id}");
    
    // Usar maybeSingle en lugar de single para evitar errores si no existe
    final response = await _supabaseService.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    
    // Si no hay perfil, crearlo automáticamente
    if (response == null) {
      print("No se encontró perfil. Creando uno nuevo...");
      
      // Datos básicos para un nuevo perfil
      final newProfile = {
        'id': user.id,
        'full_name': user.userMetadata?['full_name'] ?? 'Usuario',
        'email': user.email ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Insertar el nuevo perfil
      await _supabaseService.client
          .from('profiles')
          .insert(newProfile);
      
      // Devolver el perfil recién creado
      return Profile.fromJson(newProfile);
    }
    
    // Devolver el perfil existente
    return Profile.fromJson(response);
    
  } catch (e) {
    print("Error en getProfile: $e");
    rethrow;
  }
}
  
Future<void> updateProfile(Profile profile) async {
  try {
    final user = _supabaseService.client.auth.currentUser;
    
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }
    
    print("Actualizando perfil para usuario ${user.id}");
    print("Datos a actualizar: ${profile.toJson()}");
    
    await _supabaseService.client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', user.id);
        
    print("Perfil actualizado correctamente");
    
  } catch (e) {
    print("Error actualizando perfil: $e");
    rethrow;
  }
}
Future<String?> uploadAvatar(String filePath) async {
  try {
    final user = _supabaseService.client.auth.currentUser;
    
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }
    
    // Crear un nombre de archivo único
    final fileName = 'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(filePath);
    
    print("Subiendo avatar con nombre: $fileName");
    
    // Subir la imagen
    await _supabaseService.client.storage
        .from('avatars')
        .upload(fileName, file);
    
    // Obtener URL pública
    final avatarUrl = _supabaseService.client.storage
        .from('avatars')
        .getPublicUrl(fileName);
        
    print("Avatar subido, URL: $avatarUrl");
    
    // Actualizar perfil con la nueva URL
    await _supabaseService.client
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('id', user.id);
        
    return avatarUrl;
    
  } catch (e) {
    print("Error subiendo avatar: $e");
    rethrow;
  }
}
}