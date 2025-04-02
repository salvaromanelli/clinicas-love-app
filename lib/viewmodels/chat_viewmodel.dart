import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/claude_assistant_service.dart';
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import '/i18n/app_localizations.dart';
import '/services/knowledge_base.dart';
import 'package:intl/date_symbol_data_local.dart';
import '/services/supabase.dart';

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
  bool isBookingFlow = false;
  
  // Variables auxiliares para el flujo de reserva
  DateTime? _currentDateSelection;
  DateTime? _currentTimeSelection;
  List<String> suggestedReplies = [];
  
  ChatViewModel({
    required ClaudeAssistantService aiService,
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
      
      // NUEVO: Detección de preguntas sobre ubicación
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
  void addBotMessage(String text, {String? additionalContext}) {
    messages.add(ChatMessage(
      text: text,
      isUser: false,
      additionalContext: additionalContext,
    ));
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
      // IMPORTANTE: Primero analizar el contexto de la conversación
      final conversationContext = _analyzeConversationContext();
      
      // Crear una consulta mejorada que incluya el contexto de la conversación
      String enhancedQuery = userMessage;
      
      // Si la consulta es genérica sobre precios y hay un tratamiento mencionado recientemente
      if (_containsAny(userMessage.toLowerCase(), ['precio', 'cuesta', 'cuánto', 'cuanto', 'valor', 'costo']) && 
          !_containsSpecificTreatment(userMessage) && 
          conversationContext.lastMentionedTreatment.isNotEmpty) {
        
        debugPrint('💬 Detectada pregunta de precio en contexto de: ${conversationContext.lastMentionedTreatment}');
        // Agregar el tratamiento del contexto a la consulta
        enhancedQuery = '${userMessage} ${conversationContext.lastMentionedTreatment}';
        debugPrint('🔄 Consulta mejorada: $enhancedQuery');
      }
      
      // Obtener el contexto relevante usando la consulta mejorada
      final knowledgeContext = await _knowledgeBase.getRelevantContext(
        enhancedQuery,  // Usar la consulta mejorada
        preferredType: 'prices'
      );
      
      if (knowledgeContext.containsKey('prices') && knowledgeContext['prices'] is List) {
        final List<Map<String, dynamic>> prices = List<Map<String, dynamic>>.from(knowledgeContext['prices']);
        
        debugPrint('💰 Encontrados ${prices.length} precios en la base de conocimiento');
        debugPrint('🔍 Buscando precios para: $enhancedQuery');
        
        final keywords = extractKeywords(enhancedQuery);
        debugPrint('🔍 Palabras clave extraídas: $keywords');
        
        // Parte 1: Buscar coincidencias exactas primero
        for (var price in prices) {
          final treatment = price['treatment'].toString().toLowerCase();
          
          if (enhancedQuery.toLowerCase().contains(treatment)) {
            debugPrint('✅ Coincidencia exacta encontrada para: $treatment');
            
            // IMPORTANTE: Manejar caso donde la descripción puede ser null
            final description = price['description'] ?? 
                "Tratamiento especializado realizado por nuestros médicos expertos.";
            
            return """
            **${price['treatment']}**

            $description

            **Precio:** ${price['price']}

            ¿Deseas agendar una cita para este tratamiento?
                      """;
          }
        }
        
        // Parte 2: Si no hay coincidencia exacta, encontrar el MÁS relevante
        Map<String, dynamic>? bestMatch;
        int maxScore = -1;
        
        for (var price in prices) {
          final treatment = price['treatment'].toString().toLowerCase();
          final description = price['description']?.toString().toLowerCase() ?? '';
          final category = price['category']?.toString().toLowerCase() ?? '';
          
          int score = 0;
          
          // Calcular puntuación basada en palabras clave encontradas
          for (var keyword in keywords) {
            if (treatment.contains(keyword)) score += 3; // Mayor peso a coincidencias en nombre
            if (description.contains(keyword)) score += 1;
            if (category.contains(keyword)) score += 2;
          }
          
          // Si es la mejor coincidencia hasta ahora
          if (score > maxScore) {
            maxScore = score;
            bestMatch = price;
          }
        }
        
        // Si encontramos al menos una coincidencia relevante
        if (bestMatch != null && maxScore > 0) {
          debugPrint('✅ Mejor coincidencia encontrada: ${bestMatch['treatment']} con puntuación $maxScore');
          
          // IMPORTANTE: Manejar caso donde la descripción puede ser null
          final description = bestMatch['description'] ?? 
              "Tratamiento especializado realizado por nuestros médicos expertos.";
          
          return """
  **${bestMatch['treatment']}**

  $description

  **Precio:** ${bestMatch['price']}

  ¿Deseas agendar una cita para este tratamiento?
          """;
        }
        
        // IMPORTANTE: Solo mostrar múltiples resultados si la consulta parece explícitamente buscar múltiples tratamientos
        final isGeneralQuery = _containsAny(enhancedQuery.toLowerCase(), ['todos', 'varios', 'diferentes', 'lista', 'opciones']);
        
        if (isGeneralQuery) {
          // Mostrar hasta 3 tratamientos si la consulta parece general
          List<Map<String, dynamic>> relevantPrices = [];
          
          for (var price in prices) {
            final treatment = price['treatment'].toString().toLowerCase();
            final description = price['description']?.toString().toLowerCase() ?? '';
            
            for (var keyword in keywords) {
              if (treatment.contains(keyword) || description.contains(keyword)) {
                relevantPrices.add(price);
                break;
              }
            }
            
            if (relevantPrices.length >= 3) break;
          }
          
          if (relevantPrices.isNotEmpty) {
            final buffer = StringBuffer();
            buffer.writeln('**Algunos tratamientos relacionados:**\n');
            
            for (var price in relevantPrices) {
              buffer.writeln('**${price['treatment']}**');
              final desc = price['description'] ?? "Tratamiento especializado en nuestras clínicas.";
              buffer.writeln(desc);
              buffer.writeln('**Precio:** ${price['price']}\n');
            }
            
            return buffer.toString();
          }
        }
      }
      
      // Mensaje para cuando no hay coincidencias
      return """
  Lo siento, no encontré información específica sobre precios para tu consulta. 
  Por favor, pregunta por un tratamiento específico como "Botox", "aumento de labios" o "rinoplastia".
      """;
    } catch (e) {
      debugPrint('⚠️ Error al obtener precios: $e');
      return "Lo siento, hubo un problema al buscar información de precios. Por favor, intenta con otra pregunta.";
    }
  }

  // Añade este método auxiliar si no existe ya
  bool _containsAny(String text, List<String> keywords) {
    for (var keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  // NUEVO: Método para verificar si un mensaje contiene un tratamiento específico
  bool _containsSpecificTreatment(String message) {
    final commonTreatments = [
      'botox', 'rinomodelación', 'rinoplastia', 'rinoseptoplastia', 'nariz', 'labio', 'labios',
      'facial', 'peeling', 'mesoterapia', 'ácido', 'hialurónico', 'aumento', 'lifting',
      'relleno', 'ojeras', 'vitaminas'
    ];
    
    final lowerMessage = message.toLowerCase();
    
    for (var treatment in commonTreatments) {
      if (lowerMessage.contains(treatment)) {
        return true;
      }
    }
    
    return false;
  }

  // Método para extraer palabras clave de una consulta
  List<String> extractKeywords(String query) {
    // Normalizar el texto: minúsculas y sin acentos
    final normalizedText = _normalizeText(query);
    
    // Lista de palabras a ignorar (stopwords)
    final stopwords = [
      'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'y', 'o', 'a', 'de', 'en', 'con', 'por',
      'para', 'como', 'que', 'se', 'su', 'sus', 'mi', 'mis', 'tu', 'tus', 'es', 'son', 'sobre',
      'hay', 'tienen', 'tienen', 'quiero', 'saber', 'conocer', 'informacion', 'informacion',
      'tener', 'sobre', 'acerca', 'cuales', 'todos', 'todas', 'del', 'al', 'me', 'gustaria',
      'podrias', 'puede', 'pueden', 'ofrece', 'ofrecen'
    ];
    
    // Dividir en palabras
    final words = normalizedText.split(RegExp(r'\s+|,|\.|\?|¿|!|¡'));
    
    // Filtrar palabras relevantes
    List<String> keywords = words
        .where((word) => word.length > 2)  // Palabras de al menos 3 caracteres
        .where((word) => !stopwords.contains(word))  // Excluir stopwords
        .toList();
    
    // Palabras clave prioritarias (áreas del cuerpo y tratamientos)
    final priorityKeywords = [
      'nariz', 'facial', 'cara', 'labios', 'piel', 'cuerpo', 'ojos', 'frente', 'cuello',
      'botox', 'relleno', 'acido', 'hialuronico', 'peeling', 'hidratacion', 'rino', 'rinoplastia'
    ];
    
    // Priorizar términos específicos
    List<String> priorityMatches = [];
    for (var word in keywords) {
      if (priorityKeywords.contains(word)) {
        priorityMatches.add(word);
      }
    }
    
    // Si encontramos palabras prioritarias, ponerlas primero
    if (priorityMatches.isNotEmpty) {
      keywords = [...priorityMatches, ...keywords.where((w) => !priorityMatches.contains(w))];
    }
    
    debugPrint('🔍 Palabras clave extraídas: $keywords');
    return keywords;
  }

  // Método para obtener todos los tratamientos por área/categoría
  Future<String> getAllTreatmentsByArea(String query) async {
    try {
      // Extraer palabras clave del query
      final keywords = extractKeywords(query);
      debugPrint('🔍 Palabras clave extraídas: ${keywords.join(", ")}');
      
      // Obtener todos los tratamientos de Supabase
      final supabase = SupabaseService().client;
      final response = await supabase
          .from('treatments')
          .select('*')
          .order('name');
      
      debugPrint('📋 Obtenidos ${response.length} tratamientos');
      
      // Convertir la respuesta a una lista de mapas
      List<Map<String, dynamic>> treatments = List<Map<String, dynamic>>.from(response);
      
      // Filtrar por área o categoría si se especificó
      List<Map<String, dynamic>> filteredTreatments = [];
      
      // Palabras clave para filtrar por área
      final areaKeyword = keywords.firstWhere(
          (k) => ['nariz', 'facial', 'cara', 'labios', 'piel', 'cuerpo'].contains(k), 
          orElse: () => '');
      
      if (areaKeyword.isNotEmpty) {
        // Filtrar tratamientos por el área especificada
        filteredTreatments = treatments.where((t) {
          String name = t['name']?.toString().toLowerCase() ?? '';
          String desc = t['description']?.toString().toLowerCase() ?? '';
          String category = t['category']?.toString().toLowerCase() ?? '';
          
          // Para nariz específicamente
          if (areaKeyword == 'nariz') {
            return name.contains('nariz') || 
                  name.contains('rinop') || 
                  name.contains('rino') || 
                  desc.contains('nariz') || 
                  desc.contains('nasal') ||
                  category.contains('nariz');
          }
          
          // Para otras áreas
          return name.contains(areaKeyword) || 
                desc.contains(areaKeyword) || 
                category.contains(areaKeyword);
        }).toList();
      }
      
      // Si no hay filtrados, mostrar mensaje de que no se encontraron tratamientos
      if (filteredTreatments.isEmpty) {
        return "Lo siento, no encontré tratamientos específicos para '${areaKeyword}' en nuestra base de datos.";
      }
      
      // Construir respuesta con todos los tratamientos encontrados
      final buffer = StringBuffer();
      buffer.writeln('**Tratamientos disponibles para ${areaKeyword}:**\n');
      
      for (var treatment in filteredTreatments) {
        buffer.writeln('**${treatment['name']}**');
        buffer.writeln('• ${treatment['description']}');
        buffer.writeln('• Duración aproximada: ${treatment['duration']} minutos');
        buffer.writeln('• Precio: ${treatment['price'].toStringAsFixed(2)}€\n');
      }
      
      buffer.writeln('\n¿Te gustaría más información sobre alguno de estos tratamientos en particular?');
      
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error obteniendo tratamientos: $e');
      return "Lo siento, hubo un problema al buscar los tratamientos disponibles. ¿Puedes intentar con otra pregunta?";
    }
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
    
    // AMPLIADO: Detectar tratamientos mencionados con una lista más extensa
    final treatmentsKeywords = {
      'botox': ['botox', 'toxina', 'botulínica', 'arrugas'],
      'ácido hialurónico': ['ácido', 'hialurónico', 'relleno'],
      'labios rusos': ['ruso', 'rusos', 'lips', 'efecto'],
      'labios': ['labio', 'labios', 'aumento', 'labial'],
      'rinomodelación': ['rino', 'nariz', 'rinomodelación'],
      'rinoplastia': ['rinoplastia', 'cirugía nariz'],
      'rinoseptoplastia': ['rinoseptoplastia', 'tabique', 'septum'],
      'peeling': ['peeling', 'químico', 'exfoliación'],
      'mastopexia': ['mastopexia', 'elevación', 'pecho', 'mamaria', 'mama', 'senos'],
      'aumento de pecho': ['aumento', 'mamario', 'implante', 'silicona', 'senos'],
      'lipoescultura': ['lipo', 'lipoescultura', 'liposucción', 'grasa'],
      'blefaroplastia': ['blefaroplastia', 'párpados', 'ojos'],
      'abdominoplastia': ['abdominoplastia', 'abdomen', 'vientre'],
      'lifting': ['lifting', 'tensado', 'facial'],
      'plasma': ['plasma', 'plaquetas', 'prp', 'rico'],
      'vitaminas': ['vitaminas', 'cocktail', 'inyección'],
      'rejuvenecimiento': ['rejuvenecimiento', 'anti', 'edad', 'arrugas'],
      'mesoterapia': ['mesoterapia', 'meso', 'nutrición']
    };
    
    // MEJORADO: Estrategia de detección del tratamiento más relevante
    String mostRecentTreatment = '';
    int mostRecentPosition = -1;
    
    // Para cada tratamiento, buscar la posición más reciente de mención
    treatmentsKeywords.forEach((treatment, keywords) {
      for (final keyword in keywords) {
        final keywordPosition = recentText.lastIndexOf(keyword);
        if (keywordPosition > -1 && keywordPosition > mostRecentPosition) {
          mostRecentPosition = keywordPosition;
          mostRecentTreatment = treatment;
          
          // Añadir a la lista de tratamientos mencionados si no existe ya
          if (!context.mentionedTreatments.contains(treatment)) {
            context.mentionedTreatments.add(treatment);
          }
        }
      }
    });
    
    // Definir el tratamiento más reciente si se encontró alguno
    if (mostRecentPosition > -1) {
      context.lastMentionedTreatment = mostRecentTreatment;
      debugPrint('🔄 Tratamiento más reciente detectado: ${context.lastMentionedTreatment}');
    }
    
    // Detectar ubicaciones mencionadas
    final locationsKeywords = ['barcelona', 'madrid', 'málaga', 'tenerife'];
    for (final location in locationsKeywords) {
      if (recentText.contains(location)) {
        context.lastMentionedLocation = location;
        break;
      }
    }
    
    // Verificar si hay un mensaje reciente que pregunte específicamente por un precio
    final latestMessages = recentMessages.length > 2 ? recentMessages.sublist(recentMessages.length - 2) : recentMessages;
    final latestText = latestMessages.map((m) => m.text.toLowerCase()).join(' ');
    
    if ((latestText.contains('precio') || latestText.contains('cuesta') || latestText.contains('cuánto')) && 
        context.lastMentionedTreatment.isNotEmpty) {
      debugPrint('💲 Detectada pregunta específica de precio para: ${context.lastMentionedTreatment}');
    }
    
    debugPrint('📊 Análisis de contexto completo: Tema: ${context.currentTopic}, Tratamiento: ${context.lastMentionedTreatment}');
    return context;
  }

  // Método para reiniciar el chat
  
  void resetChat() {
    messages.clear();
    isBookingFlow = false;
    isTyping = false;
    sendWelcomeMessage();
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