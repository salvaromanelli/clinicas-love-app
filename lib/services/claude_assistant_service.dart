import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/services/knowledge_base.dart';
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProcessedMessage {
  final String text;
  final String? additionalContext;
  
  ProcessedMessage({
    required this.text,
    this.additionalContext,
  });
}

class ClaudeAssistantService {
  final String? apiKey;
  final String model;
  final double temperature;
  final bool useFallback;
  final KnowledgeBase? knowledgeBase;
  
  ClaudeAssistantService({
    this.apiKey,
    this.model = 'claude-3-haiku-20240307', 
    this.temperature = 0.7,
    this.useFallback = true,
    this.knowledgeBase,
  });

  // Obtener API key de Claude desde .env
  String _getApiKey() {
    return apiKey ?? dotenv.env['CLAUDE_API_KEY'] ?? '';
  }

    // Añadir este método en la clase ClaudeAssistantService
  bool _isLocationQuestion(String text) {
    final lowerText = text.toLowerCase();
    return lowerText.contains('dónde') || 
          lowerText.contains('donde') || 
          lowerText.contains('ubicación') || 
          lowerText.contains('ubicacion') ||
          lowerText.contains('dirección') || 
          lowerText.contains('direccion') ||
          lowerText.contains('clínica') ||
          lowerText.contains('sede') ||
          lowerText.contains('lugar') ||
          (lowerText.contains('están') && (
              lowerText.contains('ubicad') || 
              lowerText.contains('situad') || 
              lowerText.contains('localiz')
          ));
  }

  // Añadir este método que devuelve respuestas hardcoded para ubicaciones
  ProcessedMessage _getHardcodedLocationResponse(String language) {
    String responseText;
    
    if (language == 'ca') {
      responseText = """Les nostres clíniques estan ubicades a:

  📍 **Clíniques Love Barcelona**
    Adreça: Carrer Diputacio 327, 08009 Barcelona
    Telèfon: +34 938526533
    Horari: Dilluns a Divendres: 11:00 - 20:00.

  📍 **Clíniques Love Madrid**
    Adreça: Calle Edgar Neville, 16, 28020 Madrid
    Telèfon: +34 919993515
    Horari: Dilluns a Divendres: 11:00 - 20:00.

  📍 **Clíniques Love Málaga**
    Adreça: Calle Alarcón Luján, 9. 29005 Málaga
    Telèfon: +34 638189262
    Horari: Dilluns a Divendres: 11:00 - 20:00.

  📍 **Clíniques Love Tenerife**
    Adreça: Calle san clemente 31. 38003 Santa Cruz de Tenerife
    Telèfon: +34 608333285
    Horari: Dilluns a Divendres: 11:00 - 20:00.

  Necessites informació sobre com arribar a alguna de les nostres clíniques?""";
    } else if (language == 'en') {
      responseText = """Our clinics are located at:

  📍 **Clínicas Love Barcelona**
    Address: Carrer Diputacio 327, 08009 Barcelona
    Phone: +34 938526533
    Hours: Monday to Friday: 9:00 AM - 8:00 PM.

  📍 **Clínicas Love Madrid**
    Address: Calle Edgar Neville, 16, 28020 Madrid
    Phone: +34 919993515
    Hours: Monday to Friday: 10:00 AM - 8:00 PM.

  📍 **Clínicas Love Málaga**
    Address: Calle Alarcón Luján, 9. 29005 Málaga
    Phone: +34 638189262
    Hours: Monday to Friday: 11:00 AM - 8:00 PM.

  📍 **Clínicas Love Tenerife**
    Address: Calle san clemente 31. 38003 Santa Cruz de Tenerife
    Phone: +34 608333285
    Hours: Monday to Friday: 11:00 AM - 8:00 PM.

  Do you need information on how to reach any of our clinics?""";
    } else {
      // Español por defecto
      responseText = """Nuestras clínicas están ubicadas en:

  📍 **Clínicas Love Barcelona**
    Dirección: Carrer Diputacio 327, 08009 Barcelona
    Teléfono: +34 938526533
    Horario: Lunes a Viernes: 9:00 - 20:00.

  📍 **Clínicas Love Madrid**
    Dirección: Calle Edgar Neville, 16, 28020 Madrid
    Teléfono: +34 919993515
    Horario: Lunes a Viernes: 10:00 - 20:00.

  📍 **Clínicas Love Málaga**
    Dirección: Calle Alarcón Luján, 9. 29005 Málaga
    Teléfono: +34 638189262
    Horario: Lunes a Viernes: 11:00 - 20:00.

  📍 **Clínicas Love Tenerife**
    Dirección: Calle san clemente 31. 38003 Santa Cruz de Tenerife
    Teléfono: +34 608333285
    Horario: Lunes a Viernes: 11:00 - 20:00.

  ¿Necesitas información sobre cómo llegar a alguna de nuestras clínicas?""";
    }

    debugPrint('✅ Respuesta de ubicación HARDCODED generada');
    return ProcessedMessage(
      text: responseText,
      additionalContext: "Respuesta directa sobre ubicaciones de clínicas"
    );
  }

