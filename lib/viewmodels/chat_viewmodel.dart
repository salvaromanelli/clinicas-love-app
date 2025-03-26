import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/claude_assistant_service.dart';
import '/services/appointment_service.dart' as appointment_service;
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import '/i18n/app_localizations.dart';
import '/services/knowledge_base.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';


class TimeSlot {
  final DateTime dateTime;
  final bool available;
  
  TimeSlot({required this.dateTime, this.available = true});
}


class ChatViewModel extends ChangeNotifier {
  final ClaudeAssistantService _aiService;
  final appointment_service.AppointmentService _appointmentService;
  final AppLocalizations localizations;
  final KnowledgeBase _knowledgeBase;
  
  List<ChatMessage> messages = [];
  bool isTyping = false;
  appointment_service.AppointmentInfo? currentAppointmentInfo;
  bool isBookingFlow = false;
  
  // Variables auxiliares para el flujo de reserva
  DateTime? _currentDateSelection;
  DateTime? _currentTimeSelection;
  List<String> suggestedReplies = [];
  
  ChatViewModel({
    required ClaudeAssistantService aiService,
    required appointment_service.AppointmentService appointmentService,
    required this.localizations,
  }) : _aiService = aiService,
      _appointmentService = appointmentService,
      _knowledgeBase = KnowledgeBase() {
    _initKnowledgeBase();
    initializeDateFormatting('es');
  }

  Future<void> _initKnowledgeBase() async {
    try {
      await _knowledgeBase.initialize();
      debugPrint('✅ Base de conocimientos inicializada correctamente');
    } catch (error) {
      debugPrint('⚠️ Error inicializando base de conocimientos: $error');
    }
  }
    
  void sendWelcomeMessage() {
    final welcomeMessage = localizations.get('welcome_message');
    messages.add(ChatMessage(text: welcomeMessage, isUser: false));
    
    suggestedReplies = [
      localizations.get('what_treatments'),
      localizations.get('want_know_prices'),
      localizations.get('where_located'),
      localizations.get('need_appointment')
    ];
    
    notifyListeners();
  }
  
  // NUEVO MÉTODO PRINCIPAL: Procesa mensajes con IA
  Future<void> sendMessage(String message) async {
    try {
      messages.add(ChatMessage(text: message, isUser: true));
      isTyping = true;
      notifyListeners();
      
      // Preparar estado actual para la IA
      final currentState = {
        'is_booking_flow': isBookingFlow,
        'current_treatment': currentAppointmentInfo?.treatmentId != null ? 
            _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId] : null,
        'current_clinic': currentAppointmentInfo?.clinicId != null ?
            _appointmentService.availableClinics[currentAppointmentInfo!.clinicId] : null,
        'current_date': _currentDateSelection?.toString(),
        'current_time': _currentTimeSelection?.toString(),
      };
      
      // Procesar con Function Calling para aprovechar la IA
      final processedMessage = await _aiService.processMessage(
        message,
        messages.sublist(0, messages.length - 1),  // Historia previa
        currentState
      );
      
      // Manejar respuesta basada en si es intención de reserva o no
      if (processedMessage.isBookingIntent && processedMessage.bookingInfo != null) {
        await _handleAIBookingIntent(processedMessage);
      } else {
        // Mensaje normal - mostrar respuesta directamente
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        
        // Actualizar sugerencias basadas en el contexto proporcionado
        if (processedMessage.additionalContext != null) {
          _generateSuggestionsBasedOnContext(message, processedMessage.text);
        } else {
          // Sugerencias generales
          _updateSuggestedReplies(message, processedMessage.text);
        }
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      messages.add(ChatMessage(
        text: localizations.get('chat_error') ?? 
            "Lo siento, ha ocurrido un error al procesar tu mensaje.",
        isUser: false
      ));
    } finally {
      isTyping = false;
      notifyListeners();
    }
  }
  
