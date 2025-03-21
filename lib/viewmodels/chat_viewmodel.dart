import 'package:flutter/material.dart';
import '/services/openai_service.dart';
import '/services/medical_reference_service.dart';
import '/services/appointment_service.dart' as appointment_service;
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import '/i18n/app_localizations.dart';
import '/services/knowledge_base.dart';
import '/models/medical_references.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAIService _openAIService;
  final MedicalReferenceService _referenceService;
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
  
  // Lista de sugerencias de respuesta actualizadas durante la conversación
  List<String> suggestedReplies = [];
  
  ChatViewModel({
    required OpenAIService openAIService,
    required MedicalReferenceService referenceService,
    required appointment_service.AppointmentService appointmentService,
    required this.localizations,
  }) : _openAIService = openAIService,
      _referenceService = referenceService,
      _appointmentService = appointmentService,
      _knowledgeBase = KnowledgeBase() {
    _initKnowledgeBase();
    initializeDateFormatting('es');
  }

  // Inicializar la base de conocimientos de forma segura
  Future<void> _initKnowledgeBase() async {
    try {
      await _knowledgeBase.initialize();
      debugPrint('✅ Base de conocimientos inicializada correctamente');
    } catch (error) {
      debugPrint('⚠️ Error inicializando base de conocimientos: $error');
    }
  }
    
  // Enviar un mensaje de bienvenida al iniciar la conversación
  void sendWelcomeMessage() {
    final welcomeMessage = localizations.get('welcome_message');
    messages.add(ChatMessage(text: welcomeMessage, isUser: false));
    
    // Establecer sugerencias iniciales
    suggestedReplies = [
      localizations.get('what_treatments'),
      localizations.get('want_know_prices'),
      localizations.get('where_located'),
      localizations.get('need_appointment')
    ];
    
    notifyListeners();
  }
  
  // Método actualizado para procesar mensajes con contexto de conocimiento
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    debugPrint('📝 Procesando mensaje: "$message"');
    
    // Añadir mensaje del usuario a la conversación
    messages.add(ChatMessage(text: message, isUser: true));
    
    // Limpiar sugerencias cuando el usuario envía un mensaje
    suggestedReplies = [];
    
    // Mostrar indicador de escritura
    isTyping = true;
    notifyListeners();
    
    // Si estamos en un flujo de reserva, manejarlo de forma especial
    if (isBookingFlow) {
      await _processContinuedBooking(message);
      return;
    }
    
    try {
      // 1. Detectar si se quiere iniciar una reserva de cita
      if (_detectBookingIntent(message)) {
        await _handleAppointmentBooking(message);
        return;
      }
      
      // 2. Obtener contexto relevante de la base de conocimientos
      final relevantContext = await _knowledgeBase.getRelevantContext(message);
      final contextForPrompt = _knowledgeBase.formatContextForPrompt(relevantContext);
      
      // 3. Obtener referencias médicas relevantes
      final List<MedicalReference> medicalRefs = await _referenceService.getRelevantReferences(message);

      // Convertir MedicalReference a String para el prompt
      final List<String> medicalReferences = medicalRefs
          .map((ref) => ref.toFormattedString())
          .toList();
          
      // 4. Obtener precios relevantes desde la base de conocimientos
      List<Map<String, dynamic>> relevantPrices = [];
      if (relevantContext.containsKey('prices')) {
        relevantPrices = (relevantContext['prices'] as List).cast<Map<String, dynamic>>();
      }
      
      // 5. Detectar tipo de consulta específica
      final isPriceQuery = _isPriceRelated(message);
      final isAppointmentQuery = _isAppointmentRelated(message);
      
      String response;
      
      if (isPriceQuery && relevantPrices.isEmpty) {
        // Si es una consulta de precios pero no tenemos información exacta en el contexto
        // Usar OpenAI para generar una respuesta basada en categorías disponibles
        final priceCategories = await _knowledgeBase.getPriceCategories();
        final priceContext = '''
        CONSULTA SOBRE PRECIOS:
        El usuario está preguntando sobre precios pero no tenemos información específica.

        Categorías de precios disponibles:
        ${priceCategories.map((c) => '- $c').join('\n')}

        Responde de manera amable y profesional, sugiriendo que especifique más su consulta 
        o que podría visitar la clínica para un presupuesto personalizado.
        ''';
        
        response = await _openAIService.getCompletion(
          message,
          externalContext: priceContext,
        );
      } else if (isAppointmentQuery) {
        // Si es sobre citas, usar el método especializado
        response = await _handleAppointmentQuery(message);
      } else {
        // Para consultas generales, usar el método con contexto externo
        response = await _openAIService.getCompletion(
          message,
          medicalReferences: medicalReferences,
          priceInfo: relevantPrices,
          externalContext: contextForPrompt, // Pasar el contexto externo
        );
      }
      
      // Añadir respuesta del asistente
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Actualizar sugerencias según contexto
      _updateSuggestedReplies(message, response);
      
    } catch (e) {
      // Manejar errores
      debugPrint('❌ Error al procesar mensaje: $e');
      messages.add(ChatMessage(
        text: "${localizations.get('chat_error')}: ${e.toString()}",
        isUser: false
      ));
    } finally {
      // Ocultar indicador de escritura
      isTyping = false;
      notifyListeners();
    }
  }
  
  // Método para manejar consultas sobre citas sin iniciar reserva
  Future<String> _handleAppointmentQuery(String message) async {
    final clinicInfo = await _knowledgeBase.getClinicScheduleInfo();
    
    // Usar OpenAI para generar información sobre citas con instrucciones específicas
    final context = '''
    INFORMACIÓN SOBRE CITAS:
    $clinicInfo

    Si el usuario quiere reservar una cita, sugiérele que seleccione un tratamiento específico.
    ''';
    
    final response = await _openAIService.getCompletion(
      message,
      externalContext: context,
    );
    
    return response;
  }

  // Método para detectar si un mensaje contiene intenciones de reserva de citas 
  bool _detectBookingIntent(String message) {
    final bookingIntentions = [
      'agendar', 'reservar', 'cita', 'consulta', 'hora', 
      'turno', 'visitar', 'atención', 'atenderse', 'visita', 
      'quiero ir', 'me gustaría ir', 'puedo ir', 'tengo que ir',
      'necesito una cita', 'hacer una cita', 'sacar cita',
      'pedir hora', 'agendar hora', 'programar'
      'quiero agendar', 'quiero reservar', 'quisiera una cita', 
      'reservar una cita', 'agendar una cita', 'hacer una cita',
      'reservación', 'reservacion', 'agendar cita', 'reservar cita'
      'agendar', 'reservar', 'cita', 'consulta', 'hora', 
      'turno', 'visitar', 'atención', 'atenderse', 'visita', 
      'quiero ir', 'me gustaría ir', 'puedo ir', 'tengo que ir',
      'necesito una cita', 'hacer una cita', 'sacar cita',
      'pedir hora', 'agendar hora', 'programar'
    ];
    
    message = message.toLowerCase();
  
    // Verificar palabras clave individuales
    for (var intention in bookingIntentions) {
      if (message.contains(intention)) {
        // Si contiene alguna palabra relacionada con reservas, hacer una verificación adicional
        // para evitar falsos positivos en consultas generales
        
        // Comprobar patrones más específicos que indican intención de reserva
        if (message.contains('quiero') || 
            message.contains('puedo') || 
            message.contains('me gustaría') ||
            message.contains('necesito') ||
            message.contains('sacar') ||
            message.contains('hacer') ||
            message.contains('pedir') ||
            message.contains('programar') ||
            message.contains('agendar')) {
          return true;
        }
        
        // O si es una petición directa como "cita para mañana"
        if (message.contains('para mañana') || 
            message.contains('para el') || 
            message.contains('semana') ||
            message.contains('día') ||
            message.contains('cuando')) {
          return true;
        }
      }
    }
  
    // Patrones específicos de petición de cita
    final specificPatterns = [
      'quiero una cita',
      'necesito una cita',
      'me gustaría agendar',
      'me gustaría reservar',
      'puedo agendar',
      'quiero reservar',
      'para agendar',
      'para reservar',
      'quisiera una cita',
      'deseo una cita',
      'quiero atenderme',
    ];
  
    return specificPatterns.any((pattern) => message.contains(pattern));
  }

  // Actualizar el método _handleAppointmentBooking para iniciar el flujo correctamente
  Future<void> _handleAppointmentBooking(String message) async {
    debugPrint('🗓️ Iniciando flujo de reserva de cita');
    
    // Crear info de cita si no existe
    currentAppointmentInfo ??= appointment_service.AppointmentInfo();
    isBookingFlow = true;
    
    // Intentar detectar tratamiento mencionado
    final treatments = _appointmentService.availableTreatments;
    for (var entry in treatments.entries) {
      if (message.toLowerCase().contains(entry.value.toLowerCase())) {
        currentAppointmentInfo?.treatmentId = entry.key;
        debugPrint('✅ Tratamiento detectado: ${entry.value}');
        break;
      }
    }
    
    // Si no se detectó un tratamiento específico, preguntar qué tratamiento desea
    if (currentAppointmentInfo?.treatmentId == null) {
      await _startTreatmentSelection();
    } else {
      // Si ya tenemos el tratamiento, iniciar flujo de reserva
      await _startBookingFlow();
    }
  }

  // Método para selección de tratamiento
  Future<void> _startTreatmentSelection() async {
    String response = localizations.get('booking_welcome_select_treatment') ?? 
        "¡Perfecto! Me encantaría ayudarte a agendar una cita. ¿Qué tipo de tratamiento estás buscando?";
    
    response += "\n\nTenemos las siguientes categorías:";
    
    // Obtener tratamientos agrupados por categoría
    final treatmentsByCategory = _appointmentService.treatmentsByCategory;
    
    // Mostrar categorías y algunos tratamientos de ejemplo
    for (final category in _appointmentService.availableTreatmentCategories) {
      final treatments = treatmentsByCategory[category];
      if (treatments != null && treatments.isNotEmpty) {
        response += "\n\n**$category**:";
        
        // Mostrar hasta 3 tratamientos de ejemplo por categoría
      final exampleTreatments = treatments.take(3).map((t) => t['name']).join(', ');
      response += " $exampleTreatments${treatments.length > 3 ? ", entre otros." : "."}";
      }
    }
    
    response += "\n\nPor favor, indica qué tratamiento te interesa para continuar con la reserva.";
    
    // Añadir mensaje del asistente
    messages.add(ChatMessage(text: response, isUser: false));
    
    // Sugerencias para tratamientos populares
    suggestedReplies = [
      "Botox",
      "Ácido Hialurónico",
      "Eliminación de ojeras",
      "Consulta General"
    ];
    
    isTyping = false;
    notifyListeners();
  }

  // Iniciar el flujo de reserva de cita
  Future<void> _startBookingFlow() async {
    // Obtener nombre del tratamiento para mostrarlo
    String treatment = currentAppointmentInfo?.treatmentId != null ? 
        _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]! : 
        (localizations.get('a_consultation') ?? "una consulta");
    
    // Construir mensaje de respuesta según el estado actual
    String response = (localizations.get('booking_understand_treatment') ?? 
        "Entiendo que estás interesado en {treatment}. Vamos a agendar tu cita.")
        .replaceAll('{treatment}', "**$treatment**");

    // Si no hay clínica seleccionada, pedir que elija una
    if (currentAppointmentInfo?.clinicId == null) {
      response += "\n\n" + (localizations.get('which_clinic_with_locations') ?? 
          "¿En qué clínica te gustaría atenderte?") + "\n";
          
      _appointmentService.availableClinics.values.forEach((clinic) {
        response += "- $clinic\n";
      });
      
      // Sugerencias específicas para selección de clínica
      List<String> clinicSuggestions = [];
      _appointmentService.availableClinics.values.take(3).forEach((clinic) {
        clinicSuggestions.add((localizations.get('want_to_go_to') ?? 
            "Quiero ir a {clinic}").replaceAll('{clinic}', clinic));
      });
      suggestedReplies = clinicSuggestions;
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    isTyping = false;
    notifyListeners();
  }
  
  // Procesar respuestas durante el flujo de reserva - VERSIÓN AUTOMATIZADA
  Future<void> _processContinuedBooking(String text) async {
    text = text.toLowerCase();
    
    // Si todavía no hay tratamiento seleccionado
    if (currentAppointmentInfo?.treatmentId == null) {
      // Intentar identificar el tratamiento mencionado
      bool treatmentFound = false;
      final treatments = _appointmentService.availableTreatments;
      
      for (var entry in treatments.entries) {
        if (text.contains(entry.value.toLowerCase())) {
          currentAppointmentInfo?.treatmentId = entry.key;
          treatmentFound = true;
          debugPrint('✅ Tratamiento seleccionado: ${entry.value}');
          break;
        }
      }
      
      if (!treatmentFound) {
        // Si no encontramos un tratamiento coincidente, asignar consulta general
        currentAppointmentInfo?.treatmentId = 'general_consultation';
        debugPrint('ℹ️ No se encontró tratamiento específico, asignando consulta general');
      }
      
      // Una vez seleccionado el tratamiento, continuar con la selección de clínica
      await _startBookingFlow();
      return;
    }
    
    // Si no hay clínica seleccionada, procesarla
    if (currentAppointmentInfo?.clinicId == null) {
      // Intentar extraer la clínica seleccionada
      for (var entry in _appointmentService.availableClinics.entries) {
        if (text.contains(entry.key) || 
            text.contains(entry.value.toLowerCase())) {
          currentAppointmentInfo?.clinicId = entry.key;
          break;
        }
      }
      
      // Si no se detectó la clínica, asignar una por defecto
      if (currentAppointmentInfo?.clinicId == null) {
        currentAppointmentInfo?.clinicId = _appointmentService.availableClinics.keys.first;
      }
      
      // Mostrar fechas disponibles
      await _showAvailableDates();
    }
    // Procesamiento de selección de fecha/hora
    else if (currentAppointmentInfo?.date == null) {
      // Si aún no ha seleccionado un día específico
      if (_currentDateSelection == null) {
        await _processDateSelection(text);
      }
      // Si ya seleccionó día pero no hora
      else if (_currentTimeSelection == null) {
        await _processTimeSelection(text);
      }
      // Si ya seleccionó hora (confirmación)
      else {
        await _processConfirmation(text);
      }
    }
    // Proceso post-confirmación
    else {
      if (text.contains('ver mis citas') || text.contains('mis citas')) {
        // Navegar a la pantalla de citas - esto requiere un callback desde la UI
        messages.add(ChatMessage(
          text: "Puedes ver todas tus citas en la sección 'Mis Citas' de la app. ¿Necesitas algo más?",
          isUser: false
        ));
        
        // Finalizar flujo de reserva
        isBookingFlow = false;
        suggestedReplies = [
          "Agendar otra cita", 
          "Ver tratamientos",
          "No, gracias"
        ];
      } else {
        // Otra pregunta post-reserva - responder normalmente
        Map<String, dynamic> contextInfo = await _knowledgeBase.getRelevantContext(text);
        final contextForPrompt = _knowledgeBase.formatContextForPrompt(contextInfo);
        String response = await _openAIService.getCompletion(text, externalContext: contextForPrompt);
        messages.add(ChatMessage(text: response, isUser: false));
        
        suggestedReplies = [
          "Ver mis citas",
          "Agendar otra cita",
          "Gracias"
        ];
      }
    }
    
    isTyping = false;
    notifyListeners();
  }
  
  // Mostrar días disponibles para la clínica seleccionada
  Future<void> _showAvailableDates() async {
    final clinicId = currentAppointmentInfo!.clinicId!;
    final clinicName = _appointmentService.availableClinics[clinicId]!;
    final availableDates = _appointmentService.getAvailableDates(clinicId);
    
    // Mensaje de confirmación de clínica y solicitud de fecha
    String response = (localizations.get('clinic_selected_choose_date') ?? 
        "Has seleccionado **{clinic}**. ¿Qué día te gustaría reservar tu cita?")
        .replaceAll('{clinic}', clinicName);
    
    if (availableDates.isEmpty) {
      response += "\n\n" + (localizations.get('no_availability') ?? 
          "Lo siento, no hay fechas disponibles para esta clínica en las próximas semanas. Te recomendamos contactar directamente por teléfono.");
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Reiniciar flujo
      isBookingFlow = false;
      return;
    }
    
    // Formatear fechas disponibles
    final dateFormat = DateFormat('EEEE d MMMM', 'es');
    response += "\n\nFechas disponibles:";
    
    List<String> dateSuggestions = [];
    for (int i = 0; i < availableDates.length; i++) {
      final date = availableDates[i];
      final dateStr = dateFormat.format(date);
      response += "\n• $dateStr";
      dateSuggestions.add(dateStr);
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    suggestedReplies = dateSuggestions.take(3).toList(); // Mostrar máximo 3 sugerencias
  }
  
  // Procesar selección de fecha
  Future<void> _processDateSelection(String text) async {
    final clinicId = currentAppointmentInfo!.clinicId!;
    final availableDates = _appointmentService.getAvailableDates(clinicId);
    
    // Intentar identificar la fecha mencionada
    final dateFormat = DateFormat('EEEE d MMMM', 'es');
    DateTime? selectedDate;
    
    // Verificar si mencionó alguna de las fechas sugeridas
    for (final date in availableDates) {
      final dateStr = dateFormat.format(date).toLowerCase();
      if (text.contains(dateStr)) {
        selectedDate = date;
        break;
      }
      
      // También comprobar formas parciales (solo día de la semana o solo número)
      final dayOfWeek = DateFormat('EEEE', 'es').format(date).toLowerCase();
      final dayNumber = date.day.toString();
      
      if ((text.contains(dayOfWeek) && text.contains(dayNumber)) || 
          text.contains('día $dayNumber')) {
        selectedDate = date;
        break;
      }
    }
    
    // Si no se identificó la fecha, tomar la primera disponible
    selectedDate ??= availableDates.first;
    
    _currentDateSelection = selectedDate;
    
    // Mostrar horarios disponibles para la fecha seleccionada
    await _showAvailableTimeSlots(selectedDate);
  }
  
  // Mostrar horarios disponibles para una fecha
  Future<void> _showAvailableTimeSlots(DateTime date) async {
    final clinicId = currentAppointmentInfo!.clinicId!;
    final availableSlots = _appointmentService.getAvailableSlotsForDate(date, clinicId);
    
    if (availableSlots.isEmpty) {
      final response = localizations.get('no_time_slots') ?? 
          "Lo siento, no hay horarios disponibles para el día seleccionado. Por favor, elige otra fecha.";
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Reiniciar selección de fecha
      _currentDateSelection = null;
      await _showAvailableDates();
      return;
    }
    
    final dayName = DateFormat('EEEE d MMMM', 'es').format(date);
    String response = (localizations.get('date_selected_choose_time') ?? 
        "Has seleccionado el **{date}**. Estos son los horarios disponibles:")
        .replaceAll('{date}', dayName);
    
    // Agrupar por mañana/tarde
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
    
    response += "\n\n" + (localizations.get('choose_time_slot') ?? "Por favor, elige un horario disponible.");
    
    messages.add(ChatMessage(text: response, isUser: false));
    suggestedReplies = timeSuggestions.take(4).toList(); // Mostrar solo 4 opciones para no saturar la UI
  }
  
  // Procesar selección de hora
  Future<void> _processTimeSelection(String text) async {
    if (_currentDateSelection == null) {
      debugPrint('❌ Error: no hay fecha seleccionada');
      return;
    }
    
    final clinicId = currentAppointmentInfo!.clinicId!;
    final availableSlots = _appointmentService.getAvailableSlotsForDate(_currentDateSelection!, clinicId);
    
    // Intentar identificar la hora mencionada
    for (final slot in availableSlots) {
      final timeStr = DateFormat('HH:mm').format(slot.dateTime);
      if (text.contains(timeStr)) {
        _currentTimeSelection = slot.dateTime;
        break;
      }
      
      // También comprobar formas comunes de mencionar horas
      final hour = slot.dateTime.hour;
      if (text.contains('$hour:00') || 
          text.contains('a las $hour') || 
          text.contains('las $hour') ||
          text.contains('$hour h')) {
        _currentTimeSelection = slot.dateTime;
        break;
      }
    }
    
    // Si no se identificó la hora, usar la primera disponible
    if (_currentTimeSelection == null && availableSlots.isNotEmpty) {
      _currentTimeSelection = availableSlots.first.dateTime;
    }
    
    if (_currentTimeSelection == null) {
      final response = localizations.get('time_not_recognized') ?? 
          "Lo siento, no he podido identificar el horario. Por favor, elige uno de los horarios disponibles.";
      messages.add(ChatMessage(text: response, isUser: false));
      await _showAvailableTimeSlots(_currentDateSelection!);
      return;
    }
    
    // Establecer la fecha completa en la cita
    currentAppointmentInfo?.date = _currentTimeSelection;
    
    // Mostrar resumen y pedir confirmación
    final dateTimeStr = DateFormat('EEEE d MMMM, HH:mm', 'es').format(_currentTimeSelection!);
    final treatment = _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]!;
    final clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
    
    final response = (localizations.get('appointment_summary') ?? 
        "¡Excelente! Vamos a agendar tu cita con estos datos:\n\n" +
        "📅 **Fecha y hora:** {dateTime}\n" +
        "💉 **Tratamiento:** {treatment}\n" +
        "📍 **Clínica:** {clinic}\n\n" +
        "¿Confirmas esta reserva?")
        .replaceAll('{dateTime}', dateTimeStr)
        .replaceAll('{treatment}', treatment)
        .replaceAll('{clinic}', clinic);
    
    messages.add(ChatMessage(text: response, isUser: false));
    suggestedReplies = [
      localizations.get('confirm') ?? "Confirmar", 
      localizations.get('change_date') ?? "Cambiar fecha", 
      localizations.get('cancel') ?? "Cancelar"
    ];
  }
  
  // Procesar confirmación final de la cita
  Future<void> _processConfirmation(String text) async {
    final confirmText = text.toLowerCase();
    
    // Si el usuario confirma la cita
    if (confirmText.contains('confirm') || 
        confirmText.contains('sí') || 
        confirmText.contains('si') ||
        confirmText.contains('confirmo') ||
        confirmText.contains('acepto') ||
        confirmText.contains('ok')) {
      
      // Confirmar la cita con el servicio
      final success = await _appointmentService.confirmAppointment(currentAppointmentInfo!);
      
      if (success) {
        // Formatear los detalles para el mensaje de confirmación
        final treatment = _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]!;
        final clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
        final dateTime = DateFormat('EEEE d MMMM, HH:mm', 'es').format(currentAppointmentInfo!.date!);
        
        // Mensaje de confirmación exitosa
        final response = (localizations.get('booking_confirmed') ?? 
            "✅ **¡Tu cita ha sido confirmada!**\n\n" +
            "📅 **Fecha y hora:** {dateTime}\n" +
            "💉 **Tratamiento:** {treatment}\n" +
            "📍 **Clínica:** {clinic}\n\n" +
            "Tu cita ha sido registrada en el sistema y la podrás encontrar en la sección 'Mis Citas' de la app.\n\n" +
            "¿Puedo ayudarte con algo más?")
            .replaceAll('{dateTime}', dateTime)
            .replaceAll('{treatment}', treatment)
            .replaceAll('{clinic}', clinic);
        
        messages.add(ChatMessage(text: response, isUser: false));
        
        // Sugerencias post-reserva
        suggestedReplies = [
          localizations.get('view_my_appointments') ?? "Ver mis citas",
          localizations.get('before_treatment_info') ?? "Instrucciones previas",
          localizations.get('thanks') ?? "Gracias"
        ];
        
        // Finalizar flujo de reserva
        isBookingFlow = false;
        currentAppointmentInfo = null;
        _currentDateSelection = null;
        _currentTimeSelection = null;
      } else {
        // Mensaje de error
        final response = localizations.get('booking_error') ?? 
            "Lo siento, ha ocurrido un problema al confirmar tu cita. " +
            "Por favor, intenta seleccionar otro horario o contacta directamente con la clínica.";
        messages.add(ChatMessage(text: response, isUser: false));
        
        // Reiniciar selección de hora
        _currentTimeSelection = null;
        await _showAvailableTimeSlots(_currentDateSelection!);
      }
    } 
    // Si el usuario quiere cambiar la fecha
    else if (confirmText.contains('cambiar fecha') || 
             confirmText.contains('otra fecha') || 
             confirmText.contains('otro día')) {
      
      // Reiniciar selecciones
      _currentDateSelection = null;
      _currentTimeSelection = null;
      currentAppointmentInfo?.date = null;
      
      // Mostrar fechas disponibles nuevamente
      await _showAvailableDates();
    }
    // Si el usuario quiere cancelar
    else if (confirmText.contains('cancel') || 
             confirmText.contains('no quiero')) {
      
      final response = localizations.get('booking_cancelled') ?? 
          "He cancelado el proceso de reserva. ¿Hay algo más en lo que pueda ayudarte?";
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Reiniciar todo el flujo
      isBookingFlow = false;
      currentAppointmentInfo = null;
      _currentDateSelection = null;
      _currentTimeSelection = null;
      
      // Sugerencias generales
      suggestedReplies = [
        localizations.get('suggest_treatments') ?? "Ver tratamientos",
        localizations.get('suggest_prices') ?? "Consultar precios",
        localizations.get('suggest_booking') ?? "Intentar otra cita"
      ];
    }
    // Si la respuesta no es clara, pedir confirmación de nuevo
    else {
      final response = localizations.get('please_confirm') ?? 
          "Por favor, confirma si quieres reservar esta cita o si prefieres cambiar la fecha u hora.";
      messages.add(ChatMessage(text: response, isUser: false));
      
      suggestedReplies = [
        localizations.get('confirm') ?? "Confirmar", 
        localizations.get('change_date') ?? "Cambiar fecha", 
        localizations.get('cancel') ?? "Cancelar"
      ];
    }
  }
  
  // Actualizar sugerencias de respuesta según el contexto
  void _updateSuggestedReplies(String userMessage, String botResponse) {
    userMessage = userMessage.toLowerCase();
    botResponse = botResponse.toLowerCase();
    
    // Generar sugerencias contextuales basadas en la conversación actual
    if (botResponse.contains("blanqueamiento") || userMessage.contains("blanqueamiento")) {
      suggestedReplies = [
        localizations.get('whitening_cost'),
        localizations.get('is_it_painful'),
        localizations.get('how_long_does_it_last')
      ];
    } else if (botResponse.contains("botox") || userMessage.contains("botox")) {
      suggestedReplies = [
        localizations.get('which_areas'),
        localizations.get('effect_duration'),
        localizations.get('what_is_price')
      ];
    } else if (botResponse.contains("precio") || userMessage.contains("precio") || 
              botResponse.contains("costo") || userMessage.contains("costo")) {
      suggestedReplies = [
        localizations.get('have_promotions'),
        localizations.get('accept_cards'),
        localizations.get('schedule_appointment')
      ];
    } else if (botResponse.contains("horario") || userMessage.contains("horario") ||
              botResponse.contains("atención") || userMessage.contains("atención")) {
      suggestedReplies = [
        localizations.get('open_saturday'),
        localizations.get('need_appointment'),
        localizations.get('see_locations')
      ];
    } else {
      // Sugerencias generales si no hay contexto específico
      suggestedReplies = [
        localizations.get('see_available_treatments'),
        localizations.get('consultation_prices'),
        localizations.get('schedule_appointment'),
      ];
    }
    
    notifyListeners();
  }
  
  // Reiniciar la conversación
  void resetChat() {
    messages.clear();
    isBookingFlow = false;
    currentAppointmentInfo = null;
    isTyping = false;
    
    // Enviar mensaje de bienvenida
    sendWelcomeMessage();
  }

  // Método para determinar si una consulta está relacionada con precios
  bool _isPriceRelated(String message) {
    final priceKeywords = [
      'precio', 'precios', 'costo', 'costos', 'tarifa', 'tarifas',
      'costar', 'vale', 'cuanto', 'cuánto', 'valorar'
    ];
    
    message = message.toLowerCase();
    return priceKeywords.any((keyword) => message.contains(keyword));
  }
  
  // Método para determinar si una consulta está relacionada con citas
  bool _isAppointmentRelated(String message) {
    final appointmentKeywords = [
      'cita', 'citas', 'reservar', 'reserva', 'agendar', 'agenda',
      'disponibilidad', 'horario', 'cuándo', 'cuando', 'día', 'hora'
    ];
    
    message = message.toLowerCase();
    return appointmentKeywords.any((keyword) => message.contains(keyword));
  }
}