import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvailableTimeSlot {
  final String id;
  final DateTime dateTime;
  final String clinicId;
  final List<String> availableTreatmentIds;
  bool isBooked = false;
  
  AvailableTimeSlot({
    required this.id,
    required this.dateTime,
    required this.clinicId,
    required this.availableTreatmentIds,
  });
}

class AppointmentInfo {
  String? treatmentId;
  String? clinicId;
  DateTime? date;
  String? notes;
  String? patientName;
  String? contactNumber;
  
  bool get hasBasicInfo => treatmentId != null;
  
  bool get isComplete => 
      treatmentId != null && 
      clinicId != null && 
      date != null;
  
  @override
  String toString() {
    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    return 'Cita para: ${treatmentId ?? "No especificado"}\n'
           'Clínica: ${clinicId ?? "No especificada"}\n'
           'Fecha: ${date != null ? dateFormatter.format(date!) : "No especificada"}\n'
           'Notas: ${notes ?? "Ninguna"}';
  }
}

class AppointmentService {
  
  // Diccionario de tratamientos disponibles
List<String> get availableTreatmentCategories => [
  'Tratamientos Faciales',
  'Medicina Estética',
  'Cirugía Estética',
  'Tratamientos Corporales',
  'Tratamientos Láser',
  'Consultas'
];
  
  // Diccionario de clínicas disponibles
  final Map<String, String> _clinics = {
    'madrid': 'Clínicas Love - Madrid',
    'barcelona': 'Clínicas Love - Barcelona',
    'tenerife': 'Clínicas Love - Tenerife',
    'malaga': 'Clínicas Love - Málaga',
    'sevilla': 'Clínicas Love - Sevilla',
  };

  // Mapa que almacena los horarios disponibles por día y clínica
  final Map<String, List<AvailableTimeSlot>> _availableSlots = {};

  // Método para generar horarios disponibles para prueba (en producción, esto vendría de tu API)
  void _generateAvailableSlots() {
    // Limpiar slots existentes
    _availableSlots.clear();
    
    // Generar para los próximos 14 días
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    
    for (int day = 1; day <= 14; day++) {
      final currentDate = now.add(Duration(days: day));
      // Saltar domingos (día 7)
      if (currentDate.weekday == 7) continue;
      
      final dateStr = formatter.format(currentDate);
      _availableSlots[dateStr] = [];
      
      // Para cada clínica
      for (final clinicId in _clinics.keys) {
        // Horarios de mañana y tarde (depende de la clínica)
        final morningHours = [10, 11, 12];
        final afternoonHours = [16, 17, 18, 19];
        
        // Generar slots de mañana
        for (final hour in morningHours) {
          final slotDateTime = DateTime(
              currentDate.year, 
              currentDate.month, 
              currentDate.day, 
              hour, 
              0);
              
          _availableSlots[dateStr]!.add(AvailableTimeSlot(
            id: '${clinicId}_${dateStr}_${hour}_00',
            dateTime: slotDateTime,
            clinicId: clinicId,
            availableTreatmentIds: _treatmentsWithCategories.keys.toList(),
          ));
        }
        
        // Generar slots de tarde
        for (final hour in afternoonHours) {
          final slotDateTime = DateTime(
              currentDate.year, 
              currentDate.month, 
              currentDate.day, 
              hour, 
              0);
              
          _availableSlots[dateStr]!.add(AvailableTimeSlot(
            id: '${clinicId}_${dateStr}_${hour}_00',
            dateTime: slotDateTime,
            clinicId: clinicId,
            availableTreatmentIds: _treatmentsWithCategories.keys.toList(),
          ));
        }
      }
    }
    
    debugPrint('✅ Generados ${_availableSlots.length} días con horarios disponibles');
  }

  // Obtener slots disponibles para un día específico y una clínica
  List<AvailableTimeSlot> getAvailableSlotsForDate(DateTime date, String clinicId) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    if (!_availableSlots.containsKey(dateStr)) {
      return [];
    }
    
