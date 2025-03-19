import 'package:flutter/material.dart';
import '/services/openai_service.dart';
import '/services/medical_reference_service.dart';
import '/services/appointment_service.dart' as appointment_service;
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import '/i18n/app_localizations.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAIService _openAIService;
  final MedicalReferenceService _referenceService;
  final appointment_service.AppointmentService _appointmentService;
  final AppLocalizations localizations;
  
  
  List<ChatMessage> messages = [];
  bool isTyping = false;
  appointment_service.AppointmentInfo? currentAppointmentInfo;
  bool isBookingFlow = false;
  
  // Lista de sugerencias de respuesta actualizadas durante la conversación
  List<String> suggestedReplies = [];
  
  ChatViewModel({
    required OpenAIService openAIService,
    required MedicalReferenceService referenceService,
    required appointment_service.AppointmentService appointmentService,
    required this.localizations,
  }) : _openAIService = openAIService,
       _referenceService = referenceService,
       _appointmentService = appointmentService;
  
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
  
  Future<void> sendMessage(String text) async {
    // Agregar mensaje del usuario
    messages.add(ChatMessage(text: text, isUser: true));
    isTyping = true;
    notifyListeners();
    
    try {
      // Verificar si estamos en proceso de reserva
      if (isBookingFlow) {
        await _processContinuedBooking(text);
        return;
      }
      
      // Comprobar si el mensaje tiene intención de reservar
      bool hasBookingIntent = _appointmentService.hasBookingIntent(text);
      
      if (hasBookingIntent) {
        // Extraer información inicial de la cita
        currentAppointmentInfo = _appointmentService.extractAppointmentInfo(text);
        
        if (currentAppointmentInfo!.hasBasicInfo) {
          // Si tenemos información básica, iniciar flujo de reserva
          isBookingFlow = true;
          await _startBookingFlow();
          return;
        }
      }
      
      // Proceso normal - obtener respuesta de OpenAI con referencias
      List<MedicalReference> relevantRefs = _referenceService.getRelevantReferences(text);
      
      // Limitar a 2 referencias para reducir tokens
      if (relevantRefs.length > 2) {
        relevantRefs = relevantRefs.sublist(0, 2);
      }
      
      List<String> refUrls = _referenceService.referencesToUrlList(relevantRefs);
      
      String response = await _openAIService.getCompletion(text, medicalReferences: refUrls);
      
      // Agregar respuesta del asistente
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Actualizar sugerencias basadas en la conversación
      _updateSuggestedReplies(text, response);
      
    } catch (e) {
      // Manejar error
      messages.add(ChatMessage(
        text: localizations.get('processing_error'),
        isUser: false,
      ));
      
      // Sugerencias en caso de error
      suggestedReplies = [
        localizations.get('talk_to_advisor'),
        localizations.get('try_again'),
        localizations.get('see_available_treatments')
      ];
    } finally {
      isTyping = false;
      notifyListeners();
    }
  }
  
  Future<void> _startBookingFlow() async {
    // Iniciar el flujo de reserva de cita
    String treatment = currentAppointmentInfo?.treatmentId != null ? 
        _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]! : 
        localizations.get('a_consultation');
    
    String response = localizations.get('booking_understand_treatment')
        .replaceAll('{treatment}', treatment);

    
    if (currentAppointmentInfo?.clinicId == null) {
      response += localizations.get('which_clinic_with_locations') + "\n";
      _appointmentService.availableClinics.values.forEach((clinic) {
        response += "- $clinic\n";
      });
      
      // Sugerencias específicas para selección de clínica
      List<String> clinicSuggestions = [];
      _appointmentService.availableClinics.values.take(3).forEach((clinic) {
        clinicSuggestions.add(localizations.get('want_to_go_to').replaceAll('{clinic}', clinic));
      });
      suggestedReplies = clinicSuggestions;
      
    } else if (currentAppointmentInfo?.date == null) {
      response += localizations.get('which_date_time_prefer');
      
      // Sugerencias para fechas
      suggestedReplies = [
        localizations.get('tomorrow_afternoon'),
        localizations.get('this_weekend'),
        localizations.get('next_monday')
      ];
    }
    
    messages.add(ChatMessage(text: response, isUser: false));
    isTyping = false;
    notifyListeners();
  }
  
  Future<void> _processContinuedBooking(String text) async {
    // Actualizar información de la cita basada en la respuesta del usuario
    if (currentAppointmentInfo?.clinicId == null) {
      // Intentar extraer la clínica seleccionada
      for (var entry in _appointmentService.availableClinics.entries) {
        if (text.toLowerCase().contains(entry.key) || 
            text.toLowerCase().contains(entry.value.toLowerCase())) {
          currentAppointmentInfo?.clinicId = entry.key;
          break;
        }
      }
      
      // Preguntar por la fecha
      String response = localizations.get('perfect') + " ";
      if (currentAppointmentInfo?.clinicId != null) {
        String clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
        response += localizations.get('you_selected').replaceAll('{clinic}', "**$clinic**") + " ";
      } else {
        // Si no se detectó la clínica, asignar una por defecto para continuar
        currentAppointmentInfo?.clinicId = _appointmentService.availableClinics.keys.first;
        String clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
        response += localizations.get('understand_you_prefer').replaceAll('{clinic}', "**$clinic**") + " ";
      }

      response += localizations.get('which_date_time_prefer');
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Actualizar sugerencias para fechas
      suggestedReplies = [
        localizations.get('tomorrow_afternoon'),
        localizations.get('this_friday_10am'),
        localizations.get('next_monday')
      ];
      
    } else if (currentAppointmentInfo?.date == null) {
      // Guardar la respuesta como nota (en un caso real, convertirías esto a fecha)
      currentAppointmentInfo?.notes = "Fecha solicitada: $text";
      
      // Confirmar la reserva
      String treatment = _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]!;
      String clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
      
      String response = localizations.get('thanks_registered_request')
          .replaceAll('{treatment}', "**$treatment**")
          .replaceAll('{clinic}', "**$clinic**") + "\n\n" +
          localizations.get('advisor_will_contact') + "\n\n" +
          "📅 **$text**\n\n" +
          localizations.get('want_add_comment');
      
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Actualizar sugerencias para después de la reserva
      suggestedReplies = [
        localizations.get('need_to_bring'),
        localizations.get('consultation_duration'),
        localizations.get('see_more_treatments')
      ];
      
      // Finalizar flujo de reserva
      isBookingFlow = false;
    }
    
    isTyping = false;
    notifyListeners();
  }
  
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
  
  void resetChat() {
    messages.clear();
    isBookingFlow = false;
    currentAppointmentInfo = null;
    isTyping = false;
    
    // Enviar mensaje de bienvenida
    sendWelcomeMessage();
  }
}