  // SIMPLIFICADO: Genera sugerencias basadas en contexto detectado por la IA
  void _generateSuggestionsBasedOnContext(String userMessage, String aiResponse) {
    // Extraer temas clave de la respuesta
    final text = (userMessage + " " + aiResponse).toLowerCase();
    
    if (text.contains("botox") || text.contains("relleno")) {
      suggestedReplies = [
        localizations.get('which_areas') ?? "¿En qué zonas se aplica?",
        localizations.get('effect_duration') ?? "¿Cuánto dura el efecto?",
        localizations.get('what_is_price') ?? "¿Cuál es el precio?"
      ];
    } else if (text.contains("precio") || text.contains("costo")) {
      suggestedReplies = [
        localizations.get('have_promotions') ?? "¿Tienen promociones?",
        localizations.get('accept_cards') ?? "¿Aceptan tarjetas?",
        localizations.get('schedule_appointment') ?? "Quiero agendar una cita"
      ];
    } else {
      // Sugerencias por defecto
      suggestedReplies = [
        localizations.get('see_available_treatments') ?? "Ver tratamientos",
        localizations.get('consultation_prices') ?? "Precios de consulta",
        localizations.get('schedule_appointment') ?? "Agendar una cita",
      ];
    }
  }
  
  // SIMPLIFICADO: Maneja intenciones de reserva detectadas por la IA
  Future<void> _handleAIBookingIntent(ProcessedMessage processedMessage) async {
    final bookingInfo = processedMessage.bookingInfo!;
    isBookingFlow = true;
    currentAppointmentInfo ??= appointment_service.AppointmentInfo();
    
    // Extraer información detectada por la IA
    final intentType = bookingInfo['intent_type'];
    final treatment = bookingInfo['treatment'];
    final clinic = bookingInfo['clinic'];
    final dateRef = bookingInfo['date_reference'];
    final timeRef = bookingInfo['time_reference'];
    final confirmation = bookingInfo['confirmation'] == true;
    
    // Manejar diferentes etapas del flujo de reserva
    switch (intentType) {
      case 'booking':
      case 'booking_treatment':
        // Procesar tratamiento detectado
        if (treatment != null) {
          await _processTreatmentFromAI(treatment);
        }
        
        // Mostrar mensaje de la IA
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        
        // Decidir siguiente paso
        if (currentAppointmentInfo?.treatmentId != null) {
          if (clinic != null) {
            await _processClinicFromAI(clinic);
          } else {
            await _startBookingFlow();
          }
        } else {
          await _startTreatmentSelection();
        }
        break;
        
      case 'booking_clinic':
        if (clinic != null) {
          await _processClinicFromAI(clinic);
        }
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        await _showAvailableDates();
        break;
        
      case 'booking_date':
        if (dateRef != null) {
          await _processDateFromAI(dateRef);
        }
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        break;
        
      case 'booking_time':
        if (timeRef != null) {
          await _processTimeFromAI(timeRef);
        }
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        break;
        
      case 'booking_confirm':
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        if (confirmation) {
          await _confirmBooking();
        } else {
          await _cancelBooking();
        }
        break;
        
      default:
        // Continuar flujo normal
        messages.add(ChatMessage(text: processedMessage.text, isUser: false));
        break;
    }
  }
  
  // Métodos auxiliares para procesar información extraída por la IA
  
  Future<void> _processTreatmentFromAI(String treatment) async {
    // Buscar tratamiento en los disponibles
    for (var entry in _appointmentService.availableTreatments.entries) {
      if (entry.value.toLowerCase().contains(treatment.toLowerCase())) {
        currentAppointmentInfo?.treatmentId = entry.key;
        debugPrint('✅ Tratamiento IA detectado: ${entry.value}');
        return;
      }
    }
    
    // Si no encontramos coincidencia, usar consulta general
    currentAppointmentInfo?.treatmentId = 'general_consultation';
    debugPrint('ℹ️ No se encontró tratamiento específico, asignando consulta general');
  }
  
  Future<void> _processClinicFromAI(String clinic) async {
    for (var entry in _appointmentService.availableClinics.entries) {
      if (entry.value.toLowerCase().contains(clinic.toLowerCase())) {
        currentAppointmentInfo?.clinicId = entry.key;
        debugPrint('✅ Clínica IA detectada: ${entry.value}');
        return;
      }
    }
  }
  
