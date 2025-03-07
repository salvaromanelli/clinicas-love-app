import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '/models/clinicas.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'notificaciones.dart';

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

    // Almacenamiento de imagenes en supabase
  Future<void> createStorageBucketIfNotExists() async {
    try {
      await client.storage.createBucket('tratamientos', 
        const BucketOptions(public: true));
      print('Bucket "tratamientos" creado');
    } catch (e) {
      // Probablemente el bucket ya existe
      print('El bucket puede que ya exista: $e');
    }
  }

  // Carga imagenes de reemplazo
  Future<void> uploadPlaceholderImages() async {
    final categories = ['medicina_estetica_facial', 'cirugía_estetica_facial', 'cirugía_corporal'];
    
    for (String category in categories) {
      try {
        // Usa una imagen predeterminada por categoría
        String imageAssetPath;
        switch(category) {
          case 'medicina_estetica_facial':
            imageAssetPath = 'assets/placeholders/facial_estetica.jpg';
            break;
          case 'cirugía_estetica_facial':
            imageAssetPath = 'assets/placeholders/facial_cirugia.jpg';
            break;
          default:
            imageAssetPath = 'assets/placeholders/corporal.jpg';
            break;
        }
        
        // Load the image asset as bytes
        final ByteData bytes = await rootBundle.load(imageAssetPath);
        final Uint8List imageData = bytes.buffer.asUint8List();
        
        // Create the folder structure and upload file
        await client.storage.from('tratamientos')
          .uploadBinary('$category/default.jpg', imageData);
          
        print('Uploaded placeholder image for $category');
      } catch (e) {
        print('Error uploading placeholder for $category: $e');
      }
    }
  }

  // Actualizar URL de imagen en la tabla de tratamientos
  Future<void> updateImageUrls() async {
    // Get the Supabase URL directly from the initialization value
    final supabaseUrl = 'https://xlrutqwvlowzntnjgmwa.supabase.co';
    
    final treatments = await client.from('treatments').select();
    
    for (final treatment in treatments) {
      final category = treatment['category']
          .toString()
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('é', 'e');
      
      // URL a una imagen de marcador de posición por categoría
      final newImageUrl = 
          '$supabaseUrl/storage/v1/object/public/tratamientos/$category/default.jpg';
      
      await client.from('treatments')
        .update({'image_url': newImageUrl})
        .eq('id', treatment['id']);
        
      print('Updated image URL for ${treatment['name']}: $newImageUrl');
    }
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
    try {
      print('Fetching treatments from Supabase...'); // Debug log
      
      final response = await client
          .from('treatments')
          .select('*')
          .order('name');
      
      print('Raw treatments response: $response'); // Debug the raw response
      
      if (response == null) {
        print('Error: Null response when fetching treatments');
        return [];
      }
      
      final treatments = List<Map<String, dynamic>>.from(response);
      print('Parsed ${treatments.length} treatments'); // Log the count
      
      // Log the first treatment to check structure
      if (treatments.isNotEmpty) {
        print('Sample treatment: ${treatments[0]}');
      }
      
      return treatments;
    } catch (e) {
      print('Exception when fetching treatments: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
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
    
    // Usar createAppointment para aprovechar toda su funcionalidad
    await createAppointment({
      'patient_id': user.id,
      'treatment_id': treatmentId,
      'clinic_id': clinicId,
      'appointment_date': date.toIso8601String(),
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

// Modifica el método getUserAppointments para mejorar el manejo de errores

  Future<List<Map<String, dynamic>>> getUserAppointments() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      print('Obteniendo citas para usuario: $userId');
      
      // Usar el nombre correcto de columna: 'patient_id'
      final response = await client
        .from('appointments')
        .select('''
          *,
          treatment:treatments(*),
          clinic:clinics(*)
        ''')
        .eq('patient_id', userId) // Nombre correcto de la columna
        .order('appointment_date', ascending: true);
        
      print('Respuesta de citas: $response');
      
      if (response == null) {
        return [];
      }
      
      final appointments = List<Map<String, dynamic>>.from(response);
      
      // Verificar que cada cita tenga los campos requeridos
      for (var appointment in appointments) {
        if (appointment['treatment'] == null) {
          print('Advertencia: Cita sin tratamiento: ${appointment['id']}');
        }
        if (appointment['clinic'] == null) {
          print('Advertencia: Cita sin clínica: ${appointment['id']}');
        }
      }
      
      print('Citas recuperadas: ${appointments.length}');
      if (appointments.isNotEmpty) {
        print('Primera cita - ID clínica: ${appointments[0]['clinic_id']}');
        print('Datos de clínica en cita: ${appointments[0]['clinic']}');
      }
      
      return appointments;
    } catch (e) {
      print('Error obteniendo citas: $e');
      rethrow;
    }
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

  // Método para actualizar el estado de una cita
  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await client
          .from('appointments')
          .update({'status': status})
          .eq('id', appointmentId);
      
      // Si la cita se cancela o reprograma, cancelar las notificaciones
      if (status == 'Cancelada' || status == 'Reprogramada') {
        await NotificationService().cancelAppointmentNotifications(appointmentId);
      }
          
      print('Appointment $appointmentId status updated to $status');
    } catch (e) {
      print('Error updating appointment status: $e');
      throw e;
    }
  }

  // Método para eliminar una cita (alternativa a cancelar)
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      await client
          .from('appointments')
          .delete()
          .eq('id', appointmentId);
          
      print('Appointment $appointmentId deleted');
    } catch (e) {
      print('Error deleting appointment: $e');
      throw e;
    }
  }

  Future<String> createAppointment(Map<String, dynamic> appointmentData) async {
    try {
      // Establecer el estado como "Confirmada" por defecto
      appointmentData['status'] = 'Confirmada';
      
      final response = await client
          .from('appointments')
          .insert(appointmentData)
          .select()
          .single();
      
      // Obtener detalles para la notificación
      final appointmentId = response['id'] as String;
      final treatmentId = response['treatment_id'] as String;
      final clinicId = response['clinic_id'] as String;
      final appointmentDate = DateTime.parse(response['appointment_date']);
      
      // Obtener nombre del tratamiento
      final treatmentResponse = await client
          .from('treatments')
          .select('name')
          .eq('id', treatmentId)
          .single();
          
      // Obtener nombre de la clínica
      final clinicResponse = await client
          .from('clinics')
          .select('name')
          .eq('id', clinicId)
          .single();
      
      // Añadir logs para depuración
      print('Programando notificaciones para cita: $appointmentId');
      print('Tratamiento: ${treatmentResponse['name']}, Clínica: ${clinicResponse['name']}');
      print('Fecha: $appointmentDate, Estado: ${response['status']}');
      
      // Programar notificaciones
      await NotificationService().scheduleAppointmentNotifications(
        appointmentId,
        treatmentResponse['name'],
        clinicResponse['name'],
        appointmentDate,
      );
      
      return appointmentId;
    } catch (e) {
      print('Error creating appointment: $e');
      throw e;
    }
  }
}




