import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/claude_assistant_service.dart';
import '/services/appointment_service.dart' as appointment_service;
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import '/i18n/app_localizations.dart';
import '/services/knowledge_base.dart';
import 'package:intl/date_symbol_data_local.dart';

class ConversationContext {
  String currentTopic = '';
  String lastMentionedTreatment = '';
  String lastMentionedPrice = '';
  String lastMentionedLocation = '';
  List<String> mentionedTreatments = [];
}


class ChatViewModel extends ChangeNotifier {
  final ClaudeAssistantService _aiService;
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
    
    // NUEVO: Detección mejorada de preguntas sobre ubicación
    final normalizedMsg = message.toLowerCase();
    final isLocationQuery = normalizedMsg.contains('dónde') || 
                          normalizedMsg.contains('donde') ||
                          normalizedMsg.contains('ubicacion') ||
                          normalizedMsg.contains('ubicación') ||
                          normalizedMsg.contains('direccion') ||
                          normalizedMsg.contains('dirección') ||
                          normalizedMsg.contains('clínica') ||
                          (normalizedMsg.contains('están') && normalizedMsg.contains('ubicad'));
    
    // NUEVO: Respuesta hardcoded para ubicaciones
    if (isLocationQuery) {
      debugPrint('📍 INTERCEPTANDO PREGUNTA SOBRE UBICACIÓN: "$message"');
      
      // Respuesta hardcoded con datos exactos de las clínicas
      final locationResponse = """Nuestras clínicas están ubicadas en:

📍 **Clínicas Love Barcelona**
   Dirección: Carrer Diputacio 327, 08009 Barcelona
   Teléfono: +34 938526533
   Horario: Lunes a Viernes: 9:00 - 20:00.

📍 **Clínicas Love Madrid**
   Dirección: Calle Edgar Neville, 16, 28020 Madrid
   Teléfono: +34 919993515
   Horario: Lunes a Viernes: 10:00 - 20:00.

¿Necesitas información sobre cómo llegar a alguna de nuestras clínicas?""";

      // Agregar directamente la respuesta hardcoded
      messages.add(ChatMessage(text: locationResponse, isUser: false));
      isTyping = false;
      notifyListeners();
      
      debugPrint('✅ RESPUESTA DE UBICACIÓN HARDCODED ENVIADA');
      return; // Terminar aquí
    }
      
      // Analizar el contexto actual de la conversación
      final ConversationContext conversationContext = _analyzeConversationContext();
      
      // Preparar estado actual para la IA con más contexto
      final currentState = {
        'language': localizations.locale.languageCode,
        'conversation_topic': conversationContext.currentTopic,
        'last_mentioned_treatment': conversationContext.lastMentionedTreatment,
        'last_mentioned_price': conversationContext.lastMentionedPrice,
        'last_mentioned_location': conversationContext.lastMentionedLocation,
      };

          // BYPASS CLAUDE PARA PREGUNTAS DE UBICACIÓN
      if (_isLocationQuestion(message)) {
        debugPrint('🚦 ACTIVANDO BYPASS para pregunta de ubicación: "$message"');
        // Obtener ubicaciones directamente de la base de conocimientos
        final locationInfo = await _getClinicLocationsDirectly();
        messages.add(ChatMessage(text: locationInfo, isUser: false));
        isTyping = false;
        notifyListeners();
        debugPrint('✅ Respuesta de BYPASS enviada correctamente');
        return; // Importante: terminar el método aquí
      }
      
      // Procesar con la IA incluyendo historia conversacional relevante
      final processedMessage = await _aiService.processMessage(
        message,
        // Enviar más mensajes de historial para mantener el contexto
        messages.sublist(messages.length > 10 ? messages.length - 10 : 0, messages.length - 1),
        currentState
      );

      messages.add(ChatMessage(
        text: processedMessage.text, 
        isUser: false,
        additionalContext: processedMessage.additionalContext
      ));

