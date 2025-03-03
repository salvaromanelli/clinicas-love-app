import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '/models/clinicas.dart';


class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  
  factory SupabaseService() {
    return _instance;
  }
  
  SupabaseService._internal();
  
static Future<void> initialize() async {
  await Supabase.initialize(
    url: 'https://xlrutqwvlowzntnjgmwa.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhscnV0cXd2bG93em50bmpnbXdhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA5NjM2NDAsImV4cCI6MjA1NjUzOTY0MH0.RpmMKYSYEAXZLzCWgd7AP0pclgvXhVZmo14XXqdpBtE',
    debug: false,
  );
}
  SupabaseClient get client => Supabase.instance.client;
  
  // Verificar si el usuario está autenticado
  Future<bool> isLoggedIn() async {
    return client.auth.currentUser != null;
  }
  
  // Iniciar sesión con email y password
  Future<AuthResponse> signIn({
    required String email, 
    required String password
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  // Registro de nuevo usuario
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
      },
    );
    
    if (response.user != null) {
      // Crear perfil de usuario en la tabla profiles
      await client.from('profiles').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    return response;
  }
  
  // Cerrar sesión
  Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  // Obtener token de sesión
  Future<String?> getToken() async {
    final session = client.auth.currentSession;
    return session?.accessToken;
  }
  
  // Obtener usuario actual
  User? get currentUser => client.auth.currentUser;
  
  // Recuperar contraseña
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }
  
  // Subir imagen de perfil
  Future<String?> uploadProfileImage(File imageFile) async {
    final user = currentUser;
    if (user == null) return null;
    
    final fileExt = path.extension(imageFile.path);
    final fileName = '${const Uuid().v4()}$fileExt';
    final filePath = 'profile_images/${user.id}/$fileName';
    
    await client.storage.from('avatars').upload(
      filePath,
      imageFile,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
    );
    
    final imageUrl = client.storage.from('avatars').getPublicUrl(filePath);
    
    // Actualizar perfil con nueva imagen
    await client.from('profiles').update({
      'avatar_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    
    return imageUrl;
  }
  
  // Obtener perfil de usuario
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    
    final response = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
        
    return response as Map<String, dynamic>?;
  }
  
  // Actualizar perfil de usuario
 // Reemplaza el código desde la línea 140 en adelante

  Future<void> updateUserProfile({
    required Map<String, dynamic> data,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');
    
    data['updated_at'] = DateTime.now().toIso8601String();
    
    await client
        .from('profiles')
        .update(data)
        .eq('id', user.id);
  }
  
  // Escuchar cambios de autenticación
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // CLÍNICAS
  Future<List<Clinica>> getClinicas() async {
    try {
      // Cambia 'clinicas' a 'clinics' para que coincida con el nombre de la tabla
      final response = await client.from('clinics').select();
      
      if (response == null) {
        print('Error al obtener clínicas: respuesta nula');
        return [];
      }
      
      final data = response as List;
      return data.map((json) => Clinica.fromJson(json)).toList();
    } catch (e) {
      print('Error al obtener clínicas: $e');
      return [];
    }
  }

  // TRATAMIENTOS Y SIMULACIONES
  Future<List<Map<String, dynamic>>> getTreatments() async {
    final response = await client
        .from('treatments')
        .select('*')
        .order('name');

    return response;
  }

  Future<String> saveSimulationResult({
    required String treatmentId,
    required File beforeImage,
    required File afterImage,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final simulationId = const Uuid().v4();
    final beforeImagePath = 'simulations/${user.id}/${simulationId}_before${path.extension(beforeImage.path)}';
    final afterImagePath = 'simulations/${user.id}/${simulationId}_after${path.extension(afterImage.path)}';

    // Subir imagen "antes"
    await client.storage.from('simulations').upload(
          beforeImagePath,
          beforeImage,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    // Subir imagen "después"
    await client.storage.from('simulations').upload(
          afterImagePath,
          afterImage,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final beforeImageUrl = client.storage.from('simulations').getPublicUrl(beforeImagePath);
    final afterImageUrl = client.storage.from('simulations').getPublicUrl(afterImagePath);

    // Guardar registros de simulación
    await client.from('treatment_simulations').insert({
      'id': simulationId,
      'patient_id': user.id,
      'treatment_id': treatmentId,
      'before_image_url': beforeImageUrl,
      'after_image_url': afterImageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    return simulationId;
  }

  Future<List<Map<String, dynamic>>> getUserSimulations() async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final response = await client
        .from('treatment_simulations')
        .select('*, treatments(*)')
        .eq('patient_id', user.id)
        .order('created_at', ascending: false);

    return response;
  }

  // CITAS
  Future<void> bookAppointment({
    required String treatmentId,
    required String clinicId,
    required DateTime date,
    String? notes,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    await client.from('appointments').insert({
      'patient_id': user.id,
      'treatment_id': treatmentId,
      'clinic_id': clinicId,
      'appointment_date': date.toIso8601String(),
      'status': 'pending',
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUserAppointments() async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final response = await client
        .from('appointments')
        .select('*, treatments(*), clinics(*)')
        .eq('patient_id', user.id)
        .order('appointment_date');

    return response;
  }

  // REDES SOCIALES
  Future<void> connectSocialNetwork({
    required String platform,
    required String username,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    await client.from('user_socials').insert({
      'user_id': user.id,
      'platform': platform,
      'username': username,
      'verified': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUserSocialNetworks() async {
    final user = currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final response = await client
        .from('user_socials')
        .select()
        .eq('user_id', user.id);

    return response;
  }

  // CONTENIDO EDUCATIVO
  Future<List<Map<String, dynamic>>> getEducationalContent() async {
    final response = await client
        .from('educational_content')
        .select()
        .order('created_at', ascending: false);

    return response;
  }

  // PROMOCIONES
  Future<List<Map<String, dynamic>>> getPromotions() async {
    final now = DateTime.now().toIso8601String();
    final response = await client
        .from('promotions')
        .select()
        .lte('valid_from', now)
        .gte('valid_until', now);

    return response;
  }
}