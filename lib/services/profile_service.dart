import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'supabase.dart';

class ProfileService {
  final _supabaseService = SupabaseService();

  String? get currentUserId => SupabaseService().client.auth.currentUser?.id;
  
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
  
  // Método para obtener las reseñas del usuario
  Future<List<Map<String, dynamic>>> getUserReviews(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('reviews')
          .select('id, clinic_id, date, rating, text, posted_to_google, clinics(name)')
          .eq('user_id', userId)
          .order('date', ascending: false);
      
      print('Reseñas recuperadas: ${response.length}');
      
      // Transformar los datos para adaptarlos a la estructura que espera nuestra UI
      return List<Map<String, dynamic>>.from(response).map((review) {
        return {
          'id': review['id'],
          'clinic': review['clinics']['name'], // El nombre de la clínica está en el objeto anidado
          'date': review['date'],
          'rating': review['rating'].toDouble(),
          'text': review['text'],
          'posted_to_google': review['posted_to_google'],
        };
      }).toList();
    } catch (e) {
      print('Error al obtener reseñas: $e');
      
      // Durante el desarrollo, devolver datos de ejemplo para pruebas
      if (e.toString().contains('does not exist') || 
          e.toString().contains('column "clinics" does not exist')) {
        print('Devolviendo datos de ejemplo para pruebas');
        return [
          {
            'id': '1',
            'clinic': 'Clínica Love Central',
            'date': '2025-02-15',
            'rating': 4.5,
            'text': 'Excelente servicio y atención personalizada.',
            'posted_to_google': true,
          },
          {
            'id': '2',
            'clinic': 'Clínica Love Norte',
            'date': '2025-01-23',
            'rating': 5.0,
            'text': 'El tratamiento fue muy efectivo. El personal es muy profesional.',
            'posted_to_google': false,
          },
        ];
      }
      
      return []; // Devolver lista vacía en caso de error
    }
  }

  // Método para registrar un intento de reseña en Google
  Future<void> registerReviewAttempt(String userId, {String? reviewId}) async {
    try {
      // Fecha actual para timestamp
      final now = DateTime.now().toIso8601String();
      
      // Si se proporciona un ID de reseña existente, actualizar ese registro
      if (reviewId != null) {
        await _supabaseService.client
            .from('reviews')
            .update({
              'posted_to_google': true,
              'google_posted_at': now,
            })
            .eq('id', reviewId);
        
        print('Reseña marcada como publicada en Google: $reviewId');
      } else {
        // Registrar un nuevo intento (para reseñas que se hacen directamente en Google)
        await _supabaseService.client
            .from('review_attempts')
            .insert({
              'user_id': userId,
              'attempted_at': now,
              'platform': 'google',
              'discount_applied': false,
            });
        
        print('Nuevo intento de reseña registrado para usuario: $userId');
      }
    } catch (e) {
      print('Error al registrar intento de reseña: $e');
      
      // Si la tabla no existe o hay algún otro error, loguear y reenviar
      if (e.toString().contains('does not exist')) {
        print('La tabla necesaria no existe. Verifica que has creado las tablas necesarias en Supabase.');
      }
      
      throw e;
    }
  }

  // Método para obtener todos los datos del usuario (para descargas GDPR)
  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      // Obtener datos básicos del perfil
      final profileData = await SupabaseService().client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();
      
      // Obtenemos información adicional - citas
      final appointments = await SupabaseService().client
          .from('appointments')
          .select('*')
          .eq('user_id', userId);
      
      // Obtenemos reseñas del usuario
      final reviews = await SupabaseService().client
          .from('reviews')
          .select('*')
          .eq('user_id', userId);
      
      // Obtenemos consentimientos
      final consents = profileData['consents'] ?? {};
      
      // Combinamos toda la información en una estructura completa
      final Map<String, dynamic> completeUserData = {
        'profile': profileData,
        'appointments': appointments,
        'reviews': reviews,
        'consents': consents,
        'data_request_timestamp': DateTime.now().toIso8601String(),
      };
      
      return completeUserData;
    } catch (e) {
      print("Error obteniendo datos del usuario: $e");
      throw Exception('No se pudieron obtener los datos del usuario: $e');
    }
  }

  // Método para actualizar consentimientos
  Future<void> updateConsents(Map<String, dynamic> consents) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      await SupabaseService().client
          .from('profiles')
          .update({'consents': consents})
          .eq('id', userId);
    } catch (e) {
      print('Error actualizando consentimientos: $e');
      throw Exception('Error al actualizar consentimientos: $e');
    }
  }

  // Método para eliminar cuenta de usuario 
  Future<bool> deleteAccount({required String password}) async {
    try {
      final user = SupabaseService().client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Usuario no autenticado o sin email');
      }

      // Verificación de contraseña (sin cambios)
      try {
        final response = await SupabaseService().client.auth.signInWithPassword(
          email: user.email,
          password: password,
        );
        
        if (response.session == null) {
          print('Verificación de contraseña falló: No se pudo iniciar sesión');
          return false;
        }
        
        print('Contraseña verificada correctamente');
      } catch (e) {
        print('Error verificando contraseña: $e');
        return false;
      }

      try {
        // 1. Obtener y guardar IDs de todas las citas del usuario
        final appointmentsBeforeDelete = await SupabaseService().client
            .from('appointments')
            .select('id')
            .eq('patient_id', user.id);

        print('Citas a eliminar: $appointmentsBeforeDelete');

        // Almacenar los IDs para verificación posterior
        final appointmentIds = appointmentsBeforeDelete.map((appt) => appt['id']).toList();

        // 2. Eliminar cada cita individualmente
        for (final appointment in appointmentsBeforeDelete) {
          try {
            await SupabaseService().client
                .from('appointments')
                .delete()
                .eq('id', appointment['id']);
            print('Cita eliminada: ${appointment['id']}');
          } catch (e) {
            print('Error eliminando cita ${appointment['id']}: $e');
          }
        }

        // Add a small delay to allow Supabase to process deletions
        await Future.delayed(Duration(milliseconds: 500));

        // 3. Verificar cada cita individualmente en lugar de usar filter
        bool allDeleted = true;
        List<String> stillExistingIds = [];

        for (final appointmentId in appointmentIds) {
          final check = await SupabaseService().client
              .from('appointments')
              .select('id')
              .eq('id', appointmentId);
              
          if (check.isNotEmpty) {
            print('La cita aún existe: $appointmentId');
            allDeleted = false;
            stillExistingIds.add(appointmentId);
          }
        }

        if (!allDeleted) {
          print('¡ADVERTENCIA! Quedan citas sin eliminar: $stillExistingIds');
          
          // Aquí podríamos intentar eliminar de nuevo las citas problemáticas
          // En lugar de fallar inmediatamente, intentamos una segunda vez
          for (final id in stillExistingIds) {
            try {
              await SupabaseService().client
                  .from('appointments')
                  .delete()
                  .eq('id', id);
              print('Segundo intento de eliminar cita: $id');
            } catch (e) {
              print('Error en segundo intento para cita $id: $e');
            }
          }
          
          // Verificación final
          final finalCheck = await SupabaseService().client
              .from('appointments')
              .select('count')
              .eq('patient_id', user.id);
              
          if (finalCheck.isNotEmpty && finalCheck[0]['count'] > 0) {
            throw Exception('No se pudieron eliminar todas las citas después de múltiples intentos');
          }
        }
        
        // 4. Eliminar reseñas
        await SupabaseService().client
            .from('reviews')
            .delete()
            .eq('user_id', user.id);
        
        // 5. Ahora que no hay referencias, eliminar perfil
        await SupabaseService().client
            .from('profiles')
            .delete()
            .eq('id', user.id);
        
        // 6. Solicitar eliminación de la cuenta de autenticación
        await SupabaseService().client.from('delete_auth_user_trigger')
            .insert({
              'user_id': user.id
            });
        
        print('Solicitud de eliminación de cuenta enviada');
        
        // 7. Cerrar sesión
        await SupabaseService().client.auth.signOut();
        return true;
      } catch (e) {
        print('Error eliminando datos: $e');
        return false;
      }
    } catch (e) {
      print('Error eliminando cuenta: $e');
      return false;
    }
  }

  // Método para verificar si el usuario tiene un consentimiento específico
  Future<bool> hasConsent(String consentKey) async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      final profile = await getProfile(null);
      if (profile == null || profile.consents == null) {
        return false;
      }
      
      return profile.consents![consentKey] ?? false;
    } catch (e) {
      print('Error verificando consentimiento: $e');
      return false;
    }
  }
}