      // Actualizar sugerencias basadas en el nuevo contexto
      _generateSuggestionsBasedOnContext(message, processedMessage.text);
      
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
  
  Future<ProcessedMessage> processMessage(String message, String language) async {
    try {
      isTyping = true;
      notifyListeners();

      // Preparar el contexto actual para la IA
      final currentState = {
        'language': language,
      };

      // Procesar el mensaje con Claude
      final processedMessage = await _aiService.processMessage(
        message,
        messages,
        currentState,
      );
      
      return processedMessage;
    } catch (e) {
      debugPrint('❌ Error procesando el mensaje con Claude: $e');
      
      // Crear el mensaje de error de forma explícita
      final errorText = localizations.get('chat_error') ??
            "Lo siento, ha ocurrido un error al procesar tu mensaje.";
      
      // Usar Future.value con tipo explícito para evitar ambigüedades
      return Future<ProcessedMessage>.value(ProcessedMessage(
        text: errorText
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
      ];
    } else {
      // Sugerencias por defecto
      suggestedReplies = [
        localizations.get('see_available_treatments') ?? "Ver tratamientos",
        localizations.get('consultation_prices') ?? "Precios de consulta",
      ];
    }
  }

  // Añadir mensaje de usuario directamente
  void addUserMessage(String text) {
    messages.add(ChatMessage(text: text, isUser: true));
    notifyListeners();
  }

  // Añadir mensaje de asistente directamente
  void addBotMessage(String text) {
    isTyping = false;
    messages.add(ChatMessage(text: text, isUser: false));
    notifyListeners();
  }

  // Cambiar estado de escritura
  void setTyping(bool typing) {
    isTyping = typing;
    notifyListeners();
  }

  // Procesar con la IA directamente (sin añadir mensaje del usuario)
  void processMessageWithAI(String text) {
    isTyping = true;
    notifyListeners();
    
    _aiService.processMessage(text, messages, {}).then((dynamic processedResponse) {
      isTyping = false;
      // Convertir la respuesta dinámica a nuestro tipo específico
      final ProcessedMessage processedMessage;
      
      if (processedResponse is ProcessedMessage) {
        processedMessage = processedResponse;
      } else {
        // Manejar el caso cuando la respuesta no es del tipo esperado
        messages.add(ChatMessage(
          text: localizations.get('error_processing_message') ?? "Error procesando el mensaje",
          isUser: false
        ));
        notifyListeners();
        return;
      }
      
      // Ahora podemos usar processedMessage con seguridad
      messages.add(ChatMessage(
        text: processedMessage.text,
        isUser: false
      ));
      
      notifyListeners();
    }).catchError((error) {
      // Resto del código sin cambios
    });
  }
  // Obtener información específica de precios desde la knowledge base

Future<String> getSpecificPriceFromKnowledgeBase(String userMessage) async {
  try {
    // Obtener contexto con preferencia a precios
    final knowledgeContext = await _knowledgeBase.getRelevantContext(
      userMessage, 
      preferredType: 'prices'  // Indica que preferimos información de precios
    );
    
    debugPrint('🔍 Buscando información de precios en knowledge base');
    
    // Si hay precios disponibles
    if (knowledgeContext.containsKey('prices') && knowledgeContext['prices'] is List) {
      final prices = knowledgeContext['prices'] as List;
      debugPrint('💰 Encontrados ${prices.length} precios relevantes');
      
      // IMPORTANTE: Depurar la estructura real de los datos
      if (prices.isNotEmpty) {
        debugPrint('🔍 Estructura del primer precio: ${prices.first}');
      }
      
      // Identificar el tratamiento específico
      final lowerMessage = userMessage.toLowerCase();
      String priceInfo = "";
      
      // Buscar por botox
      if (lowerMessage.contains('botox') || lowerMessage.contains('toxina')) {
        for (var price in prices) {
          final String treatment = price['treatment']?.toString().toLowerCase() ?? '';
          if (treatment.contains('botox') || treatment.contains('toxina')) {
            priceInfo = "El tratamiento de Botox en Clínicas Love tiene un precio de ${price['price']}. ";
            if (price['description'] != null) {
              priceInfo += price['description'];
            } else {
              priceInfo += "El precio puede variar dependiendo de las zonas a tratar. Incluye valoración médica previa y seguimiento posterior.";
            }
            break;
          }
        }
      } 
      // Buscar por labios
      else if (lowerMessage.contains('labio') || lowerMessage.contains('relleno')) {
        for (var price in prices) {
          final String treatment = price['treatment']?.toString().toLowerCase() ?? '';
          if (treatment.contains('labio') || treatment.contains('relleno')) {
            priceInfo = "El aumento de labios con ácido hialurónico tiene un precio de ${price['price']}. ";
            if (price['description'] != null) {
              priceInfo += price['description'];
            } else {
              priceInfo += "Los resultados son inmediatos y duran entre 6-12 meses, dependiendo del metabolismo de cada paciente.";
            }
            break;
          }
        }
      }

      else if (_containsAny(lowerMessage, ['rino', 'nariz', 'rinomodelacion', 'rinomodelación'])) {
        debugPrint('🔍 Buscando precio de rinomodelación');
        bool found = false;
        
        // Imprimir todos los tratamientos para depuración
        for (var price in prices) {
          final String treatment = price['treatment']?.toString().toLowerCase() ?? '';
          debugPrint('👃 Comparando con: $treatment');
          
          // Usar una detección más amplia
          if (treatment.contains('rino') || 
              treatment.contains('nariz') || 
              treatment.contains('armoniz') || 
              treatment.contains('facial') && treatment.contains('sin cirug')) {
            
            found = true;
            debugPrint('✅ Coincidencia encontrada para rinomodelación: $treatment');
            
            priceInfo = "La rinomodelación sin cirugía en Clínicas Love tiene un precio desde ${price['price']}€. ";
            if (price['description'] != null) {
              priceInfo += price['description'];
            } else {
              priceInfo += "Es un tratamiento realizado con ácido hialurónico que permite corregir pequeñas imperfecciones nasales sin cirugía. El procedimiento es rápido, con resultados inmediatos y mínima recuperación.";
            }
            break;
          }
        }
        
        // Si no encontramos coincidencia específica pero era una pregunta de rinomodelación
        if (!found && prices.isNotEmpty) {
          debugPrint('⚠️ No se encontró coincidencia específica para rinomodelación');
          
          // Proporcionar una respuesta predefinida con precio aproximado
          priceInfo = "La rinomodelación sin cirugía en Clínicas Love tiene un precio aproximado de 350€ a 450€, dependiendo de la complejidad del caso y la cantidad de producto necesario. El tratamiento se realiza con ácido hialurónico y los resultados son inmediatos, duran entre 12-18 meses.";
        }
      }
      // Precios generales
      else {
        priceInfo = "En Clínicas Love contamos con los siguientes tratamientos y precios:\n\n";
        
        // Mostrar hasta 5 precios disponibles
        int count = 0;
        for (var price in prices) {
          if (count >= 5) break;
          
          // CLAVE: Usar 'treatment' en lugar de 'name'
          String treatmentName = price['treatment']?.toString() ?? "Tratamiento";
          String priceValue = price['price']?.toString() ?? "Consultar";
          
          priceInfo += "• $treatmentName: $priceValue\n";
          count++;
        }
        
        priceInfo += "\n¿Sobre qué tratamiento específico te gustaría conocer más detalles?";
      }
      
      // Si no se encontró ninguna coincidencia específica
      if (priceInfo.isEmpty && prices.isNotEmpty) {
        priceInfo = "En Clínicas Love contamos con los siguientes tratamientos y precios:\n\n";
        
        int count = 0;
        for (var price in prices) {
          if (count >= 5) break;
          
          // CLAVE: Usar 'treatment' en lugar de 'name'
          String treatmentName = price['treatment']?.toString() ?? "Tratamiento";
          String priceValue = price['price']?.toString() ?? "Consultar";
          
          priceInfo += "• $treatmentName: $priceValue\n";
          count++;
        }
      }
      
      return priceInfo;
    }
  } catch (e) {
    debugPrint('⚠️ Error al obtener precios: $e');
  }
  
  return "Lo siento, no encontré información específica sobre precios para tu consulta. ¿Te gustaría preguntar por un tratamiento específico como Botox, aumento de labios o rinomodelación?";
}

  // Obtener información específica de tratamientos
  Future<String> getTreatmentInfoFromKnowledgeBase(String userMessage) async {
    if (_knowledgeBase == null) return "";
    
    try {
      // Obtener contexto con preferencia a tratamientos
      final knowledgeContext = await _knowledgeBase.getRelevantContext(
        userMessage, 
        preferredType: 'treatments'  // Indica que preferimos información de tratamientos
      );
      
      debugPrint('🔍 Buscando información de tratamientos en knowledge base');
      
      // Si hay tratamientos disponibles
      if (knowledgeContext.containsKey('treatments') && knowledgeContext['treatments'] is List) {
        final treatments = knowledgeContext['treatments'] as List;
        debugPrint('💉 Encontrados ${treatments.length} tratamientos relevantes');
        
        // Para preguntas generales sobre tratamientos
        if (_containsAny(userMessage.toLowerCase(), ['qué tratamientos', 'que tratamientos', 'cuáles son', 'cuales son', 'ofrecen', 'disponibles'])) {
          // Lista todos los tratamientos disponibles
          String treatmentInfo = "En Clínicas Love ofrecemos estos tratamientos estéticos:\n\n";
          
          // Agrupar por categorías
          final Map<String, List<dynamic>> treatmentsByCategory = {};
          
          for (var treatment in treatments) {
            final category = treatment['category']?.toString() ?? 'General';
            treatmentsByCategory.putIfAbsent(category, () => []);
            treatmentsByCategory[category]!.add(treatment);
          }
          
          // Mostrar tratamientos por categoría
          treatmentsByCategory.forEach((category, categoryTreatments) {
            treatmentInfo += "**$category**:\n";
            
            for (var t in categoryTreatments.take(4)) {
              treatmentInfo += "• ${t['name']}";
              if (t['price'] != null) {
                treatmentInfo += " (${t['price']}€)";
              }
              treatmentInfo += "\n";
            }
            
            if (categoryTreatments.length > 4) {
              treatmentInfo += "• Y otros tratamientos más...\n";
            }
            
            treatmentInfo += "\n";
          });
          
          return treatmentInfo;
        }
        
        // Identificar el tratamiento específico - usar bucle for en lugar de firstWhere
        final lowerMessage = userMessage.toLowerCase();
        for (var treatment in treatments) {
          final treatmentName = treatment['name']?.toString() ?? '';
          
          if (_messageContainsTreatment(lowerMessage, treatmentName)) {
            String treatmentInfo = "**${treatment['name']}**: ";
            
            if (treatment['description'] != null) {
              treatmentInfo += treatment['description'];
            }
            
            // Añadir duración si está disponible
            if (treatment['duration'] != null) {
              treatmentInfo += "\n\nDuración aproximada: ${treatment['duration']} minutos.";
            }
            
            // Añadir precio si está disponible
            if (treatment['price'] != null) {
              treatmentInfo += " Precio: ${treatment['price']}€.";
            }
            
            return treatmentInfo;
          }
        }
        
        // Si llegamos aquí, no encontramos un tratamiento específico
        if (treatments.isNotEmpty) {
          // Mostrar los tratamientos disponibles
          String treatmentInfo = "No encontré información específica sobre ese tratamiento, pero en Clínicas Love ofrecemos estos tratamientos:\n\n";
          
          // Listar hasta 5 tratamientos
          int count = 0;
          for (var t in treatments) {
            if (count >= 5) break;
            treatmentInfo += "• **${t['name']}**";
            if (t['price'] != null) {
              treatmentInfo += " (${t['price']}€)";
            }
            treatmentInfo += "\n";
            count++;
          }
          
          treatmentInfo += "\n¿Te gustaría información más detallada sobre alguno de estos tratamientos?";
          return treatmentInfo;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al obtener información de tratamientos: $e');
    }
    
    // Respuesta de respaldo si todo falla
    return "En Clínicas Love ofrecemos una amplia variedad de tratamientos estéticos, incluyendo:\n\n"
        "• Tratamientos faciales: Botox, ácido hialurónico, rellenos, rinomodelación\n"
        "• Tratamientos corporales: Mesoterapia, tratamientos reductores\n"
        "• Medicina estética avanzada: Peelings químicos, láser\n\n"
        "Todos realizados por médicos especialistas. ¿Sobre qué tratamiento específico te gustaría más información?";
  }

  // Método auxiliar para verificar si un mensaje contiene el nombre de un tratamiento
  bool _messageContainsTreatment(String message, String treatmentName) {
    final treatmentLower = treatmentName.toLowerCase();
    
    // Palabras clave para tratamientos comunes
    final Map<String, List<String>> treatmentKeywords = {
      'botox': ['botox', 'toxina', 'botulínica', 'arrugas'],
      'labios': ['labio', 'labios', 'relleno labial', 'aumento de labios'],
      'rinomodelación': ['rino', 'rinomodelación', 'nariz', 'rinoplastia'],
      'mesoterapia': ['meso', 'mesoterapia', 'facial', 'vitaminas'],
      'peeling': ['peeling', 'químico', 'exfoliación'],
      'facial': ['facial', 'limpieza facial', 'tratamiento facial'],
    };
    
    // Verificar coincidencia directa
    if (message.contains(treatmentLower)) {
      return true;
    }
    
    // Verificar por palabras clave específicas
    for (final entry in treatmentKeywords.entries) {
      if (treatmentLower.contains(entry.key)) {
        for (final keyword in entry.value) {
          if (message.contains(keyword)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }

  // Método para analizar el contexto de la conversación actual
  ConversationContext _analyzeConversationContext() {
    final context = ConversationContext();
    
    // No analizar si no hay mensajes suficientes
    if (messages.length < 2) return context;
    
    // Analizar los últimos mensajes para detectar temas, tratamientos, etc.
    final recentMessages = messages.sublist(messages.length > 6 ? messages.length - 6 : 0);
    
    // Concatenar todo el texto reciente para análisis
    String recentText = recentMessages.map((m) => m.text.toLowerCase()).join(' ');
    
    // Detectar tema actual
    if (recentText.contains('precio') || recentText.contains('costo') || 
        recentText.contains('vale') || recentText.contains('cuesta')) {
      context.currentTopic = 'precios';
    } else if (recentText.contains('tratamiento') || recentText.contains('procedimiento')) {
      context.currentTopic = 'tratamientos';
    } else if (recentText.contains('ubicación') || recentText.contains('dirección') || 
              recentText.contains('donde') || recentText.contains('clínica')) {
      context.currentTopic = 'ubicaciones';
    }
    
    // Detectar tratamientos mencionados
    final treatmentsKeywords = {
      'botox': ['botox', 'toxina', 'botulínica', 'arrugas'],
      'ácido hialurónico': ['ácido', 'hialurónico', 'relleno'],
      'labios': ['labio', 'labios', 'aumento'],
      'rinomodelación': ['rino', 'nariz', 'rinomodelación'],
      'peeling': ['peeling', 'químico', 'exfoliación']
    };
    
    treatmentsKeywords.forEach((treatment, keywords) {
      for (final keyword in keywords) {
        if (recentText.contains(keyword)) {
          // Si es la primera vez que se menciona o es reciente
          if (!context.mentionedTreatments.contains(treatment) || 
              recentMessages.last.text.toLowerCase().contains(keyword)) {
            context.lastMentionedTreatment = treatment;
          }
          if (!context.mentionedTreatments.contains(treatment)) {
            context.mentionedTreatments.add(treatment);
          }
          break;
        }
      }
    });
    
    // Detectar ubicaciones mencionadas
    final locationsKeywords = ['barcelona', 'madrid', 'málaga', 'tenerife'];
    for (final location in locationsKeywords) {
      if (recentText.contains(location)) {
        context.lastMentionedLocation = location;
        break;
      }
    }
    
    debugPrint('📊 Análisis de contexto: ${context.currentTopic}, tratamiento: ${context.lastMentionedTreatment}');
    return context;
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

    bool _containsAny(String text, List<String> keywords) {
    final normalized = _normalizeText(text);
    
    for (final keyword in keywords) {
      if (normalized.contains(_normalizeText(keyword))) {
        return true;
      }
    }
    return false;
  }

  String _normalizeText(String text) {
    // Normalizar: quitar acentos, convertir a minúsculas, eliminar caracteres especiales
    return text.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
  }

  bool _isLocationQuestion(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('dónde') || 
          lowerText.contains('donde') || 
          lowerText.contains('ubicación') || 
          lowerText.contains('ubicacion') ||
          lowerText.contains('dirección') || 
          lowerText.contains('direccion') ||
          lowerText.contains('clinica') ||
          lowerText.contains('localización') ||
          lowerText.contains('lugar') ||
          lowerText.contains('sede') ||
          (lowerText.contains('esta') && lowerText.contains('ubicad'));
  }

  Future<String> _getClinicLocationsDirectly() async {
    try {
      debugPrint('🔍 ACCEDIENDO DIRECTAMENTE A LA LISTA DE CLÍNICAS');
      
      // Acceder DIRECTAMENTE a las clínicas - importante usar await aquí
      final List<Map<String, dynamic>> clinics = await _knowledgeBase.getAllClinics();
      
      // Depuración profunda para verificar qué estamos obteniendo
      debugPrint('📍 CLÍNICAS OBTENIDAS: ${clinics.length}');
      for (var i = 0; i < clinics.length; i++) {
        debugPrint('Clínica ${i+1}: ${clinics[i]['name']} - ${clinics[i]['address']}');
      }
      
      if (clinics.isEmpty) {
        return "Lo siento, no tengo información sobre nuestras ubicaciones en este momento.";
      }
      
      // Construir respuesta manualmente con las ubicaciones reales
      String locationInfo = "Nuestras clínicas están ubicadas en:\n\n";
      
      for (var clinic in clinics) {
        final name = clinic['name'] ?? 'Clínica Love';
        final address = clinic['address'] ?? 'Dirección no disponible';
        final phone = clinic['phone'] ?? 'Teléfono no disponible';
        final schedule = clinic['schedule'] ?? 'Horario no disponible';
        
        locationInfo += "📍 **$name**\n";
        locationInfo += "   Dirección: $address\n";
        locationInfo += "   Teléfono: $phone\n";
        locationInfo += "   Horario: $schedule\n\n";
      }
      
      locationInfo += "¿Necesitas información sobre cómo llegar a alguna de nuestras clínicas?";
      return locationInfo;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo ubicaciones: $e');
      // Si hay error, devolver información hardcoded como último recurso
      return "Nuestras clínicas están ubicadas en:\n\n" +
            "📍 **Clínicas Love Barcelona**\n" +
            "   Dirección: Carrer Diputacio 327, 08009 Barcelona\n" +
            "   Teléfono: +34 938526533\n" +
            "   Horario: Lunes a Viernes: 9:00 - 20:00.\n\n" +
            "📍 **Clínicas Love Madrid**\n" +
            "   Dirección: Calle Edgar Neville, 16. 28020 Madrid\n" +
            "   Teléfono: 34 919993515\n" +
            "   Horario: Lunes a Viernes: 10:00 - 20:00.\n\n" +
            "¿Necesitas información sobre cómo llegar a alguna de nuestras clínicas?";
    }
  }
}