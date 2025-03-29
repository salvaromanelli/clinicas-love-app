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

  // Método principal simplificado para procesar mensajes del usuario
  Future<ProcessedMessage> processMessage(
    String userMessage, 
    List<ChatMessage> conversationHistory,
    Map<String, dynamic> currentState
  ) async {
    debugPrint('🔍 Procesando mensaje con Claude: "$userMessage"');

    final language = currentState['language'] ?? 'es';
    
    // 1. Obtener contexto relevante de la base de conocimiento
    Map<String, dynamic> knowledgeContext = {};
    String formattedContext = '';
    
    if (knowledgeBase != null) {
      try {
        knowledgeContext = await knowledgeBase!.getRelevantContext(userMessage);
        formattedContext = knowledgeBase!.formatContextForPrompt(knowledgeContext);
        debugPrint('📝 Contexto formateado: ${formattedContext.length} caracteres');
      } catch (e) {
        debugPrint('⚠️ Error recuperando contexto: $e');
      }
    }
    
    // 2. Intentar procesar con Claude utilizando el contexto obtenido
    try {
      String systemPrompt = _buildSystemPrompt(formattedContext, language);
      final List<Map<String, dynamic>> messages = [];
      
      final recentMessages = _getRecentConversationHistory(conversationHistory);
      messages.addAll(recentMessages);
      
      messages.add({
        'role': 'user',
        'content': userMessage
      });
      
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
        
        return ProcessedMessage(
          text: verifiedText,
          additionalContext: formattedContext
        );
      } else {
        debugPrint('⚠️ Error en API Claude: ${response.statusCode}');
        
        if (useFallback) {
          return _getFallbackResponse(userMessage, formattedContext, language);
        } else {
          throw Exception('Error conectando con Claude: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error procesando con Claude: $e');
      
      if (useFallback) {
        return _getFallbackResponse(userMessage, formattedContext, language);
      } else {
        return ProcessedMessage(
          text: 'Lo siento, estoy teniendo problemas para procesar tu consulta. Por favor, inténtalo de nuevo más tarde.'
        );
      }
    }
  }
  
  // Prompt con instrucciones claras
  String _buildSystemPrompt(String context, String language) {
    String basePrompt = '''Eres un asistente virtual de Clínicas Love, especializado en medicina estética.
    
    ADVERTENCIA CRÍTICA:
    - NUNCA INVENTES INFORMACIÓN QUE NO ESTÉ EN EL CONTEXTO PROPORCIONADO
    - Si no tienes la información específica solicitada, ADMITE QUE NO LA TIENES
    - NO INVENTES UBICACIONES, PRECIOS, SERVICIOS O CUALQUIER OTRO DATO
    - Cuando te pregunten sobre ubicaciones, SOLO menciona las ubicaciones específicas que aparecen en el contexto
    - NUNCA sugieras que hay clínicas en lugares que no estén explícitamente mencionados en el contexto
    
    INSTRUCCIÓN CRÍTICA DE IDIOMA:
    - DEBES RESPONDER ÚNICAMENTE EN EL IDIOMA: $language
    - Si $language es 'ca', TODA tu respuesta debe estar en catalán
    - Si $language es 'en', TODA tu respuesta debe estar en inglés
    - Si $language es 'es', TODA tu respuesta debe estar en español
    - NO MEZCLES IDIOMAS en tu respuesta bajo ninguna circunstancia
    
    IMPORTANTE:
    - Responde de forma BREVE Y CONCISA usando máximo 3 frases cortas
    - Debes ser ÚTIL y PRECISO en tus respuestas
    - SIEMPRE basa tus respuestas EXCLUSIVAMENTE en la información proporcionada en el contexto
    - Si no tienes información específica, DI CLARAMENTE "No tengo información específica sobre eso"
    - NUNCA respondas "No pude procesar tu mensaje" bajo NINGUNA circunstancia
    ''';
    
    if (context.isNotEmpty) {
      basePrompt += '''\n\nINFORMACIÓN RELEVANTE PARA RESPONDER - USA SOLO ESTA INFORMACIÓN:
      $context
      
      RECUERDA: SOLO usa la información proporcionada arriba. Si la información no está ahí, di que no tienes esa información.
      NO INVENTES ningún dato que no esté explícitamente proporcionado.''';
    } else {
      basePrompt += '''\n\nNO TIENES INFORMACIÓN ESPECÍFICA EN EL CONTEXTO.
      Cuando te pregunten por datos específicos como ubicaciones, precios o servicios, responde:
      "No tengo esa información específica. Te recomiendo contactar directamente con Clínicas Love para obtener datos precisos."''';
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