  // Método principal simplificado para procesar mensajes del usuario
  Future<ProcessedMessage> processMessage(
    String userMessage, 
    List<ChatMessage> conversationHistory,
    Map<String, dynamic> currentState
  ) async {
    debugPrint('🔍 Procesando mensaje con Claude: "$userMessage"');

    final language = currentState['language'] ?? 'es';
    
    // Interceptar preguntas de ubicación directamente en el servicio
    if (_isLocationQuestion(userMessage)) {
      debugPrint('🏢 Interceptando pregunta sobre ubicación de clínicas en el servicio');
      return _getHardcodedLocationResponse(language);
    }
    
    // El resto de tu código existente permanece igual...
    final currentTopic = currentState['conversation_topic'] ?? '';
    final lastMentionedTreatment = currentState['last_mentioned_treatment'] ?? '';
    
    // Obtener contexto relevante considerando el tema actual
    Map<String, dynamic> knowledgeContext = {};
    String formattedContext = '';
    
    if (knowledgeBase != null) {
      try {
        // Extraer información del historial de conversación
        String conversationContext = _extractConversationContext(conversationHistory);
        debugPrint('🧠 Contexto conversacional: $conversationContext');
        
        // Si el usuario está preguntando sobre un tratamiento específico
        // mencionado anteriormente sin nombrarlo explícitamente
        if (lastMentionedTreatment.isNotEmpty && 
            _isFollowUpQuestion(userMessage) &&
            currentTopic == 'tratamientos') {
          // Forzar búsqueda sobre ese tratamiento
          knowledgeContext = await knowledgeBase!.getRelevantContext(
            lastMentionedTreatment + " " + userMessage,
            preferredType: 'treatments'
          );
          debugPrint('🔍 Búsqueda específica para tratamiento: $lastMentionedTreatment');
        } 
        // Si es una pregunta de seguimiento sobre precios de un tratamiento 
        // mencionado anteriormente
        else if (lastMentionedTreatment.isNotEmpty && 
                _isFollowUpQuestion(userMessage) && 
                (currentTopic == 'precios' || 
                _containsAny(userMessage.toLowerCase(), ['precio', 'costo', 'vale']))) {
          knowledgeContext = await knowledgeBase!.getRelevantContext(
            lastMentionedTreatment + " precio " + userMessage,
            preferredType: 'prices'
          );
          debugPrint('💰 Búsqueda específica para precio de: $lastMentionedTreatment');
        } else {
          // Búsqueda normal
          knowledgeContext = await knowledgeBase!.getRelevantContext(userMessage);
        }
        
        // Formatear el contexto para Claude
        formattedContext = knowledgeBase!.formatContextForPrompt(knowledgeContext);
        
        // Añadir explícitamente el contexto de la conversación si es necesario
        if (lastMentionedTreatment.isNotEmpty || conversationContext.isNotEmpty) {
          formattedContext += "\n\nCONTEXTO DE LA CONVERSACIÓN:";
          
          if (lastMentionedTreatment.isNotEmpty) {
            formattedContext += "\n- Tratamiento mencionado previamente: $lastMentionedTreatment";
          }
          
          if (conversationContext.isNotEmpty) {
            formattedContext += "\n- Mensajes recientes: $conversationContext";
          }
        }
        
        debugPrint('📝 Contexto formateado: ${formattedContext.length} caracteres');
      } catch (e) {
        debugPrint('⚠️ Error recuperando contexto: $e');
      }
    }
    
    // Crear systemPrompt mejorado para conversaciones fluidas
    String systemPrompt = _buildSystemPrompt(formattedContext, language);
    
    // Preparar mensajes para Claude incluyendo historial conversacional
    final List<Map<String, dynamic>> messages = [];
    
    // Añadir hasta 6 mensajes recientes para mantener el contexto
    final int historyLimit = 6;
    final startIdx = conversationHistory.length > historyLimit ? 
                    conversationHistory.length - historyLimit : 0;
    
    for (var i = startIdx; i < conversationHistory.length; i++) {
      messages.add({
        'role': conversationHistory[i].isUser ? 'user' : 'assistant',
        'content': conversationHistory[i].text
      });
    }
    
    // Añadir el mensaje actual del usuario
    messages.add({
      'role': 'user',
      'content': userMessage
    });
    
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'x-api-key': _getApiKey(),
          'anthropic-version': '2023-06-01'
        },
        body: utf8.encode(jsonEncode({  
          'model': model,
          'messages': messages,
          'system': systemPrompt,
          'temperature': temperature,
          'max_tokens': 500
        })),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedBody);
        final text = data['content'][0]['text']; 
        
        // Limpiar y verificar el idioma de la respuesta
        final cleanedText = _cleanResponse(text);
        final verifiedText = _verifyLanguage(cleanedText, language);
        
        debugPrint('✅ Respuesta de Claude procesada correctamente');
        return ProcessedMessage(
          text: verifiedText,
          additionalContext: formattedContext
        );
      } else {
        debugPrint('⚠️ Error en API Claude: ${response.statusCode}');
        throw Exception('Error conectando con Claude: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error procesando con Claude: $e');
      throw e;
    }
  }

  // Extraer información relevante del historial de conversación
  String _extractConversationContext(List<ChatMessage> history) {
    if (history.isEmpty || history.length < 2) return '';
    
    // Tomar solo los últimos 4 mensajes para el contexto
    final recentMessages = history.length > 4 ? history.sublist(history.length - 4) : history;
    
    // Formatear como un resumen conciso
    List<String> contextItems = [];
    for (int i = 0; i < recentMessages.length; i++) {
      final message = recentMessages[i];
      final prefix = message.isUser ? "Usuario preguntó" : "Asistente respondió";
      // Limitar la longitud de cada mensaje para que el contexto no sea demasiado largo
      final truncatedText = message.text.length > 50 ? 
                          '${message.text.substring(0, 50)}...' : message.text;
      contextItems.add('$prefix: "$truncatedText"');
    }
    
    return contextItems.join(' | ');
  }

  // Detectar si es una pregunta de seguimiento sin mencionar explícitamente el tema
  bool _isFollowUpQuestion(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Si es una pregunta muy corta, probablemente sea de seguimiento
    if (message.split(' ').length < 6) {
      
      // Patrones comunes en preguntas de seguimiento
      final followUpPatterns = [
        'cuánto', 'cuanto', 'precio', 'costo', 'vale', 
        'qué es', 'que es', 'cómo funciona', 'como funciona',
        'duración', 'duracion', 'más información', 'mas informacion',
        'me interesa', 'explica', 'dime más', 'dime mas',
        'y eso', 'cómo es', 'como es', 'efectos', 'tiempo', 'resultados',
        'por qué', 'para qué', 'qué hace', 'beneficios', 'ventajas',
        'riesgos', 'contraindicaciones', 'efectos secundarios',
        'duele', 'dolor', 'recuperación', 'después', 'tiempo',
        'funciona', 'resultados', 'cuánto dura', 'permanente'
      ];
      
      for (final pattern in followUpPatterns) {
        if (lowerMessage.contains(pattern)) {
          return true;
        }
      }
      
      // Preguntas implícitas muy cortas "¿Y eso duele?", "¿Es permanente?"
      if (message.split(' ').length < 4) {
        return true;
      }
    }
    
    return false;
  }

  // Construir un prompt mejorado para conversaciones fluidas
  String _buildSystemPrompt(String context, String language) {
    String basePrompt = '''Eres un asistente virtual de Clínicas Love, especializado en medicina estética.
    Actúas como una secretaria profesional, amable y conocedora de todos los servicios de la clínica.
    
    ADVERTENCIA CRÍTICA DE MÁXIMA IMPORTANCIA:
    - NUNCA, BAJO NINGUNA CIRCUNSTANCIA, INVENTES UBICACIONES DE CLÍNICAS
    - Cuando te pregunten por ubicaciones, SÓLO MENCIONA LAS DIRECCIONES EXACTAS que aparecen en el contexto proporcionado
    - NUNCA respondas con direcciones genéricas como "Calle Mayor 123" o "Avenida Principal"
    - Si no tienes las direcciones exactas en el contexto, di "Tenemos clínicas en [ciudades], pero necesito verificar las direcciones exactas"

    INSTRUCCIONES PARA CONVERSACIÓN FLUIDA Y NATURAL:
    - Mantén la COHERENCIA con los mensajes anteriores
    - Si el usuario hace una pregunta corta o ambigua, asume que se refiere al tema que se estaba discutiendo
    - Si anteriormente se mencionó un tratamiento específico y el usuario hace una pregunta genérica como "¿cuánto cuesta?", entiende que se refiere a ese tratamiento
    - Evita repetir toda la lista de servicios si el usuario está preguntando sobre uno específico
    - Adopta un estilo conversacional natural como lo haría una recepcionista real
    
    ADVERTENCIA CRÍTICA:
    - NUNCA INVENTES INFORMACIÓN QUE NO ESTÉ EN EL CONTEXTO PROPORCIONADO
    - Si no tienes la información específica solicitada, ADMITE QUE NO LA TIENES
    - NO INVENTES UBICACIONES, PRECIOS, SERVICIOS O CUALQUIER OTRO DATO
    
    INSTRUCCIÓN DE IDIOMA:
    - DEBES RESPONDER ÚNICAMENTE EN EL IDIOMA: $language
    - Si $language es 'ca', responde en catalán
    - Si $language es 'en', responde en inglés
    - Si $language es 'es', responde en español
    
    ESTILO DE RESPUESTA:
    - Respuestas BREVES Y CONCISAS (2-3 frases)
    - Tono AMABLE y PROFESIONAL
    - SIEMPRE basa tus respuestas en la información proporcionada
    ''';
    
    if (context.isNotEmpty) {
      basePrompt += '''\n\nINFORMACIÓN RELEVANTE PARA RESPONDER:
      $context
      
      RECUERDA: Usa SOLO la información proporcionada arriba. Si la información no está ahí, admite que no la tienes.''';
    }
    
    return basePrompt;
  }
  
  // Historial de conversación reciente para contexto
  List<Map<String, dynamic>> _getRecentConversationHistory(List<ChatMessage> history) {
    final List<Map<String, dynamic>> messages = [];
    int count = 0;
    
    for (final msg in history.reversed) {
      if (count >= 4) break;
      
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text
      });
      
      count++;
    }
    
    return messages.reversed.toList();
  }
  
  // Respuesta de respaldo simplificada
  ProcessedMessage _getFallbackResponse(
    String userMessage, 
    String formattedContext,
    String language
  ) {
    final lowerMessage = userMessage.toLowerCase();
    String responseText;
    
    // RESPUESTAS SEGÚN EL IDIOMA
    if (language == 'ca') {
      if (_containsAny(lowerMessage, ['preu', 'cost', 'quant', 'val', 'costa'])) {
        responseText = "Els preus a Clíniques Love varien segons el tractament específic. Si us plau, contacta directament amb la clínica per obtenir informació precisa sobre els preus.";
      } else if (_containsAny(lowerMessage, ['tractament', 'ofereixen', 'servei', 'fan', 'realitzen'])) {
        responseText = "A Clíniques Love oferim diversos tractaments estètics, incloent Botox, augment de llavis, rinomodelació, mesoteràpia, tractaments corporals reductors, peelings químics i tractaments de rejoveniment facial amb tecnologia làser.";
      } else if (_containsAny(lowerMessage, ['ubicació', 'on', 'adreça', 'seu', 'clínica'])) {
        responseText = "Clíniques Love té seus a Barcelona, Madrid, Màlaga i Tenerife. Per a informació més detallada sobre les adreces exactes, et recomanem contactar directament amb nosaltres.";
      } else {
        responseText = "A Clíniques Love ens especialitzem en medicina estètica facial i corporal amb els més alts estàndards. Oferim valoració personalitzada i tractaments adaptats a les teves necessitats estètiques.";
      }
    } else if (language == 'en') {
      if (_containsAny(lowerMessage, ['price', 'cost', 'how much', 'value', 'fee'])) {
        responseText = "Prices at Clínicas Love vary according to the specific treatment. Please contact the clinic directly for accurate price information.";
      } else if (_containsAny(lowerMessage, ['treatment', 'offer', 'service', 'do', 'perform'])) {
        responseText = "At Clínicas Love we offer various aesthetic treatments, including Botox, lip augmentation, rhinomodeling, mesotherapy, slimming body treatments, chemical peels, and facial rejuvenation treatments with laser technology.";
      } else if (_containsAny(lowerMessage, ['location', 'where', 'address', 'office', 'clinic'])) {
        responseText = "Clínicas Love has locations in Barcelona, Madrid, Malaga, and Tenerife. For more detailed information about the exact addresses, we recommend contacting us directly.";
      } else {
        responseText = "At Clínicas Love we specialize in facial and body aesthetic medicine with the highest standards. We offer personalized assessment and treatments tailored to your aesthetic needs.";
      }
    } else {
      // Español por defecto
      if (_containsAny(lowerMessage, ['precio', 'costo', 'cuánto', 'vale', 'cuesta'])) {
        responseText = "Los precios en Clínicas Love varían según el tratamiento específico. Por favor, contacta directamente con la clínica para obtener información precisa sobre los precios.";
      } else if (_containsAny(lowerMessage, ['tratamiento', 'ofrecen', 'servicio', 'hacen', 'realizan'])) {
        responseText = "En Clínicas Love ofrecemos diversos tratamientos estéticos, incluyendo Botox, aumento de labios, rinomodelación, mesoterapia, tratamientos corporales reductores, peelings químicos y tratamientos de rejuvenecimiento facial con tecnología láser.";
      } else if (_containsAny(lowerMessage, ['ubicación', 'dónde', 'dirección', 'sede', 'clínica'])) {
        responseText = "Clínicas Love tiene sedes en Barcelona, Madrid, Málaga y Tenerife. Para información más detallada sobre las direcciones exactas, te recomendamos contactar directamente con nosotros.";
      } else {
        responseText = "En Clínicas Love nos especializamos en medicina estética facial y corporal con los más altos estándares. Ofrecemos valoración personalizada y tratamientos adaptados a tus necesidades estéticas.";
      }
    }

    return ProcessedMessage(
      text: responseText,
      additionalContext: formattedContext
    );
  }

  // Mantener el resto de funciones de utilidad
  String _cleanResponse(String text) {
    // Código existente para limpiar la respuesta
    final Map<String, String> characterFixes = {
      // Todos tus mapeos existentes
    };
    
    characterFixes.forEach((badChar, goodChar) {
      text = text.replaceAll(badChar, goodChar);
    });
    
    text = text.replaceAll('ommm', '')
              .replaceAll('ommmm', '')
              .replaceAll('Ommm', '')
              .replaceAll('Ommmm', '');
    
    text = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    return text;
  }
  
  String _verifyLanguage(String response, String expectedLanguage) {
    // Tu código existente para verificar el idioma
    return response;
  }
  
  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}