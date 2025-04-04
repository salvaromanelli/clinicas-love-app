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

       // Detectar si es una consulta sobre citas
      final lowerMessage = message.toLowerCase();
      if (_isAppointmentQuery(lowerMessage)) {
        debugPrint('📅 Detectada consulta sobre citas');
        final appointmentResponse = await handleAppointmentRequest(message);
        return ProcessedMessage(
          text: appointmentResponse,
          additionalContext: "show_schedule_button"
        );
      }


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

  // Método auxiliar para detectar consultas sobre citas
bool _isAppointmentQuery(String text) {
  final appointmentKeywords = [
    'cita', 'citas', 'agendar', 'reservar', 'programar', 'consulta', 
    'turno', 'hora', 'horario', 'disponible', 'disponibilidad'
  ];
  
  final appointmentPhrases = [
    'quiero una cita', 'sacar una cita', 'pedir hora', 'reservar hora',
    'cuando puedo ir', 'cuando me pueden atender', 'me gustaría agendar',
    'para cuando hay', 'tienen disponibilidad'
  ];
  
  // Verificar coincidencias exactas con frases comunes
  for (var phrase in appointmentPhrases) {
    if (text.contains(phrase)) {
      return true;
    }
  }
  
  // Verificar palabras clave en combinación con verbos de intención
  final intentVerbs = ['quiero', 'puedo', 'necesito', 'quisiera', 'me gustaría', 'deseo'];
  
  for (var verb in intentVerbs) {
    if (text.contains(verb)) {
      for (var keyword in appointmentKeywords) {
        if (text.contains(keyword)) {
          return true;
        }
      }
    }
  }

    // Verificar palabras clave individuales con alta relevancia
  int keywordCount = 0;
  for (var keyword in appointmentKeywords) {
    if (text.contains(keyword)) {
      keywordCount++;
    }
    
    // Si hay al menos dos palabras clave de cita, considerarlo una consulta de cita
    if (keywordCount >= 2) {
      return true;
    }
  }
  
  return false;
}


  String ensurePriceFilter(String responseText, String userQuery) {
  // Verificar si la consulta es sobre precios
  bool isAskingForPrice = userQuery.toLowerCase().contains('precio') || 
                        userQuery.toLowerCase().contains('cuesta') || 
                        userQuery.toLowerCase().contains('cuánto') ||
                        userQuery.toLowerCase().contains('cuanto') ||
                        userQuery.toLowerCase().contains('valor') ||
                        userQuery.toLowerCase().contains('coste');
                        
  // Si NO está preguntando por precios, eliminar cualquier mención de precio
  if (!isAskingForPrice) {
    // Patrones comunes de precios en respuestas
    final pricePatterns = [
      RegExp(r'Precio:.*?€'),
      RegExp(r'precio:.*?€'),
      RegExp(r'precio desde.*?€'),
      RegExp(r'Precio desde.*?€'),
      RegExp(r'\d+[.,]?\d*\s*€'),
      RegExp(r'cuesta.*?\d+[.,]?\d*\s*€'),
      RegExp(r'valor.*?\d+[.,]?\d*\s*€'),
    ];
    
    String filteredResponse = responseText;
    
    // Reemplazar todos los patrones de precio con mensaje estándar
    for (var pattern in pricePatterns) {
      filteredResponse = filteredResponse.replaceAll(
        pattern, 
        "Para información sobre precios, por favor pregunta específicamente o consulta en nuestras clínicas"
      );
    }
    
    debugPrint('🔍 FILTRO DE PRECIO APLICADO');
    return filteredResponse;
  }
  
  return responseText;
}

  
  // Genera sugerencias basadas en contexto detectado por la IA
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
  void addBotMessage(String text, {String? additionalContext, String userQuery = ""}) {
    // NO aplicar filtro de precios para mensajes que contienen enlaces de WhatsApp
    final filteredText = text.contains("wa.me/") ? text : ensurePriceFilter(text, userQuery);
    messages.add(ChatMessage(
      text: filteredText, // Usar el filteredText
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
  
  String _formatPriceResponse(Map<String, dynamic> price) {
  // Formatear precios y manejar formatos irregulares
  String priceText = price['price'].toString().trim();
  
  // Detectar si hay múltiples precios separados por "|"
  if (priceText.contains('|')) {
    final prices = priceText.split('|');
    priceText = "Desde ${prices.first.trim()} €";
  }
  
  // Normalizar la descripción
  String description = price['description'] ?? "Tratamiento especializado realizado por nuestros médicos expertos.";
  
  // Corregir descripciones incompletas
  if (description.endsWith('un') || description.length < 20) {
    if (price['treatment'].toString().toLowerCase().contains('arruga')) {
      description = "Tratamiento para reducir las arrugas y líneas de expresión mediante la aplicación de toxina botulínica, que relaja los músculos faciales responsables de la formación de estas líneas.";
    } else {
      description = "Tratamiento especializado realizado por nuestros médicos expertos para mejorar la apariencia estética y el bienestar del paciente.";
    }
  }
  
  return "**${price['treatment']}**\n\n$description\n\n**Precio:** $priceText\n\n¿Deseas agendar una cita para este tratamiento?";
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
      
      // NUEVO: Simplificar query para mejor coincidencia
      String simplifiedQuery = _simplifyTreatmentQuery(enhancedQuery);
      debugPrint('🔄 Consulta simplificada: $simplifiedQuery');
      
      // Obtener el contexto relevante usando la consulta mejorada
      final knowledgeContext = await _knowledgeBase.getRelevantContext(
        simplifiedQuery,  // Usar la consulta simplificada
        preferredType: 'prices'
      );
      
      if (knowledgeContext.containsKey('prices') && knowledgeContext['prices'] is List) {
        final List<Map<String, dynamic>> prices = List<Map<String, dynamic>>.from(knowledgeContext['prices']);
        
        debugPrint('💰 Encontrados ${prices.length} precios en la base de conocimiento');

        // AÑADIR AQUÍ: Extraer palabras clave del mensaje antes de usarlas
        final List<String> keywords = extractKeywords(enhancedQuery);
        debugPrint('🔍 Palabras clave extraídas: ${keywords.join(", ")}');
        
        // NUEVO: Mejorar detección para rinomodelación
        if (enhancedQuery.toLowerCase().contains('rino') || 
            enhancedQuery.toLowerCase().contains('nariz')) {
          
          debugPrint('👃 Detectada consulta sobre rinomodelación/rinoplastia');
          
          // Buscar específicamente tratamientos de nariz
          final nasalTreatments = prices.where((price) => 
            price['treatment'].toString().toLowerCase().contains('rino') || 
            price['treatment'].toString().toLowerCase().contains('nariz')
          ).toList();
          
          if (nasalTreatments.isNotEmpty) {
            // Diferenciar entre quirúrgica y no quirúrgica
            if (enhancedQuery.toLowerCase().contains('sin') && 
                enhancedQuery.toLowerCase().contains('cirug')) {
              
              // Buscar rinomodelación no quirúrgica
              final nonSurgicalOptions = nasalTreatments.where((p) => 
                !p['treatment'].toString().toLowerCase().contains('plastia') &&
                p['treatment'].toString().toLowerCase().contains('modelo')
              ).toList();
              
              if (nonSurgicalOptions.isNotEmpty) {
                return _formatPriceResponse(nonSurgicalOptions.first);
              }
            }
            
            // Si no se especifica o no encontramos la versión sin cirugía, devolver la primera opción
            return _formatPriceResponse(nasalTreatments.first);
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
          
          return _formatPriceResponse(bestMatch);
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
      return """Lo siento, no encontré información específica sobre precios para tu consulta. 
                Por favor, pregunta por un tratamiento específico como "Botox", "aumento de labios" o "rinoplastia".""";
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

  String _simplifyTreatmentQuery(String query) {
  final lower = query.toLowerCase();
  
  // Para rinomodelación
  if (lower.contains('rinomodel') || 
      (lower.contains('rino') && lower.contains('sin') && lower.contains('cirug'))) {
    return "rinomodelación precio";
  }
  
  // Para otros tratamientos se pueden añadir más reglas
  
  return query; // Si no hay reglas específicas, devolver la consulta original
  }
  
    // Método para procesar consultas sobre tratamientos usando IA
  Future<String> recognizeAndRespondToTreatment(String userQuery) async {
    try {
      // 1. Detectar si es una pregunta sobre catálogo general
      if (_isGeneralCatalogQuery(userQuery.toLowerCase())) {
        debugPrint('📚 Detectada consulta sobre catálogo general, redirigiendo...');
        return await getAllTreatmentsByCategory();
      }
      
      // 2. Obtener tratamientos de la base de datos
      final supabase = SupabaseService().client;
      final response = await supabase
          .from('treatments')
          .select('*');
      
      final treatments = List<Map<String, dynamic>>.from(response);
      debugPrint('📋 Total de tratamientos disponibles: ${treatments.length}');
      
      // 3. Crear prompt para que Claude identifique el tratamiento
      final treatmentNames = treatments.map((t) => t['name']).toList();
      final prompt = """
      Consulta del usuario: "$userQuery"
      
      Lista de tratamientos disponibles en Clínicas Love:
      ${treatmentNames.join(', ')}
      
      Basado en la consulta del usuario, identifica:
      1. Si está preguntando específicamente por un tratamiento
      2. Qué tratamiento de la lista anterior mejor coincide con su consulta
      3. Si está preguntando por un tratamiento que combina varias técnicas o productos
      
      Responde en formato JSON:
      {
        "isTreatmentQuery": true/false,
        "matchedTreatment": "nombre del tratamiento más cercano o null",
        "isComboTreatment": true/false,
        "components": ["componente1", "componente2"]
      }
      """;
      
      // 4. Obtener análisis de Claude
      final aiResponse = await _aiService.getJsonResponse(prompt);
      debugPrint('🧠 Análisis de la IA: $aiResponse');

      
      // 5. Manejar respuesta identificada - MEJORAR LA VERIFICACIÓN
      if (aiResponse['isTreatmentQuery'] == true && aiResponse['matchedTreatment'] != null) {
        final matchedTreatment = aiResponse['matchedTreatment'];
        debugPrint('✅ Tratamiento identificado: $matchedTreatment');
        
        // NUEVO: Definir matchingTreatments - esto debe ir aquí
        final List<Map<String, dynamic>> matchingTreatments = treatments.where((t) {
          final treatmentName = t['name'].toString().toLowerCase();
          final matchedName = matchedTreatment.toString().toLowerCase();
          return treatmentName.contains(matchedName) || matchedName.contains(treatmentName);
        }).toList();
        debugPrint('🔍 Encontrados ${matchingTreatments.length} tratamientos que coinciden con "$matchedTreatment"');
        
        // Casos especiales con palabras clave específicas
        if (userQuery.toLowerCase().contains('nariz') && userQuery.toLowerCase().contains('ácido')) {
          debugPrint('🔍 Detectada consulta sobre rinomodelación con ácido hialurónico');
        }
        
        // 6. Si encontramos coincidencias, mostrar el tratamiento mejor coincidente
        if (matchingTreatments.isNotEmpty) {
          // Verificar si la consulta es sobre precios
          bool isAskingForPrice = userQuery.toLowerCase().contains('precio') || 
                                  userQuery.toLowerCase().contains('cuesta') || 
                                  userQuery.toLowerCase().contains('cuánto') ||
                                  userQuery.toLowerCase().contains('cuanto') ||
                                  userQuery.toLowerCase().contains('valor');
          
          // Ordenar por longitud de nombre para priorizar coincidencias más precisas
          matchingTreatments.sort((a, b) => 
            (b['name'].toString().length - a['name'].toString().length));
          
          // Pasar el flag para incluir precios solo si se pregunta por ellos
          return formatTreatmentInfo(matchingTreatments.first, includePrices: isAskingForPrice);
        }
        
        // 7. Para casos especiales de tratamientos combinados
        if (aiResponse['isComboTreatment'] == true) {
          // Buscar en la base de datos primero antes de usar respuestas hardcoded
          final List<String> components = List<String>.from(aiResponse['components'] ?? []);
          
          // Combinar información de los componentes identificados
          if (components.isNotEmpty) {
            final componentsTreatments = treatments.where((t) => 
              components.any((c) => t['name'].toString().toLowerCase().contains(c.toLowerCase())))
              .toList();
            
            if (componentsTreatments.isNotEmpty) {
              return _formatCombinedTreatmentInfo(componentsTreatments, userQuery);
            }
          }
        }
      }
      
      // 8. Si no encontramos coincidencias, sugerir tratamientos relevantes
      final keywords = extractKeywords(userQuery);
      if (keywords.isNotEmpty) {
        final relevantTreatments = _findRelevantTreatments(treatments, keywords);
        
        if (relevantTreatments.isNotEmpty) {
          return _formatSuggestedTreatments(relevantTreatments);
        }
      }
      
      // 9. Mensaje de respuesta final cuando no hay coincidencias
      return "Lo siento, no encontré información específica sobre el tratamiento por el que preguntas. "
            "Ofrecemos diversos tratamientos estéticos como Botox, rellenos dérmicos, rinomodelación, "
            "entre otros. ¿Te gustaría ver nuestro catálogo completo de tratamientos?";
      
    } catch (e) {
      debugPrint('⚠️ Error en recognizeAndRespondToTreatment: $e');
      return "Lo siento, tuve un problema al procesar tu consulta sobre tratamientos. ¿Podrías reformularla?";
    }
  }

    // Método para formatear tratamientos especiales con datos reales
  String _formatSpecialTreatment(Map<String, dynamic> baseData, String treatmentName, String description) {
    final buffer = StringBuffer();
    
    buffer.writeln('**$treatmentName**\n');
    buffer.writeln(description);
    
    // Usar SOLO datos reales de la base para duración y precio
    if (baseData['duration'] != null) {
      buffer.writeln('\n• Duración aproximada: ${baseData['duration']} minutos');
    }
    
    if (baseData['price'] != null) {
      buffer.writeln('• Precio: desde ${baseData['price'].toStringAsFixed(2)}€\n');
    } else {
      buffer.writeln('• Para información de precios actualizada, por favor consulta en nuestras clínicas.\n');
    }
    
    buffer.writeln('¿Deseas agendar una cita para este tratamiento?');
    return buffer.toString();
  }

  // Método auxiliar para detectar si es una consulta sobre catálogo general
  bool _isGeneralCatalogQuery(String query) {
    return (query.contains('qué tratamientos') || 
            query.contains('que tratamientos') || 
            query.contains('cuáles son') || 
            query.contains('catálogo') ||
            (query.contains('tratamientos') && query.contains('todos'))) && 
          !query.contains('nariz') && 
          !query.contains('facial') && 
          !query.contains('botox');
  }

  // Método para encontrar tratamientos relevantes según palabras clave
  List<Map<String, dynamic>> _findRelevantTreatments(List<Map<String, dynamic>> treatments, List<String> keywords) {
    final relevantTreatments = <Map<String, dynamic>>[];
    
    for (var treatment in treatments) {
      final name = treatment['name'].toString().toLowerCase();
      final description = treatment['description']?.toString().toLowerCase() ?? '';
      
      for (var keyword in keywords) {
        if (name.contains(keyword) || description.contains(keyword)) {
          relevantTreatments.add(treatment);
          break;
        }
      }
      
      if (relevantTreatments.length >= 3) break;
    }
    
    return relevantTreatments;
  }

  // Formatear información para tratamientos combinados
  String _formatCombinedTreatmentInfo(List<Map<String, dynamic>> treatments, String userQuery) {
    final buffer = StringBuffer();
    // Verificar si la consulta es sobre precios
    bool isAskingForPrice = userQuery.toLowerCase().contains('precio') || 
                            userQuery.toLowerCase().contains('cuesta') || 
                            userQuery.toLowerCase().contains('cuánto') ||
                            userQuery.toLowerCase().contains('cuanto') ||
                            userQuery.toLowerCase().contains('valor');
    
    // MEJORADO: Ampliar detección para incluir más términos relacionados con nariz
    if ((userQuery.toLowerCase().contains('rinoplastia') || 
         userQuery.toLowerCase().contains('nariz') ||
         userQuery.toLowerCase().contains('rinomodel') ||
         userQuery.toLowerCase().contains('tratamiento') && userQuery.toLowerCase().contains('nariz')) && 
        userQuery.toLowerCase().contains('ácido hialurónico')) {
      
      // Buscar si existe un tratamiento específico de rinomodelación en los datos
      final rinomodelacion = treatments.firstWhere(
        (t) => t['name'].toString().toLowerCase().contains('rinomodel'), 
        orElse: () => <String, dynamic>{}
      );
      
      buffer.writeln('**Rinomodelación con Ácido Hialurónico**\n');
      buffer.writeln('Sí, ofrecemos este tratamiento en nuestras clínicas.\n');
      
      // IMPORTANTE: Usar descripción real de la base de datos si existe
      if (rinomodelacion.isNotEmpty && rinomodelacion['description'] != null) {
        buffer.writeln(rinomodelacion['description']);
      } else {
        buffer.writeln('Tratamiento no quirúrgico para mejorar la apariencia de la nariz mediante inyecciones de ácido hialurónico.');
      }
    } else {
      buffer.writeln('**Tratamiento Combinado**\n');
      buffer.writeln('Ofrecemos este tratamiento combinado en nuestras clínicas.\n');
    }
    
    // SOLUCIÓN PARA PRECIOS INVENTADOS: Comprobar si tenemos datos reales
    bool hasTreatmentData = treatments.isNotEmpty && 
                           (treatments.first['price'] != null || 
                            treatments.first['duration'] != null);
    
    if (hasTreatmentData) {
      // Incluir información real de los componentes
      buffer.writeln('\nEl tratamiento incluye:');
      for (var t in treatments) {
        buffer.writeln('• **${t['name']}**');
      }
      
      // Duración y precio solo si hay datos reales y se pregunta por precios
      if (treatments.any((t) => t['duration'] != null)) {
        buffer.writeln('\nDuración aproximada: ${treatments.fold(0.0, (sum, t) => sum + (t['duration'] ?? 30))} minutos');
      }
      
      if (isAskingForPrice) {
        if (treatments.any((t) => t['price'] != null)) {
          buffer.writeln('Precio: desde ${treatments.fold(0.0, (sum, t) => sum + (t['price'] ?? 0)).toStringAsFixed(2)}€');
          buffer.writeln('(Por favor, consulta en clínica para el precio exacto de tu tratamiento personalizado)');
        } else {
          buffer.writeln('Por favor, consulta en nuestras clínicas para información detallada de precios.');
        }
      }
    } else {
      // NO INVENTAR información - ser honesto cuando no tenemos datos
      buffer.writeln('\nPara recibir información detallada sobre duración y precios de este tratamiento combinado, te recomendamos consultar directamente en nuestras clínicas o llamar a nuestro teléfono de atención al cliente.');
    }
    
    buffer.writeln('\n¿Deseas agendar una cita para este tratamiento?');
    return buffer.toString();
  }

  // Formatear sugerencias de tratamientos relevantes
  String _formatSuggestedTreatments(List<Map<String, dynamic>> treatments) {
    final buffer = StringBuffer();
    
    buffer.writeln('No encontré un tratamiento exacto para tu consulta, pero estos podrían interesarte:\n');
    
    for (var treatment in treatments) {
      buffer.writeln('**${treatment['name']}**');
      buffer.writeln('• ${treatment['description'] ?? "Tratamiento especializado en nuestras clínicas"}');
      buffer.writeln('');
    }
    
    buffer.writeln('¿Te gustaría más información sobre alguno de estos tratamientos?');
    return buffer.toString();
  }

  // Método auxiliar para formatear la información del tratamiento
  String formatTreatmentInfo(Map<String, dynamic> treatment, {bool includePrices = false}) {
    final buffer = StringBuffer();
    
    buffer.writeln('**${treatment['name']}**\n');
    
    // Normalizar la descripción
    String description = treatment['description'];
    if (description == null || description.isEmpty || description.length < 20 || description.endsWith('un')) {
      description = "Tratamiento especializado realizado por nuestros médicos expertos en medicina estética.";
    }
    buffer.writeln(description);
    
    // Añadir duración si está disponible
    if (treatment['duration'] != null) {
      try {
        final duration = double.tryParse(treatment['duration'].toString()) ?? 0;
        if (duration > 0) {
          buffer.writeln('\n• Duración aproximada: ${duration.toStringAsFixed(0)} minutos');
        }
      } catch (e) {
        // No mostrar duración si hay error
      }
    }
    
    // Solo incluir precio si se solicita específicamente
    if (includePrices && treatment['price'] != null) {
      try {
        final price = double.tryParse(treatment['price'].toString());
        if (price != null && price > 0) {
          buffer.writeln('• Precio: ${price.toStringAsFixed(2)}€\n');
        } else {
          buffer.writeln('\nPara información detallada sobre precios, por favor consulta directamente en nuestras clínicas.\n');
        }
      } catch (e) {
        buffer.writeln('\nPara información detallada sobre precios, por favor consulta directamente en nuestras clínicas.\n');
      }
    } else {
      buffer.writeln('\n');
    }
    
    buffer.writeln('¿Te gustaría más información o agendar una cita para este tratamiento?');
    
    return buffer.toString();
  }

  // Método para obtener todos los tratamientos organizados por categoría
  Future<String> getAllTreatmentsByCategory() async {
    try {
      // Obtener todos los tratamientos de Supabase
      final supabase = SupabaseService().client;
      final response = await supabase
          .from('treatments')
          .select('*')
          .order('category');
      
      debugPrint('📋 Obtenidos ${response.length} tratamientos');
      
      // Convertir la respuesta a una lista de mapas
      List<Map<String, dynamic>> treatments = List<Map<String, dynamic>>.from(response);
      
      // Agrupar tratamientos por categoría
      Map<String, List<Map<String, dynamic>>> categorizedTreatments = {};
      
      for (var treatment in treatments) {
        String category = treatment['category'] ?? 'Otros';
        if (!categorizedTreatments.containsKey(category)) {
          categorizedTreatments[category] = [];
        }
        categorizedTreatments[category]!.add(treatment);
      }
      
      // Ordenar categorías según la preferencia del usuario
      final orderedCategories = [
        'Medicina Estética Facial',
        'Cirugía Estética Facial',
        'Cirugía Corporal',
        'Medicina Estética Corporal',
        'Otros'
      ];
      
      // Construir respuesta con tratamientos por categoría
      final buffer = StringBuffer();
      buffer.writeln('**Catálogo de tratamientos disponibles:**\n');
      
      for (var category in orderedCategories) {
        if (categorizedTreatments.containsKey(category)) {
          buffer.writeln('\n### $category\n');
          
          // Limitar a 3 tratamientos para Medicina Estética Facial como se solicitó
          var treatmentsToShow = categorizedTreatments[category]!;
          if (category == 'Medicina Estética Facial') {
            treatmentsToShow = treatmentsToShow.take(3).toList();
          }
          
          for (var treatment in treatmentsToShow) {
            buffer.writeln('• **${treatment['name']}**');
          }
        }
      }
      
      buffer.writeln('\n\n¿Te gustaría más información sobre algún tratamiento en particular?');
      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error obteniendo tratamientos: $e');
      return "Lo siento, tuve un problema al buscar el catálogo de tratamientos. ¿Puedo ayudarte con algo más?";
    }
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
      
      // Verificar si la consulta es sobre precios
      bool isAskingForPrice = query.toLowerCase().contains('precio') || 
                            query.toLowerCase().contains('cuesta') || 
                            query.toLowerCase().contains('cuánto') ||
                            query.toLowerCase().contains('cuanto') ||
                            query.toLowerCase().contains('valor');

      for (var treatment in filteredTreatments) {
        buffer.writeln('**${treatment['name']}**');
        buffer.writeln('• ${treatment['description']}');
        buffer.writeln('• Duración aproximada: ${treatment['duration']} minutos');
        
        // Solo mostrar precio si lo solicita específicamente
        if (isAskingForPrice && treatment['price'] != null) {
          buffer.writeln('• Precio: ${treatment['price'].toStringAsFixed(2)}€\n');
        } else {
          buffer.writeln(''); // Línea en blanco sin precio
        }
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

  // Método para manejar solicitudes de citas
  Future<String> handleAppointmentRequest(String userMessage) async {
    // Usar StringBuffer para evitar problemas de indentación
    final buffer = StringBuffer();
    
    buffer.writeln('**Información sobre Citas**\n');
    buffer.writeln('Como asistente virtual, no puedo agendar citas directamente, pero tienes dos opciones sencillas para hacerlo:\n');
    buffer.writeln('1️⃣ **Usar el botón de "Agendar Cita"** que aparece justo debajo de este mensaje. Al presionarlo, podrás programar una cita directamente desde la aplicación.\n');
    buffer.writeln('2️⃣ **Contactar por WhatsApp** para una atención más personalizada:');

    // NUEVO: Definir directamente las clínicas con números verificados
    final List<Map<String, String>> clinics = [
      {'name': 'Barcelona', 'whatsapp': '+34 938526533'},
      {'name': 'Madrid', 'whatsapp': '+34 919993515'},
      {'name': 'Málaga', 'whatsapp': '+34 638189262'},
      {'name': 'Tenerife', 'whatsapp': '+34 608333285'},
    ];
    
    // Generar enlaces de WhatsApp para cada clínica
    for (var clinic in clinics) {
      final name = clinic['name']!;
      final phone = clinic['whatsapp']!;
      
      // Formatear número para WhatsApp (eliminar espacios, +, etc.)
      final whatsappNumber = _formatWhatsAppNumber(phone);
      
      // Generar enlace de WhatsApp
      buffer.writeln('\n• **$name**: [📱 CONTACTAR POR WHATSAPP: $phone](https://wa.me/$whatsappNumber?text=Hola,%20me%20gustaría%20agendar%20una%20cita)');
    }
    
    buffer.writeln('\n¿Tienes alguna preferencia sobre fecha u horario para tu cita?');
    
    return buffer.toString();
  }

  // Añadir este método auxiliar para formatear números de WhatsApp
  String _formatWhatsAppNumber(String phoneNumber) {
    // Eliminar espacios, paréntesis, guiones y '+'
    return phoneNumber
        .replaceAll(RegExp(r'[\s\(\)\-\+]'), '')
        // Asegurarse de que empiece con código de país (si no tiene prefijo, asumimos España)
        .replaceAll(RegExp(r'^(?!34|0034)'), '34');
  }
}