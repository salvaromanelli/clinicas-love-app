import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/services/knowledge_base.dart';
import '/virtual_assistant_chat.dart' hide AppointmentInfo;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ClaudeAssistantService {
  final String? apiKey;
  final String model;
  final double temperature;
  final bool useFallback; // Indica si usar respuestas predefinidas cuando Claude falla
  final KnowledgeBase? knowledgeBase;
  
  ClaudeAssistantService({
    this.apiKey,
    this.model = 'claude-3-haiku-20240307', 
    this.temperature = 0.7,
    this.useFallback = true, // Por defecto, usar respuestas predefinidas como respaldo
    this.knowledgeBase,
  });

  // Obtener API key de Claude desde .env
  String _getApiKey() {
    return apiKey ?? dotenv.env['CLAUDE_API_KEY'] ?? '';
  }

  // Método principal para procesar mensajes del usuario
  Future<ProcessedMessage> processMessage(
    String userMessage, 
    List<ChatMessage> conversationHistory,
    Map<String, dynamic> currentState
  ) async {
    debugPrint('🔍 Procesando mensaje con Claude: "$userMessage"');
    
    // 1. Obtener contexto relevante de la base de conocimiento
    Map<String, dynamic> knowledgeContext = {};
    String formattedContext = '';
    
    if (knowledgeBase != null) {
      try {
        // Obtener información relevante para la consulta
        knowledgeContext = await knowledgeBase!.getRelevantContext(userMessage);
        
        // Logging de la información recuperada
        if (knowledgeContext.containsKey('web_references')) {
          debugPrint('📚 Encontradas ${knowledgeContext['web_references']?.length ?? 0} referencias web');
        }
        if (knowledgeContext.containsKey('prices')) {
          debugPrint('💰 Encontrados ${knowledgeContext['prices']?.length ?? 0} precios');
        }
        if (knowledgeContext.containsKey('treatments')) {
          debugPrint('💉 Encontrados ${knowledgeContext['treatments']?.length ?? 0} tratamientos');
        }
        
        // Formatear el contexto para la IA
        formattedContext = knowledgeBase!.formatContextForPrompt(knowledgeContext);
        debugPrint('📝 Contexto formateado: ${formattedContext.length} caracteres');
      } catch (e) {
        debugPrint('⚠️ Error recuperando contexto: $e');
        // Continuar con formattedContext vacío
      }
    }
    
    // 2. Intentar procesar con Claude utilizando el contexto obtenido
    try {
      // Extraer el mensaje del sistema que estabas colocando como un mensaje con rol "system"
      String systemPrompt = _buildSystemPrompt(formattedContext);
      
      // Construir mensajes para Claude (solo user y assistant, sin system)
      final List<Map<String, dynamic>> messages = [];
      
      // Añadir historial de conversación limitado (últimos 2-3 intercambios)
      final recentMessages = _getRecentConversationHistory(conversationHistory);
      messages.addAll(recentMessages);
      
      // Añadir consulta actual
      messages.add({
        'role': 'user',
        'content': userMessage
      });
      
      // Hacer la llamada a Claude con el formato correcto
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _getApiKey(), // Header correcto para Claude
          'anthropic-version': '2023-06-01'
        },
        body: utf8.encode(jsonEncode({  
          'model': model,
          'messages': messages,
          'system': systemPrompt, // La API de Claude espera "system" como parámetro de nivel superior
          'temperature': temperature,
          'max_tokens': 500
        })),
      ).timeout(const Duration(seconds: 10));  // Timeout corto para experiencia de usuario fluida
      
      // Procesar respuesta de Claude
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['content'][0]['text'];
        
        // Detectar intención de reserva
        final isBookingIntent = _detectBookingIntent(text, userMessage);
        final bookingInfo = isBookingIntent ? _extractBookingInfo(text, userMessage) : null;
        
        // Devolver respuesta procesada
        return ProcessedMessage(
          text: _cleanResponse(text),
          isBookingIntent: isBookingIntent,
          bookingInfo: bookingInfo,
          additionalContext: formattedContext
        );
      } else {
        debugPrint('⚠️ Error en API Claude: ${response.statusCode}');
        debugPrint('Detalles: ${response.body}');
        
        // Si hay error y tenemos habilitado el fallback, usar respuestas predefinidas
        if (useFallback) {
          return _getFallbackResponse(userMessage, formattedContext, knowledgeContext);
        } else {
          throw Exception('Error conectando con Claude: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error procesando con Claude: $e');
      
      // Usar respuestas predefinidas si está habilitado
      if (useFallback) {
        return _getFallbackResponse(userMessage, formattedContext, knowledgeContext);
      } else {
        return ProcessedMessage(
          text: 'Lo siento, estoy teniendo problemas para procesar tu consulta. Por favor, inténtalo de nuevo más tarde.',
          isBookingIntent: false,
          bookingInfo: null
        );
      }
    }
  }
  
  // Construir prompt de sistema con contexto
  String _buildSystemPrompt(String context) {
    String basePrompt = '''Eres un asistente virtual de Clínicas Love, especializado en medicina estética.
    
    IMPORTANTE:
    - Responde de forma BREVE Y CONCISA usando máximo 3 frases cortas
    - Debes ser ÚTIL y PRECISO en tus respuestas
    - SIEMPRE basa tus respuestas en la información proporcionada en el contexto
    - NO inventes precios o datos específicos si no están en la información proporcionada
    - Si no tienes información específica, di que no tienes esa información exacta y sugiere contactar directamente
    - NUNCA respondas "No pude procesar tu mensaje" bajo NINGUNA circunstancia
    - NO uses expresiones como "ommm" o cualquier onomatopeya al final de tus respuestas
    ''';
    
    // Añadir contexto si existe
    if (context.isNotEmpty) {
      basePrompt += '''\n\nINFORMACIÓN RELEVANTE PARA RESPONDER:
      $context
      
      Utiliza esta información para responder de manera precisa y detallada.
      No menciones que te he proporcionado esta información, simplemente úsala
      como parte de tu conocimiento.''';
    }
    
    return basePrompt;
  }
  
  // Obtener historial de conversación reciente
  List<Map<String, dynamic>> _getRecentConversationHistory(List<ChatMessage> history) {
    final List<Map<String, dynamic>> messages = [];
    int count = 0;
    
    // Filtrar solo mensajes que sean del usuario o asistente (no system)
    for (final msg in history.reversed) {
      if (count >= 4) break;
      
      // Solo incluir mensajes de tipo user o assistant
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text
      });
      
      count++;
    }
    
    // Devolver en orden cronológico
    return messages.reversed.toList();
  }
  
  // Detectar si el mensaje indica intención de reservar una cita
  bool _detectBookingIntent(String assistantResponse, String userMessage) {
    final lowerResponse = assistantResponse.toLowerCase();
    final lowerQuery = userMessage.toLowerCase();
    
    // Palabras clave para detectar intención de reserva
    final bookingKeywords = [
      'cita', 'agendar', 'reservar', 'programar', 'consulta',
      'disponibilidad', 'horario', 'cuándo puedo ir'
    ];
    
    // Si la respuesta sugiere agendar o el usuario lo pidió explícitamente
    for (final keyword in bookingKeywords) {
      if (lowerResponse.contains(keyword) || lowerQuery.contains(keyword)) {
        return true;
      }
    }
    
    return false;
  }
  
  // Extraer información para la reserva, si existe
  Map<String, dynamic>? _extractBookingInfo(String text, String userMessage) {
    final Map<String, dynamic> info = {
      'intent_type': 'booking',
      'treatment': null,
      'clinic': null,
    };
    
    // Tratamientos comunes para detectar
    final treatmentMappings = {
      'botox': 'Botox',
      'toxina': 'Botox',
      'labio': 'Aumento de labios',
      'relleno de labio': 'Aumento de labios',
      'rino': 'Rinomodelación',
      'nariz': 'Rinomodelación',
      'meso': 'Mesoterapia',
      'facial': 'Tratamiento facial',
      'láser': 'Tratamiento láser',
      'peeling': 'Peeling químico',
    };
    
    // Buscar tratamiento mencionado
    final lowerMessage = userMessage.toLowerCase();
    for (var term in treatmentMappings.keys) {
      if (lowerMessage.contains(term)) {
        info['treatment'] = treatmentMappings[term];
        break;
      }
    }
    
    // Detectar clínica (si se menciona)
    if (lowerMessage.contains('serrano')) {
      info['clinic'] = 'Serrano';
    } else if (lowerMessage.contains('américa')) {
      info['clinic'] = 'Avenida de América';
    }
    
    return info;
  }
  
  // Limpiar respuesta de expresiones no deseadas
    String _cleanResponse(String text) {
    // Mapeo de caracteres mal codificados a sus versiones correctas
    final Map<String, String> characterFixes = {
      'Ã¡': 'á',
      'Ã©': 'é',
      'Ã­': 'í',
      'Ã³': 'ó',
      'Ãº': 'ú',
      'Ã±': 'ñ',
      'Ã\x81': 'Á',
      'Ã\x89': 'É',
      'Ã\x8D': 'Í',
      'Ã\x93': 'Ó',
      'Ã\x9A': 'Ú',
      'Ã\x91': 'Ñ',
      'Â': '',  // Carácter basura común
      '@': 'é', // Otro reemplazo común
      'lÃ¡': 'lá',
      'lÃ©': 'lé',
      'lÃ­': 'lí',
      'lÃ³': 'ló',
      'lÃº': 'lú',
      'estA@ticos': 'estéticos',
      'mÃis': 'más',
      'botulÂnica': 'botulínica',
      'lÃjser': 'láser',
      'pÃigina': 'página',
      'especÃficos': 'específicos',
    };
    
    // Aplicar todas las correcciones de caracteres
    characterFixes.forEach((badChar, goodChar) {
      text = text.replaceAll(badChar, goodChar);
    });
    
    // Eliminar expresiones no deseadas
    text = text.replaceAll('ommm', '')
              .replaceAll('ommmm', '')
              .replaceAll('Ommm', '')
              .replaceAll('Ommmm', '');
    
    // Eliminar espacios adicionales
    text = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    return text;
  }
  
  // Generar respuesta alternativa basada en contenido local cuando Claude falla
  ProcessedMessage _getFallbackResponse(
    String userMessage, 
    String formattedContext, 
    Map<String, dynamic> knowledgeContext
  ) {
    final lowerMessage = userMessage.toLowerCase();
    String responseText;
    bool isBookingIntent = false;
    Map<String, dynamic>? bookingInfo;
    
    // RESPUESTAS PARA PRECIOS
    if (_containsAny(lowerMessage, ['precio', 'costo', 'cuánto', 'vale', 'cuesta'])) {
      // Intentar usar precios del knowledge base primero
      if (knowledgeContext.containsKey('prices') && knowledgeContext['prices'].isNotEmpty) {
        final prices = knowledgeContext['prices'];
        
        // Buscar precio específico por tratamiento
        if (_containsAny(lowerMessage, ['botox', 'toxina'])) {
          responseText = "El tratamiento de Botox en Clínicas Love tiene un precio entre 250€ y 350€, dependiendo de las zonas a tratar. Incluye valoración médica previa y seguimiento posterior.";
        }
        else if (_containsAny(lowerMessage, ['labio', 'relleno labial'])) {
          responseText = "El aumento de labios con ácido hialurónico en Clínicas Love tiene un precio entre 300€ y 350€, dependiendo del producto y la cantidad. Los resultados son inmediatos y duran entre 6-12 meses.";
        }
        else if (_containsAny(lowerMessage, ['rino', 'nariz'])) {
          responseText = "La rinomodelación sin cirugía en Clínicas Love tiene un precio desde 400€. Es un tratamiento con ácido hialurónico que corrige imperfecciones nasales sin necesidad de quirófano.";
        }
        else {
          responseText = "Los precios en Clínicas Love varían según el tratamiento. Tenemos opciones desde 80€ para tratamientos básicos hasta 500€ para procedimientos más complejos. ¿Sobre qué tratamiento específico te gustaría conocer el precio?";
        }
      } else {
        // Respuesta genérica si no hay información específica
        responseText = "Los precios en Clínicas Love varían según el tratamiento específico. Por favor, indícame qué tratamiento te interesa para darte información más precisa sobre su precio.";
      }
    }
    
    // RESPUESTAS PARA TRATAMIENTOS
    else if (_containsAny(lowerMessage, ['tratamiento', 'ofrecen', 'servicio', 'hacen', 'realizan'])) {
      responseText = "En Clínicas Love ofrecemos diversos tratamientos estéticos, incluyendo Botox, aumento de labios, rinomodelación, mesoterapia, tratamientos corporales reductores, peelings químicos y tratamientos de rejuvenecimiento facial con tecnología láser. ¿Te gustaría información sobre alguno en particular?";
    }
    
    // RESPUESTAS PARA CITAS
    else if (_containsAny(lowerMessage, ['cita', 'reserva', 'horario', 'agenda', 'disponible'])) {
      responseText = "Para agendar una cita en Clínicas Love, necesitaría saber qué tratamiento te interesa, tu preferencia de sede y el horario que te vendría mejor. ¿Podrías proporcionarme esta información?";
      isBookingIntent = true;
      bookingInfo = {
        'intent_type': 'booking',
        'treatment': null,
        'clinic': null
      };
    }
    
    // RESPUESTAS PARA UBICACIONES
    else if (_containsAny(lowerMessage, ['ubicación', 'dónde', 'dirección', 'sede', 'clínica'])) {
      responseText = "Contamos con dos sedes en Madrid: nuestra clínica principal en Calle Serrano 45 (L-V de 9:00 a 20:00), y nuestra segunda sede en Avenida de América 28 (L-V de 10:00 a 19:00). Ambas ofrecen todos nuestros tratamientos estéticos.";
    }
    
    // RESPUESTA GENÉRICA
    else {
      responseText = "En Clínicas Love nos especializamos en medicina estética facial y corporal con los más altos estándares. Ofrecemos valoración personalizada y tratamientos adaptados a tus necesidades estéticas. ¿En qué podemos ayudarte hoy?";
    }
    
    // Devolver respuesta procesada
    return ProcessedMessage(
      text: responseText,
      isBookingIntent: isBookingIntent,
      bookingInfo: bookingInfo,
      additionalContext: formattedContext
    );
  }
  
  // Función auxiliar para verificar si un texto contiene cualquiera de las palabras clave
  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}

// Clase para manejar las respuestas procesadas
class ProcessedMessage {
  final String text;
  final bool isBookingIntent;
  final Map<String, dynamic>? bookingInfo;
  final String? additionalContext;
  
  ProcessedMessage({
    required this.text,
    required this.isBookingIntent,
    this.bookingInfo,
    this.additionalContext,
  });

}