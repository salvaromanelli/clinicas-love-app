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

  bool _isPriceQuestion(String text, Map<String, dynamic> knowledgeContext) {
  final lowerText = text.toLowerCase();
  
  // Verificar si la pregunta es sobre precios
  final isPriceRelated = _containsAny(lowerText, [
    'precio', 'cuesta', 'cuánto', 'cuanto', 'valor', 'tarifa',
    'price', 'cost', 'how much', 'preu', 'cost'
  ]);
  
  // Verificar si tenemos información de precios en el contexto
  final hasPrice = knowledgeContext.containsKey('prices') && 
                  knowledgeContext['prices'] != null &&
                  knowledgeContext['prices'].isNotEmpty;
  
  return isPriceRelated || hasPrice;
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
      [](app://clinicas)""";
      
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
      [](app://clinicas)""";
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
      [](app://clinicas)""";
    }

    debugPrint('✅ Respuesta de ubicación HARDCODED generada');
    return ProcessedMessage(
      text: responseText,
      additionalContext: "show_clinic_button"
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
    
    // Obtener contexto relevante de la base de conocimiento
    Map<String, dynamic> knowledgeContext = {};
    String formattedContext = '';
    
    if (knowledgeBase != null) {
      try {
        // Búsqueda normal en la base de conocimientos
        knowledgeContext = await knowledgeBase!.getRelevantContext(userMessage);
        formattedContext = knowledgeBase!.formatContextForPrompt(knowledgeContext);
        debugPrint('📝 Contexto formateado: ${formattedContext.length} caracteres');
             
        if (knowledgeContext.containsKey('prices')) {
        debugPrint('💰 Información de precios encontrada: ${knowledgeContext['prices']}');
      }
      } catch (e) {
        debugPrint('⚠️ Error recuperando contexto: $e');
      }
    }

    final isPriceQuestion = _isPriceQuestion(userMessage, knowledgeContext);
    
    // Sistema prompt simplificado
    String systemPrompt = '''Eres un asistente virtual de Clínicas Love, especializado en medicina estética.
    Actúas como una secretaria profesional, amable y conocedora de todos los servicios de la clínica.
    
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
    ''';
    
    if (isPriceQuestion) {
    systemPrompt += '''
    
    INSTRUCCIONES ESPECÍFICAS SOBRE PRECIOS:
    - SOLO menciona precios de tratamientos si están EXPLÍCITAMENTE proporcionados en el contexto
    - Si se te pregunta sobre el precio de un tratamiento y NO tienes el dato exacto, di algo como: 
      "Para darte el precio exacto de este tratamiento, te recomiendo contactar directamente con la clínica 
      o reservar una consulta de valoración gratuita donde podrán darte un presupuesto personalizado."
    - NUNCA estimes, aproximes o inventes un rango de precios si no tienes el dato exacto
    - Si el contexto proporciona un precio específico, úsalo exactamente como aparece, sin redondearlo ni modificarlo
    ''';
  }

    if (formattedContext.isNotEmpty) {
      systemPrompt += '''\n\nINFORMACIÓN RELEVANTE PARA RESPONDER:
      $formattedContext
      
      RECUERDA: Usa SOLO la información proporcionada arriba. Si la información no está ahí, admite que no la tienes.''';
    }
    
    // Preparar mensajes para Claude
    final List<Map<String, dynamic>> messages = [];
    
    // Añadir hasta 4 mensajes recientes para mantener contexto mínimo
    final historyLimit = 4;
    final startIdx = conversationHistory.length > historyLimit ? 
                    conversationHistory.length - historyLimit : 0;
    
    for (var i = startIdx; i < conversationHistory.length; i++) {
      messages.add({
        'role': conversationHistory[i].isUser ? 'user' : 'assistant',
        'content': conversationHistory[i].text
      });
    }
    
    // Añadir el mensaje actual
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
        final validatedPriceText = _validatePriceInformation(verifiedText, knowledgeContext);
        
        debugPrint('✅ Respuesta de Claude procesada correctamente');
        return ProcessedMessage(
          text: validatedPriceText,
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

    String _validatePriceInformation(String response, Map<String, dynamic> knowledgeContext) {
    if (!knowledgeContext.containsKey('prices') || knowledgeContext['prices'] == null) {
      return response;
    }
    
    // Verificar si la respuesta contiene información de precios inventada
    RegExp pricePattern = RegExp(r'(\d+[.,]?\d*)\s*[€$£]');
    var matches = pricePattern.allMatches(response);
    
    if (matches.isEmpty) {
      return response; // No hay precios mencionados
    }
    
    // Verificar cada precio mencionado contra nuestros datos
    List<Map<String, dynamic>> prices = knowledgeContext['prices'];
    Set<String> validPrices = prices.map((p) => p['price'].toString()).toSet();
    
    for (var match in matches) {
      String mentionedPrice = match.group(1)!;
      bool isValid = validPrices.contains(mentionedPrice);
      
      if (!isValid) {
        // Si detectamos un precio inventado, añadimos una nota para aclarar
        response += "\n\n[NOTA INTERNA: Para obtener el precio exacto de este tratamiento, por favor contacta directamente con la clínica o reserva una consulta de valoración gratuita.]";
        break;
      }
    }
    
    return response;
  }
  
  Future<Map<String, dynamic>> getJsonResponse(String prompt) async {
    try {
      // Enviar el prompt a la API de Claude
      final response = await processMessage(
        prompt,
        [],  // Historial de mensajes vacío para una consulta directa
        {}   // No se necesita contexto adicional
      );
      
      // Intentar analizar el texto de respuesta como JSON
      try {
        // Eliminar marcadores de bloque de código markdown si están presentes
        String jsonText = response.text;
        if (jsonText.contains('```json')) {
          jsonText = jsonText.split('```json')[1].split('```')[0].trim();
        } else if (jsonText.contains('```')) {
          jsonText = jsonText.split('```')[1].split('```')[0].trim();
        }
        
        // Analizar el JSON
        final jsonResponse = json.decode(jsonText);
        return jsonResponse;
      } catch (parseError) {
        debugPrint('⚠️ Error al analizar JSON de la respuesta de Claude: $parseError');
        debugPrint('📝 La respuesta sin procesar fue: ${response.text}');
        
        // Devolver un JSON de error por defecto si falla el análisis
        return {
          'isTreatmentQuery': false,
          'matchedTreatment': null,
          'isComboTreatment': false,
          'components': [],
          'error': 'No se pudo analizar JSON de la respuesta de IA'
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error al obtener respuesta JSON de Claude: $e');
      
      // Devolver un JSON de error por defecto si falla la llamada a la API
      return {
        'isTreatmentQuery': false,
        'matchedTreatment': null,
        'isComboTreatment': false,
        'components': [],
        'error': 'Error de API: $e'
      };
    }
  }

}