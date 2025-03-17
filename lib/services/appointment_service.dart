import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

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
  final Map<String, String> availableTreatments = {
    'blanqueamiento': 'Blanqueamiento Dental',
    'limpieza': 'Limpieza Dental Profunda',
    'ortodoncia': 'Consulta de Ortodoncia',
    'botox': 'Aplicación de Botox',
    'rellenos': 'Rellenos Faciales',
    'implantes': 'Implantes Dentales',
    'consulta': 'Consulta General',
  };
  
  // Diccionario de clínicas disponibles
  final Map<String, String> availableClinics = {
    'centro': 'Clínica Love - Centro',
    'norte': 'Clínica Love - Zona Norte',
    'sur': 'Clínica Love - Zona Sur',
    'polanco': 'Clínica Love - Polanco',
    'satelite': 'Clínica Love - Satélite',
  };
  
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
}