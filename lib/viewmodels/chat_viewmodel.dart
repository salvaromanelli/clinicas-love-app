import 'package:flutter/material.dart';
import '/services/openai_service.dart';
import '/services/medical_reference_service.dart';
import '/services/appointment_service.dart' as appointment_service;
import '/virtual_assistant_chat.dart' hide AppointmentInfo;

class ChatViewModel extends ChangeNotifier {
  final OpenAIService _openAIService;
  final MedicalReferenceService _referenceService;
  final appointment_service.AppointmentService _appointmentService;
  
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
  }) : _openAIService = openAIService,
       _referenceService = referenceService,
       _appointmentService = appointmentService;
  
  // Enviar un mensaje de bienvenida al iniciar la conversación
  void sendWelcomeMessage() {
    const welcomeMessage = "¡Hola! Soy el asistente virtual de Clínicas Love. "
        "Puedo ayudarte con información sobre nuestros tratamientos estéticos y dentales, "
        "resolver dudas sobre precios, horarios o ubicaciones, y asistirte para agendar una cita. "
        "¿En qué puedo ayudarte hoy?";
    
    messages.add(ChatMessage(text: welcomeMessage, isUser: false));
    
    // Establecer sugerencias iniciales
    suggestedReplies = [
      "¿Qué tratamientos ofrecen?",
      "Quiero saber los precios",
      "¿Dónde están ubicados?",
      "Necesito agendar una cita"
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
        text: "Lo siento, tuve un problema procesando tu solicitud. Por favor intenta nuevamente.",
        isUser: false,
      ));
      
      // Sugerencias en caso de error
      suggestedReplies = [
        "Quiero hablar con un asesor",
        "Intentar de nuevo",
        "Ver tratamientos disponibles"
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
        "una consulta";
    
    String response = "Entiendo que quieres agendar una cita para $treatment. "
        "Para continuar con la reserva necesito algunos datos:\n\n";
    
    if (currentAppointmentInfo?.clinicId == null) {
      response += "¿En qué sede te gustaría atenderte? Tenemos clínicas en:\n";
      _appointmentService.availableClinics.values.forEach((clinic) {
        response += "- $clinic\n";
      });
      
      // Sugerencias específicas para selección de clínica
      List<String> clinicSuggestions = [];
      _appointmentService.availableClinics.values.take(3).forEach((clinic) {
        clinicSuggestions.add("Quiero ir a $clinic");
      });
      suggestedReplies = clinicSuggestions;
      
    } else if (currentAppointmentInfo?.date == null) {
      response += "¿Qué día y horario te gustaría agendar tu cita?";
      
      // Sugerencias para fechas
      suggestedReplies = [
        "Mañana por la tarde",
        "Este fin de semana",
        "El próximo lunes"
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
      String response = "Perfecto. ";
      if (currentAppointmentInfo?.clinicId != null) {
        String clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
        response += "Has seleccionado **$clinic**. ";
      } else {
        // Si no se detectó la clínica, asignar una por defecto para continuar
        currentAppointmentInfo?.clinicId = _appointmentService.availableClinics.keys.first;
        String clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
        response += "Entiendo que prefieres **$clinic**. ";
      }
      
      response += "¿Qué día y horario preferirías para tu cita?";
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Actualizar sugerencias para fechas
      suggestedReplies = [
        "Mañana por la tarde",
        "Este viernes a las 10am",
        "El próximo lunes"
      ];
      
    } else if (currentAppointmentInfo?.date == null) {
      // Guardar la respuesta como nota (en un caso real, convertirías esto a fecha)
      currentAppointmentInfo?.notes = "Fecha solicitada: $text";
      
      // Confirmar la reserva
      String treatment = _appointmentService.availableTreatments[currentAppointmentInfo!.treatmentId]!;
      String clinic = _appointmentService.availableClinics[currentAppointmentInfo!.clinicId]!;
      
      String response = "¡Gracias! He registrado tu solicitud para **$treatment** en **$clinic**.\n\n"
          "Un asesor se pondrá en contacto contigo pronto para confirmar la disponibilidad "
          "en el horario solicitado:\n\n"
          "📅 **$text**\n\n"
          "¿Deseas agregar algún comentario adicional o tienes alguna otra pregunta?";
      
      messages.add(ChatMessage(text: response, isUser: false));
      
      // Actualizar sugerencias para después de la reserva
      suggestedReplies = [
        "¿Necesito llevar algo?",
        "¿Cuánto dura la consulta?",
        "Ver más tratamientos"
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
        "¿Cuánto cuesta el blanqueamiento?",
        "¿Es doloroso?",
        "¿Cuánto tiempo dura?"
      ];
    } else if (botResponse.contains("botox") || userMessage.contains("botox")) {
      suggestedReplies = [
        "¿Qué zonas se pueden tratar?",
        "¿Cuánto tiempo dura el efecto?",
        "¿Cuál es el precio?"
      ];
    } else if (botResponse.contains("precio") || userMessage.contains("precio") || 
               botResponse.contains("costo") || userMessage.contains("costo")) {
      suggestedReplies = [
        "¿Tienen promociones?",
        "¿Aceptan tarjetas?",
        "Quiero agendar una cita"
      ];
    } else if (botResponse.contains("horario") || userMessage.contains("horario") ||
               botResponse.contains("atención") || userMessage.contains("atención")) {
      suggestedReplies = [
        "¿Atienden sábados?",
        "¿Necesito cita previa?",
        "Ver ubicaciones"
      ];
    } else {
      // Sugerencias generales si no hay contexto específico
      suggestedReplies = [
        "Ver tratamientos disponibles",
        "Precios de consultas",
        "Agendar una cita",
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