    return _availableSlots[dateStr]!
        .where((slot) => 
            slot.clinicId == clinicId && 
            !slot.isBooked)
        .toList();
  }

  // Obtener próximos días disponibles para una clínica
  List<DateTime> getAvailableDates(String clinicId, {int limit = 5}) {
    final result = <DateTime>[];
    
    for (final dateStr in _availableSlots.keys) {
      // Verificar si hay slots disponibles para esta clínica en este día
      final hasSlotsForClinic = _availableSlots[dateStr]!
          .any((slot) => slot.clinicId == clinicId && !slot.isBooked);
          
      if (hasSlotsForClinic) {
        final parts = dateStr.split('-');
        final date = DateTime(
            int.parse(parts[0]), 
            int.parse(parts[1]), 
            int.parse(parts[2]));
        result.add(date);
        
        if (result.length >= limit) break;
      }
    }
    
    return result;
  }

  // Método para confirmar una cita
  Future<bool> confirmAppointment(AppointmentInfo info) async {
    // Validar que tenemos toda la información necesaria
    if (!info.isComplete || info.date == null) {
      debugPrint('❌ No se puede confirmar cita incompleta');
      return false;
    }
    
    // Verificar disponibilidad y marcar como reservado
    final dateStr = DateFormat('yyyy-MM-dd').format(info.date!);
    
    if (!_availableSlots.containsKey(dateStr)) {
      debugPrint('❌ No hay disponibilidad para la fecha seleccionada');
      return false;
    }
    
    // Buscar el slot específico
    final targetHour = info.date!.hour;
    final targetMinute = info.date!.minute;
    
    bool found = false;
    for (final slot in _availableSlots[dateStr]!) {
      if (slot.clinicId == info.clinicId && 
          slot.dateTime.hour == targetHour && 
          slot.dateTime.minute == targetMinute &&
          !slot.isBooked) {
        
        // Verificar que el tratamiento esté disponible en este horario
        if (!slot.availableTreatmentIds.contains(info.treatmentId)) {
          debugPrint('❌ El tratamiento no está disponible en este horario');
          return false;
        }
        
        // Marcar como reservado
        slot.isBooked = true;
        found = true;
        
        // En una app real, aquí guardarías la cita en la base de datos
        // await _saveAppointmentToDatabase(info, slot.id);
        
        debugPrint('✅ Cita confirmada para ${DateFormat('yyyy-MM-dd HH:mm').format(info.date!)}');
        break;
      }
    }
    
    if (!found) {
      debugPrint('❌ No se encontró disponibilidad para el horario específico');
      return false;
    }
    
    // Guardar la cita en el almacenamiento local o en la nube
    await _saveAppointment(info);
    
    return true;
  }

  // Guardar la cita (usando SharedPreferences para demo)
  Future<void> _saveAppointment(AppointmentInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtener lista de citas existentes o crear nueva
      List<String> savedAppointments = prefs.getStringList('user_appointments') ?? [];
      
      // Convertir la cita a JSON
      final appointmentJson = {
        'treatmentId': info.treatmentId,
        'treatmentName': availableTreatments[info.treatmentId],
        'clinicId': info.clinicId,
        'clinicName': availableClinics[info.clinicId],
        'date': info.date?.millisecondsSinceEpoch,
        'notes': info.notes,
        'patientName': info.patientName ?? 'Usuario actual',
        'contactNumber': info.contactNumber,
        'status': 'confirmed'
      };
      
      // Añadir a la lista
      savedAppointments.add(jsonEncode(appointmentJson));
      
      // Guardar la lista actualizada
      await prefs.setStringList('user_appointments', savedAppointments);
      
      debugPrint('✅ Cita guardada en almacenamiento local');
    } catch (e) {
      debugPrint('❌ Error guardando cita: $e');
    }
  }

  // Obtener todas las citas del usuario
  Future<List<Map<String, dynamic>>> getUserAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtener lista de citas guardadas
      List<String> savedAppointments = prefs.getStringList('user_appointments') ?? [];
      
      // Convertir de JSON a objetos
      return savedAppointments
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo citas: $e');
      return [];
    }
  }

  // Constructor
  AppointmentService() {
    // Generar horarios disponibles al inicializar
    _generateAvailableSlots();
  }

  /// Getter para acceder a las clínicas disponibles
  Map<String, String> get availableClinics => _clinics;

  // Mapa detallado de tratamientos con categorías
  final Map<String, Map<String, dynamic>> _treatmentsWithCategories = {
    // TRATAMIENTOS FACIALES
    'eliminacion_ojeras': {
      'name': 'Eliminación de ojeras',
      'category': 'Tratamientos Faciales',
      'duration': 45,
      'description': 'Tratamiento específico para reducir la apariencia de las ojeras con ácido hialurónico'
    },
    'microdermoabrasion': {
      'name': 'Microdermoabrasión',
      'category': 'Tratamientos Faciales',
      'duration': 50,
      'description': 'Exfoliación mecánica que elimina las capas superficiales de la piel'
    },
    'surco_nasogeniano': {
      'name': 'Surco Nasogeniano',
      'category': 'Tratamientos Faciales',
      'duration': 30,
      'description': 'Tratamiento para suavizar las arrugas de la sonrisa con ácido hialurónico'
    },
    'armonizacion_facial': {
      'name': 'Armonización facial',
      'category': 'Tratamientos Faciales',
      'duration': 60,
      'description': 'Procedimiento que combina diferentes técnicas para equilibrar las facciones'
    },
    'eliminacion_arrugas': {
      'name': 'Eliminación de arrugas',
      'category': 'Tratamientos Faciales',
      'duration': 45,
      'description': 'Tratamientos para suavizar y reducir líneas de expresión'
    },
    
    // MEDICINA ESTÉTICA
    'botox': {
      'name': 'Botox',
      'category': 'Medicina Estética',
      'duration': 30,
      'description': 'Reduce arrugas de expresión mediante la aplicación de toxina botulínica'
    },
    'acido_hialuronico': {
      'name': 'Ácido Hialurónico',
      'category': 'Medicina Estética',
      'duration': 45,
      'description': 'Relleno dérmico para dar volumen y definir contornos faciales'
    },
    'aumento_labios': {
      'name': 'Aumento de Labios',
      'category': 'Medicina Estética',
      'duration': 30,
      'description': 'Relleno de labios para aumentar su volumen y definir su contorno'
    },
    'lipopapada': {
      'name': 'Lipopapada',
      'category': 'Medicina Estética',
      'duration': 40,
      'description': 'Tratamiento para eliminar la papada y recuperar la armonía facial'
    },
    'rinomodelacion': {
      'name': 'Rinomodelación sin cirugía',
      'category': 'Medicina Estética',
      'duration': 45,
      'description': 'Técnica para corregir defectos menores de la nariz sin cirugía'
    },
    
    // CIRUGÍA ESTÉTICA
    'blefaroplastia': {
      'name': 'Blefaroplastia',
      'category': 'Cirugía Estética',
      'duration': 90,
      'description': 'Corrección de párpados caídos y bolsas bajo los ojos'
    },
    'aumento_pecho': {
      'name': 'Aumento de Pecho',
      'category': 'Cirugía Estética',
      'duration': 150,
      'description': 'Cirugía para aumentar el tamaño y mejorar la forma de los senos'
    },
    'bichectomia': {
      'name': 'Bichectomía',
      'category': 'Cirugía Estética',
      'duration': 60,
      'description': 'Extracción de las bolas de Bichat para estilizar el rostro'
    },
    
    // TRATAMIENTOS CORPORALES
    'presoterapia': {
      'name': 'Presoterapia',
      'category': 'Tratamientos Corporales',
      'duration': 45,
      'description': 'Drenaje linfático para reducir la retención de líquidos'
    },
    'radiofrecuencia': {
      'name': 'Radiofrecuencia',
      'category': 'Tratamientos Corporales',
      'duration': 50,
      'description': 'Tratamiento para reafirmar la piel y reducir la flacidez'
    },
    
    // TRATAMIENTOS LÁSER
    'k_laser': {
      'name': 'K-Láser',
      'category': 'Tratamientos Láser',
      'duration': 40,
      'description': 'Mejora la textura de la piel y reduce cicatrices'
    },
    'laser_co2': {
      'name': 'Láser CO2',
      'category': 'Tratamientos Láser',
      'duration': 60,
      'description': 'Tratamiento para rejuvenecimiento facial y tratamiento de cicatrices'
    },
    
    // CONSULTAS GENERALES
    'general_consultation': {
      'name': 'Consulta General',
      'category': 'Consultas',
      'duration': 30,
      'description': 'Evaluación inicial para determinar el tratamiento adecuado'
    },
    'valoracion_estetica': {
      'name': 'Valoración Estética Completa',
      'category': 'Consultas',
      'duration': 45,
      'description': 'Análisis personalizado de necesidades estéticas'
    }
  };

  

  Map<String, String> get availableTreatments {
  final result = <String, String>{};
  _treatmentsWithCategories.forEach((key, value) {
    result[key] = value['name'];
  });
  return result;
}

  /// Devuelve los tratamientos agrupados por categoría
  Map<String, List<Map<String, dynamic>>> get treatmentsByCategory {
    final result = <String, List<Map<String, dynamic>>>{};
    
    // Inicializar listas vacías para cada categoría
    for (final category in availableTreatmentCategories) {
      result[category] = [];
    }
    
    // Agrupar tratamientos por categoría
    _treatmentsWithCategories.forEach((id, info) {
      final category = info['category'];
      if (result.containsKey(category)) {
        result[category]!.add({
          'id': id,
          ...info,
        });
      }
    });
    
    return result;
  }
  
  // Extraer información de cita de un mensaje
  AppointmentInfo extractAppointmentInfo(String message) {
    message = message.toLowerCase();
    AppointmentInfo info = AppointmentInfo();
    
    // Detectar tratamiento
    for (var entry in availableTreatments.entries) {
      if (message.contains(entry.key)) {
        info.treatmentId = entry.key;
        break;
      }
    }
    
    // Detectar clínica
    for (var entry in availableClinics.entries) {
      if (message.contains(entry.key)) {
        info.clinicId = entry.key;
        break;
      }
    }
    
    // Detectar posibles fechas (implementación básica)
    // Esto requeriría una lógica más compleja para un uso real
    RegExp dateRegex = RegExp(r'\b\d{1,2}\s+de\s+\w+\b');
    Match? dateMatch = dateRegex.firstMatch(message);
    if (dateMatch != null) {
      // Aquí convertirías el texto de la fecha en un objeto DateTime
      // Esta es una implementación simplificada
      info.notes = "Fecha mencionada: ${dateMatch.group(0)}";
    }
    
    debugPrint('Información de cita extraída: ${info.toString()}');
    return info;
  }
  
  // Verificar si un mensaje contiene intención de agendar
  bool hasBookingIntent(String message) {
    message = message.toLowerCase();
    List<String> bookingKeywords = [
      'cita', 'agendar', 'reservar', 'programar', 'consulta', 
      'visita', 'disponibilidad', 'horario'
    ];
    
    return bookingKeywords.any((keyword) => message.contains(keyword));
  }

    Future<String?> findTreatmentIdByName(String name) async {
    // Normalizar para mejor comparación
    final normalizedName = name.toLowerCase().trim();
    
    // Buscar coincidencias exactas primero
    for (final entry in availableTreatments.entries) {
      if (entry.value.toLowerCase() == normalizedName) {
        return entry.key;
      }
    }
    
    // Buscar coincidencias parciales
    for (final entry in availableTreatments.entries) {
      if (entry.value.toLowerCase().contains(normalizedName) || 
          normalizedName.contains(entry.value.toLowerCase())) {
        return entry.key;
      }
    }
    
    return null;
  } 
}