  Future<void> _processDateFromAI(String dateReference) async {
    // Convertir referencia ("segunda semana de abril") a fecha real
    // Aquí OpenAI ya hizo el análisis, por lo que podríamos tener una implementación más simple
    final dates = _appointmentService.getAvailableDates(currentAppointmentInfo!.clinicId!);
    
    // Buscar una fecha que coincida con la referencia de fecha solicitada
    DateTime? matchingDate;
    
    // Para simplificar, compararemos el texto normalizado
    final normalizedRef = dateReference.toLowerCase();
    
    // Buscar coincidencias con nombres de mes
    for (final date in dates) {
      final monthName = DateFormat('MMMM', 'es').format(date).toLowerCase();
      if (normalizedRef.contains(monthName)) {
        // Si menciona una semana específica, intentar aproximarse
        if (normalizedRef.contains('primer') || normalizedRef.contains('primera')) {
          if (date.day <= 7) matchingDate = date;
        } else if (normalizedRef.contains('segunda')) {
          if (date.day > 7 && date.day <= 14) matchingDate = date;
        } else if (normalizedRef.contains('tercer') || normalizedRef.contains('tercera')) {
          if (date.day > 14 && date.day <= 21) matchingDate = date;
        } else if (normalizedRef.contains('cuarta')) {
          if (date.day > 21) matchingDate = date;
        } else {
          // Si solo menciona el mes, tomar la primera fecha disponible
          matchingDate = date;
          break;
        }
      }
      
      // Si ya encontramos coincidencia, salir
      if (matchingDate != null) break;
    }
    
    if (matchingDate != null) {
      _currentDateSelection = matchingDate;
      await _showAvailableTimeSlots(matchingDate);
    } else {
      // Si no se encontró coincidencia, mostrar todas las fechas
      await _showAvailableDates();
    }
  }

  
  Future<void> _processTimeFromAI(String timeReference) async {
    if (_currentDateSelection == null) return;
    
    final slots = _appointmentService.getAvailableSlotsForDate(
      _currentDateSelection!, 
      currentAppointmentInfo!.clinicId!
    );
    
    if (slots.isEmpty) {
      await _showAvailableTimeSlots(_currentDateSelection!);
      return;
    }
    
    // Buscar slots que coincidan con la referencia de tiempo
    final lowerTimeRef = timeReference.toLowerCase();
    appointment_service.AvailableTimeSlot? matchingSlot;
    
    // Detectar si menciona mañana o tarde
    bool prefersMorning = lowerTimeRef.contains('mañana');
    bool prefersAfternoon = lowerTimeRef.contains('tarde');
    
    // Extraer hora específica si se menciona
    RegExp hourPattern = RegExp(r'(\d{1,2})(?::(\d{2}))?');
    Match? hourMatch = hourPattern.firstMatch(lowerTimeRef);
    
    if (hourMatch != null) {
      int hour = int.parse(hourMatch.group(1)!);
      
      // Ajustar AM/PM si necesario
      if (hour < 12 && (lowerTimeRef.contains('pm') || lowerTimeRef.contains('tarde'))) {
        hour += 12;
      }
      
      // Buscar slot cercano a la hora mencionada
      int closestDiff = 24;
      for (final slot in slots) {
        int diff = (slot.dateTime.hour - hour).abs();
        if (diff < closestDiff) {
          closestDiff = diff;
          matchingSlot = slot;
        }
      }
    } else if (prefersMorning) {
      // Seleccionar un slot de la mañana
      final morningSlots = slots.where((s) => s.dateTime.hour < 13).toList();
      if (morningSlots.isNotEmpty) {
        matchingSlot = morningSlots.first;
      }
    } else if (prefersAfternoon) {
      // Seleccionar un slot de la tarde
      final afternoonSlots = slots.where((s) => s.dateTime.hour >= 13).toList();
      if (afternoonSlots.isNotEmpty) {
        matchingSlot = afternoonSlots.first;
      }
    }
    
    if (matchingSlot != null) {
      _currentTimeSelection = matchingSlot.dateTime;
      currentAppointmentInfo?.date = matchingSlot.dateTime;
      
      await _showBookingSummary();
    } else {
      await _showAvailableTimeSlots(_currentDateSelection!);
    }
  }
  
  // MANTENIDO: Métodos clave para gestionar el flujo de reserva
  
