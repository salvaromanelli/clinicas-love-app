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
import 'package:path_provider/path_provider.dart';

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
    required String phoneNumber,
    DateTime? birthDate, // Añadir este parámetro
  }) async {
    try {
      print("Iniciando registro con email: $email y nombre: $fullName");
      
      // Paso 1: Registrar al usuario con Auth
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'birth_date': birthDate?.toIso8601String(), // Añadir fecha de nacimiento
        },
        emailRedirectTo: 'io.supabase.flutterquickstart://login-callback/'
      );
      
      // Si el usuario se creó exitosamente
      if (response.user != null) {
        try {
          final now = DateTime.now().toIso8601String();
          
          await client.from('profiles').update({
            'full_name': fullName,
            'phone_number': phoneNumber,
            'birth_date': birthDate?.toIso8601String(), // Añadir fecha de nacimiento
            'updated_at': now
          }).eq('id', response.user!.id);
          
          print("Perfil actualizado correctamente");
        } catch (profileError) {
          print("Error actualizando perfil: $profileError");
        }
      }
      
      return response;
    } catch (e) {
      print("Error detallado en signUp: $e");
      rethrow;
    }
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
    try {
      // Nombre del bucket
      const String bucketName = 'simulations';
      
      // Verificar si el bucket existe, si no, crearlo (para desarrollo)
      try {
        await client.storage.getBucket(bucketName);
      } catch (e) {
        if (e.toString().contains('Bucket not found')) {
          print('El bucket no existe, intentando crearlo...');
          try {
            await client.storage.createBucket(bucketName, const BucketOptions(
              public: true, // Para desarrollo
            ));
            print('Bucket creado correctamente');
          } catch (createError) {
            print('Error al crear bucket: $createError');
            // Si no se puede crear, intentar con otro nombre o usar modo de desarrollo
            return _saveSimulationToLocal(treatmentId, beforeImage, afterImage);
          }
        } else {
          // Si es un error diferente a "Bucket not found"
          print('Error al verificar bucket: $e');
          return _saveSimulationToLocal(treatmentId, beforeImage, afterImage);
        }
      }
      
      // Continuar con la subida de archivos si el bucket existe o se creó correctamente
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final beforeFileName = 'before_${userId}_$timestamp.jpg';
      final afterFileName = 'after_${userId}_$timestamp.jpg';
      
      // Subir imagen "antes"
      await client.storage.from(bucketName).upload(
        'before/$beforeFileName',
        beforeImage,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      // Subir imagen "después"
      await client.storage.from(bucketName).upload(
        'after/$afterFileName',
        afterImage,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      // Obtener URLs públicas
      final beforeUrl = client.storage.from(bucketName).getPublicUrl('before/$beforeFileName');
      final afterUrl = client.storage.from(bucketName).getPublicUrl('after/$afterFileName');
      
      // Guardar registro en la base de datos
      final simulationData = {
        'patient_id': userId,
        'treatment_id': treatmentId,
        'before_image_url': beforeUrl,
        'after_image_url': afterUrl,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final response = await client
          .from('treatment_simulations')
          .insert(simulationData)
          .select('id')
          .single();
      
      return response['id'] as String;
      
    } catch (e) {
      print('Error guardando simulación: $e');
      return _saveSimulationToLocal(treatmentId, beforeImage, afterImage);
    }
  }

  Future<String> _saveSimulationToLocal(
    String treatmentId, 
    File beforeImage, 
    File afterImage
  ) async {
    try {
      // Generar un ID único para la simulación
      final simulationId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      
      // Guardar copias locales de las imágenes en el directorio temporal
      final tempDir = await getTemporaryDirectory();
      
      // Crear directorio para simulaciones si no existe
      final simDir = Directory('${tempDir.path}/simulations');
      if (!await simDir.exists()) {
        await simDir.create(recursive: true);
      }
      
      // Copiar imágenes con nombres que incluyen el ID de simulación
      final localBeforeImage = File('${simDir.path}/${simulationId}_before.jpg');
      final localAfterImage = File('${simDir.path}/${simulationId}_after.jpg');
      
      await beforeImage.copy(localBeforeImage.path);
      await afterImage.copy(localAfterImage.path);
      
      // Añadir la simulación a una lista local simulada en modo offline
      final Map<String, dynamic> simulationData = {
        'id': simulationId,
        'treatment_id': treatmentId,
        'patient_id': client.auth.currentUser?.id ?? 'guest',
        'before_image_url': 'file://${localBeforeImage.path}',
        'after_image_url': 'file://${localAfterImage.path}',
        'created_at': DateTime.now().toIso8601String(),
        'is_local': true,
      };
      
      // Podrías guardar en SharedPreferences para persistencia entre sesiones
      
      print('Simulación guardada localmente con ID: $simulationId');
      print('Imágenes guardadas en: ${simDir.path}');
      print('URLs locales: ${simulationData['before_image_url']} y ${simulationData['after_image_url']}');
      
      return simulationId;
    } catch (e) {
      print('Error en modo de respaldo: $e');
      throw Exception('No se pudo guardar la simulación: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getLocalSimulations() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final simDir = Directory('${tempDir.path}/simulations');
      
      if (!await simDir.exists()) {
        return [];
      }
      
      // Validar que el directorio tiene archivos
      final List<FileSystemEntity> files = await simDir.list().toList();
      print('Archivos encontrados: ${files.length}');
      
      final Map<String, Map<String, dynamic>> simulationsMap = {};
      
      // Procesar los archivos para encontrar pares before/after
      for (var file in files) {
        if (file is File) {
          final filename = path.basename(file.path);
          print('Analizando archivo: $filename');
          
          final match = RegExp(r'local_(\d+)_(before|after)\.jpg').firstMatch(filename);
          
          if (match != null) {
            final simId = 'local_${match.group(1)}';
            final type = match.group(2);
            print('Match encontrado - ID: $simId, Tipo: $type');
            
            // Si el ID no existe en el mapa, crearlo
            if (!simulationsMap.containsKey(simId)) {
              simulationsMap[simId] = {
                'id': simId,
                'treatment_id': 'local_treatment',
                'created_at': DateTime.fromMillisecondsSinceEpoch(
                  int.parse(match.group(1)!)
                ).toIso8601String(),
                'is_local': true,
              };
            }
            
            // Agregar URL de la imagen según tipo
            if (type == 'before') {
              simulationsMap[simId]!['before_image_url'] = 'file://${file.path}';
            } else {
              simulationsMap[simId]!['after_image_url'] = 'file://${file.path}';
            }
          }
        }
      }
      
      // Verificar que cada simulación tenga ambas imágenes (before y after)
      simulationsMap.values.forEach((sim) {
        print('Simulación: ${sim['id']}');
        print('  Before URL: ${sim['before_image_url'] ?? 'FALTA'}');
        print('  After URL: ${sim['after_image_url'] ?? 'FALTA'}');
      });
      
      // Convertir a lista y ordenar por fecha de creación (más reciente primero)
      final simulations = simulationsMap.values.where((sim) {
        // Solo incluir simulaciones que tengan ambas imágenes
        return sim.containsKey('before_image_url') && 
              sim.containsKey('after_image_url');
      }).toList();
      
      simulations.sort((a, b) => b['created_at'].compareTo(a['created_at']));
      print('Simulaciones locales encontradas: ${simulations.length}');
      
      return simulations;
    } catch (e) {
      print('Error recuperando simulaciones locales: $e');
      return [];
    }
  }

  // Método para obtener simulaciones del usuario actual
  Future<List<Map<String, dynamic>>> getUserSimulations() async {
    try {
      final userId = client.auth.currentUser?.id;
      
      // Si hay usuario autenticado, intentamos obtener datos de Supabase
      if (userId != null) {
        try {
          final response = await client
            .from('treatment_simulations')
            .select('''
              *,
              treatment:treatments(*)
            ''')
            .eq('patient_id', userId)
            .order('created_at', ascending: false);
            
          if (response != null) {
            final onlineSimulations = List<Map<String, dynamic>>.from(response);
            
            // También intentamos obtener simulaciones locales
            final localSimulations = await _getLocalSimulations();
            
            // Combinar ambas listas
            return [...onlineSimulations, ...localSimulations];
          }
        } catch (e) {
          print('Error obteniendo simulaciones online, buscando solo locales: $e');
        }
      }
      
      // Si no hay usuario o falló la carga online, devolvemos solo locales
      return await _getLocalSimulations();
      
    } catch (e) {
      print('Error al recuperar simulaciones: $e');
      return [];
    }
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
  // Promociones

  Future<List<Map<String, dynamic>>> getMonthlyPromotions() async {
    try {
      // Obtener promociones de la tabla 'promotions' en Supabase
      // que estén activas este mes
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      
      final response = await client
        .from('promotions')
        .select('''
          *,
          treatment:treatments(*)
        ''')
        .gte('start_date', firstDayOfMonth.toIso8601String())
        .lte('end_date', lastDayOfMonth.toIso8601String())
        .eq('is_active', true)
        .order('discount_percentage', ascending: false);
        
      if (response == null) {
        return [];
      }
      
      // Convertir los datos a formato compatible para mostrar en UI
      return List<Map<String, dynamic>>.from(response).map((promo) {
        final treatment = promo['treatment'] as Map<String, dynamic>?;
        
        return {
          'id': promo['id'],
          'title': treatment?['name'] ?? 'Promoción Especial',
          'description': treatment?['description'] ?? promo['description'] ?? '',
          'discount': '${promo['discount_percentage']}% de descuento',
          'image_url': promo['image_url'] ?? treatment?['image_url'] ?? 'https://placehold.co/600x300',
          'treatment_id': treatment?['id'],
          'original_price': treatment?['price'],
          'discounted_price': treatment != null && treatment['price'] != null && promo['discount_percentage'] != null
            ? (treatment['price'] * (100 - promo['discount_percentage']) / 100).toStringAsFixed(2)
            : null,
        };
      }).toList();
    } catch (e) {
      print('Error obteniendo promociones mensuales: $e');
      rethrow;
    }
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
    // Asegurar que los IDs estén en el formato correcto
    if (appointmentData['treatment_id'] != null && appointmentData['treatment_id'] is int) {
      appointmentData['treatment_id'] = appointmentData['treatment_id'].toString();
    }
    
    if (appointmentData['clinic_id'] != null && appointmentData['clinic_id'] is int) {
      appointmentData['clinic_id'] = appointmentData['clinic_id'].toString();
    }
    
    // Establecer el estado como "Confirmada" por defecto
    appointmentData['status'] = 'Confirmada';
    
    final response = await client
        .from('appointments')
        .insert(appointmentData)
        .select()
        .single();
    
    // Obtener detalles para la notificación
    final appointmentId = response['id'].toString();
    final treatmentId = response['treatment_id'].toString();
    final clinicId = response['clinic_id'].toString();
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

  // Obtener el ID de usuario actual
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  // Verificar si el usuario ha iniciado sesión
  bool isUserLoggedIn() {
    return client.auth.currentUser != null;
  }

  // Guardar un nuevo descuento
  Future<void> saveDiscount({
    required String code,
    required int percentage,
    required String source,
    int validityDays = 90,
  }) async {
    final userId = getCurrentUserId();
    if (userId == null) {
      throw Exception('No hay usuario logueado');
    }
    
    final now = DateTime.now();
    final expiryDate = now.add(Duration(days: validityDays));
    
    final discountData = {
      'user_id': userId,
      'code': code,
      'percentage': percentage,
      'is_used': false,
      'created_at': now.toIso8601String(),
      'expires_at': expiryDate.toIso8601String(),
      'source': source
    };
    
    await client.from('discounts').insert(discountData);
  }

  // Obtener descuentos no usados del usuario
  Future<List<Map<String, dynamic>>> getUserActiveDiscounts() async {
    final userId = getCurrentUserId();
    if (userId == null) {
      return [];
    }
    
    final now = DateTime.now().toIso8601String();
    
    final response = await client
      .from('discounts')
      .select()
      .eq('user_id', userId)
      .eq('is_used', false)
      .gt('expires_at', now)
      .order('created_at', ascending: false);
      
    if (response == null) {
      return [];
    }
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Marcar un descuento como usado
  Future<void> useDiscount(String discountId) async {
    await client
      .from('discounts')
      .update({'is_used': true, 'used_at': DateTime.now().toIso8601String()})
      .eq('id', discountId);
  }

  Future<User?> getCurrentUser() async {
  try {
    // Obtener la sesión actual
    final session = client.auth.currentSession;
    
    if (session == null) {
      print('No hay sesión de usuario activa');
      return null;
    }
    
    // Obtener el usuario actual
    final user = client.auth.currentUser;
    
    if (user == null) {
      print('No se pudo obtener el usuario a pesar de tener sesión');
      return null;
    }
    
    print('Usuario obtenido: ${user.id}');
    return user;
  } catch (e) {
    print('Error al obtener usuario actual: $e');
    return null;
  }
}
}




