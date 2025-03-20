import 'package:flutter/material.dart';
import '/services/openai_service.dart';
import '/services/medical_reference_service.dart';
import '/services/appointment_service.dart' as appointment_service;
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import '/i18n/app_localizations.dart';
import '/services/prices_service.dart';

class ChatViewModel extends ChangeNotifier {
  final OpenAIService _openAIService;
  final MedicalReferenceService _referenceService;
  final appointment_service.AppointmentService _appointmentService;
  final PriceService _priceService;
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
    required PriceService priceService,
    required this.localizations,
  }) : _openAIService = openAIService,
       _referenceService = referenceService,
       _appointmentService = appointmentService,
       _priceService = priceService;
    
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

    // Añadir este nuevo método para manejar consultas de precios
    Future<String> _getResponseAboutPrices(String userMessage) async {
      final keywords = [
        'precio', 'precios', 'costo', 'costos', 'tarifa', 'tarifas', 'costar', 'vale',
        'price', 'pricing', 'cost', 'fee', 'charge', 'value',
        'preu', 'preus', 'cost', 'tarifa', 'tarifes', 'val'
      ];
      
      // Extraer la posible consulta de tratamiento
      String treatmentQuery = userMessage.toLowerCase();
      
      // Eliminar palabras clave de precios para quedarse solo con el tratamiento
      for (var keyword in keywords) {
        if (treatmentQuery.contains(keyword)) {
          // Dividir y quedarse con la parte después de la palabra clave
          final parts = treatmentQuery.split(keyword);
          if (parts.length > 1) {
            treatmentQuery = parts[1].trim();
            break;
          }
        }
      }
      
      // Si la consulta es muy corta, usar todo el mensaje
      if (treatmentQuery.length < 3) {
        treatmentQuery = userMessage.toLowerCase();
      }
      
      try {
        // Buscar el tratamiento en la base de datos
        final priceInfo = await _priceService.findTreatmentPrice(treatmentQuery);
        
        if (priceInfo != null) {
          // Encontró información específica
          return "${localizations.get('price_for')} ${priceInfo['treatment']}: ${priceInfo['price']}\n\n${priceInfo['description']}";
        } else {
          // No encontró el tratamiento exacto, listar categorías disponibles
          final prices = await _priceService.getPrices();
          
          if (prices.isEmpty) {
            return localizations.get('price_data_unavailable');
          }
          
          String response = "${localizations.get('no_exact_price_found')}\n\n";
          response += "${localizations.get('available_categories')}:\n";
          
          prices.keys.forEach((category) {
            response += "- $category\n";
          });
          
          response += "\n${localizations.get('ask_specific_treatment')}";
          return response;
        }
      } catch (e) {
        // Error al obtener precios
        return "${localizations.get('price_error')}: ${e.toString()}";
      }
    }
    
    // Modificar el método sendMessage para interceptar preguntas de precios
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    
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
    
    // Detector de intención para precios (palabras clave)
    final priceKeywords = [
      'precio', 'precios', 'costo', 'costos', 'tarifa', 'tarifas', 'costar', 'vale', 'cuanto',
      'price', 'pricing', 'cost', 'fee', 'charge', 'value', 'how much',
      'preu', 'preus', 'cost', 'tarifa', 'tarifes', 'val', 'quant'
    ];
    
    // Comprobar si el mensaje contiene palabras clave de precios
    bool isPriceQuery = priceKeywords.any(
      (keyword) => message.toLowerCase().contains(keyword)
    );
    
    if (isPriceQuery) {
      try {
        // AQUÍ ESTÁ EL CAMBIO: Usar el nuevo método _handlePriceQuery en lugar de _getResponseAboutPrices
        final response = await _handlePriceQuery(message);
        messages.add(ChatMessage(text: response, isUser: false));
        
        // Actualizar sugerencias según el contexto de la respuesta
        _updateSuggestedReplies(message, response);
      } catch (e) {
        messages.add(ChatMessage(
          text: "${localizations.get('price_error')}: ${e.toString()}", 
          isUser: false
        ));
      } finally {
        isTyping = false;
        notifyListeners();
      }
      return;
    }
      
      // Resto del código existente para otras consultas...
      try {
        // Código existente para consultas generales
      } catch (e) {
        // Manejo de errores existente
      } finally {
        isTyping = false;
        notifyListeners();
      }
    }
    // Agregar este método en tu ChatViewModel

  Future<String> _handlePriceQuery(String query) async {
    try {
      // Extraer términos clave de la consulta
      final keyTerms = [
        'precio', 'cuesta', 'vale', 'coste', 'tarifa',
        'price', 'cost', 'fee',
        'tratamiento', 'treatment'
      ];
      
      // Limpiar la consulta para extraer el tratamiento
      String cleanedQuery = query.toLowerCase();
      for (final term in keyTerms) {
        cleanedQuery = cleanedQuery.replaceAll(term, ' ');
      }
      cleanedQuery = cleanedQuery
          .replaceAll('?', '')
          .replaceAll('¿', '')
          .replaceAll('del', ' ')
          .replaceAll('de', ' ')
          .replaceAll('la', ' ')
          .replaceAll('el', ' ')
          .replaceAll('los', ' ')
          .replaceAll('las', ' ')
          .trim();
      
      // Si la consulta limpia es muy corta, intentar usar la consulta original
      final searchQuery = cleanedQuery.length < 3 ? query.toLowerCase() : cleanedQuery;
      
      // FIX: Use _priceService instead of priceService
      final prices = await _priceService.searchPrices(searchQuery);
      
      if (prices.isEmpty) {
        // Si no hay coincidencias, obtener categorías disponibles
        // FIX: Use _priceService instead of priceService
        final categories = await _priceService.getCategories();
        return '''
  No encontré el precio exacto para "$searchQuery".
  Estas son las categorías disponibles:
  ${categories.map((c) => '• $c').join('\n')}

  ¿Puedes preguntarme por un tratamiento más específico o indicar la categoría que te interesa?
  ''';
      } else if (prices.length == 1) {
        // Si hay una sola coincidencia
        final price = prices.first;
        return '''
  📋 **${price['treatment']}**
  💰 **Precio:** ${price['price']}
  📝 ${price['description'] ?? 'Sin descripción adicional'}
  ''';
      } else if (prices.length <= 5) {
        // Si hay varias coincidencias (hasta 5)
        final pricesList = prices.map((p) => 
          '• **${p['treatment']}**: ${p['price']} - ${p['description'] ?? 'Sin descripción'}'
        ).join('\n');
        
        return '''
  Encontré estos tratamientos que podrían interesarte:

  $pricesList

  ¿Deseas información más detallada sobre alguno de ellos?
  ''';
      } else {
        // Si hay demasiadas coincidencias
        final categories = prices.map((p) => p['category'] as String).toSet().toList();
        return '''
  Encontré ${prices.length} tratamientos relacionados. Para ayudarte mejor, ¿podrías especificar más?

  Categorías disponibles:
  ${categories.map((c) => '• $c').join('\n')}
  ''';
      }
    } catch (e) {
      return "Lo siento, ocurrió un error al buscar información de precios. Por favor, intenta de nuevo o consulta directamente en la clínica.";
    }
  }

  // Asegúrate de llamar a este método desde tu método principal de procesamiento de mensajes
  }