  Future<void> _startTreatmentSelection() async {
    String response = localizations.get('booking_welcome_select_treatment') ?? 
        "¡Perfecto! Me encantaría ayudarte a agendar una cita. ¿Qué tipo de tratamiento estás buscando?";
    
    response += "\n\nTenemos las siguientes categorías:";
    
    // Mostrar categorías y algunos tratamientos de ejemplo
    for (final category in _appointmentService.availableTreatmentCategories) {
      final treatments = _appointmentService.treatmentsByCategory[category];
      if (treatments != null && treatments.isNotEmpty) {
        response += "\n\n**$category**:";
        final exampleTreatments = treatments.take(3).map((t) => t['name']).join(', ');
        response += " $exampleTreatments${treatments.length > 3 ? ", entre otros." : "."}";
      }
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    
    // Sugerencias para tratamientos populares
    suggestedReplies = [
      "Botox",
      "Ácido Hialurónico",
      "Eliminación de ojeras",
      "Consulta General"
    ];
    
    notifyListeners();
  }

  Future<void> _startBookingFlow() async {
    // Obtener nombre del tratamiento para mostrarlo
    String treatment = currentAppointmentInfo?.treatmentId != null ? 
        _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]! : 
        (localizations.get('a_consultation') ?? "una consulta");
    
    // Mensaje conciso para reserva específica
    String response = (localizations.get('booking_specific_treatment') ?? 
        "📋 Agendaré tu cita para {treatment}")
        .replaceAll('{treatment}', "**$treatment**");

    if (currentAppointmentInfo?.clinicId == null) {
      response += "\n\n${localizations.get('which_clinic_short') ?? "¿En qué ubicación?"}";
      
      // Mostrar clínicas de forma concisa
      for (final clinic in _appointmentService.availableClinics.values) {
        response += "\n$clinic";
      }
      
      // Sugerencias de clínicas
      List<String> clinicSuggestions = [];
      for (final clinic in _appointmentService.availableClinics.values.take(3)) {
        clinicSuggestions.add(clinic);
      }
      suggestedReplies = clinicSuggestions;
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    notifyListeners();
  }
  
  // Mostrar días disponibles
  Future<void> _showAvailableDates() async {
    final clinicId = currentAppointmentInfo!.clinicId!;
    final clinicName = _appointmentService.availableClinics[clinicId]!;
    final availableDates = _appointmentService.getAvailableDates(clinicId);
    
    String response = (localizations.get('clinic_selected_choose_date') ?? 
        "¿Qué día te gustaría tu cita en {clinic}?")
        .replaceAll('{clinic}', clinicName);
    
    if (availableDates.isEmpty) {
      response += "\n\n${localizations.get('no_availability') ?? 
          "Lo siento, no hay fechas disponibles para esta clínica en las próximas semanas."}";
      messages.add(ChatMessage(text: response, isUser: false));
      isBookingFlow = false;
      return;
    }
    
    // Formatear fechas disponibles de forma concisa
    final dateFormat = DateFormat('EEEE d MMMM', 'es');
    response += "\n\nFechas disponibles:";
    
    List<String> dateSuggestions = [];
    for (final date in availableDates.take(5)) {
      final dateStr = dateFormat.format(date);
      response += "\n• $dateStr";
      dateSuggestions.add(dateStr);
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    suggestedReplies = dateSuggestions.take(3).toList();
  }
  
  // Mostrar horarios disponibles
  Future<void> _showAvailableTimeSlots(DateTime date) async {
    final clinicId = currentAppointmentInfo!.clinicId!;
    final availableSlots = _appointmentService.getAvailableSlotsForDate(date, clinicId);
    
    if (availableSlots.isEmpty) {
      final response = localizations.get('no_time_slots') ?? 
          "Lo siento, no hay horarios disponibles para el día seleccionado.";
      messages.add(ChatMessage(text: response, isUser: false));
      _currentDateSelection = null;
      await _showAvailableDates();
      return;
    }
    
    final dayName = DateFormat('EEEE d MMMM', 'es').format(date);
    String response = (localizations.get('date_selected_choose_time') ?? 
        "¿Qué horario prefieres para el {date}?")
        .replaceAll('{date}', dayName);
    
    // Agrupar por mañana/tarde de manera concisa
    final morningSlots = availableSlots.where((s) => s.dateTime.hour < 13).toList();
    final afternoonSlots = availableSlots.where((s) => s.dateTime.hour >= 13).toList();
    
    List<String> timeSuggestions = [];
    
    if (morningSlots.isNotEmpty) {
      response += "\n\n**Mañana:**";
      for (final slot in morningSlots) {
        final timeStr = DateFormat('HH:mm').format(slot.dateTime);
        response += "\n• $timeStr";
        timeSuggestions.add(timeStr);
      }
    }
    
    if (afternoonSlots.isNotEmpty) {
      response += "\n\n**Tarde:**";
      for (final slot in afternoonSlots) {
        final timeStr = DateFormat('HH:mm').format(slot.dateTime);
        response += "\n• $timeStr";
        timeSuggestions.add(timeStr);
      }
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    suggestedReplies = timeSuggestions.take(4).toList();
  }
  
  // Mostrar resumen de reserva
  Future<void> _showBookingSummary() async {
    final treatment = _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]!;
    final clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
    final dateTime = DateFormat('EEEE d MMMM, HH:mm', 'es').format(currentAppointmentInfo!.date!);
    
    final response = (localizations.get('appointment_summary') ?? 
        "📌 Resumen de cita:\n📅 {dateTime}\n💉 {treatment}\n📍 {clinic}\n\n¿Confirmas?")
        .replaceAll('{dateTime}', dateTime)
        .replaceAll('{treatment}', treatment)
        .replaceAll('{clinic}', clinic);
    
    messages.add(ChatMessage(text: response, isUser: false));
    
    suggestedReplies = [
      localizations.get('confirm') ?? "Confirmar", 
      localizations.get('change_date') ?? "Cambiar fecha", 
      localizations.get('cancel') ?? "Cancelar"
    ];
  }
  
  // Confirmar reserva final
  Future<void> _confirmBooking() async {
    final success = await _appointmentService.confirmAppointment(currentAppointmentInfo!);
    
    if (success) {
      final treatment = _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]!;
      final clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
      final dateTime = DateFormat('EEEE d MMMM, HH:mm', 'es').format(currentAppointmentInfo!.date!);
      
      final response = (localizations.get('booking_confirmed') ?? 
          "✅ **¡Tu cita ha sido confirmada!**\n\n" +
          "📅 **Fecha y hora:** {dateTime}\n" +
          "💉 **Tratamiento:** {treatment}\n" +
          "📍 **Clínica:** {clinic}")
          .replaceAll('{dateTime}', dateTime)
          .replaceAll('{treatment}', treatment)
          .replaceAll('{clinic}', clinic);
      
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Finalizar flujo de reserva
      isBookingFlow = false;
      currentAppointmentInfo = null;
      _currentDateSelection = null;
      _currentTimeSelection = null;
      
      suggestedReplies = [
        localizations.get('view_my_appointments') ?? "Ver mis citas",
        localizations.get('before_treatment_info') ?? "Instrucciones previas",
        localizations.get('thanks') ?? "Gracias"
      ];
    } else {
      final response = localizations.get('booking_error') ?? 
          "Lo siento, ha ocurrido un problema al confirmar tu cita.";
      messages.add(ChatMessage(text: response, isUser: false));
      _currentTimeSelection = null;
      await _showAvailableTimeSlots(_currentDateSelection!);
    }
  }
  
  // Cancelar reserva
  Future<void> _cancelBooking() async {
    final response = localizations.get('booking_cancelled') ?? 
        "He cancelado el proceso de reserva. ¿Hay algo más en lo que pueda ayudarte?";
    messages.add(ChatMessage(text: response, isUser: false));
    
    isBookingFlow = false;
    currentAppointmentInfo = null;
    _currentDateSelection = null;
    _currentTimeSelection = null;
    
    suggestedReplies = [
      localizations.get('suggest_treatments') ?? "Ver tratamientos",
      localizations.get('consultation_prices') ?? "Precios de consulta",
      localizations.get('schedule_appointment') ?? "Intentar otra cita"
    ];
  }
  
  void _updateSuggestedReplies(String userMessage, String botResponse) {
    // Simplemente llamar al método de generación de sugerencias basado en contexto
    _generateSuggestionsBasedOnContext(userMessage, botResponse);
    notifyListeners();
  }
  
  void resetChat() {
    messages.clear();
    isBookingFlow = false;
    currentAppointmentInfo = null;
    isTyping = false;
    sendWelcomeMessage();
  }
}