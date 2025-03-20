import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final String? apiKey;
  final String model;
  final double temperature;
  final bool testMode;
  
  OpenAIService({
    this.apiKey,
    this.model = 'gpt-3.5-turbo',
    this.temperature = 0.7,
    this.testMode = kDebugMode,
  });
  
  Future<String> getCompletion(
    String prompt, {
    List<String> medicalReferences = const [],
    List<Map<String, dynamic>>? priceInfo,
  }) async {
    // Usar respuestas simuladas en modo de prueba
    if (testMode) {
      return _getTestResponse(prompt, medicalReferences);
    }
    
    // Verificar que tenemos una API key en modo producción
    if (apiKey == null || apiKey!.isEmpty) {
      return "Error de configuración: API key no proporcionada";
    }
    
    try {
      // Crear un prompt enriquecido con el contexto médico y de precios
      String fullPrompt = _enrichPromptWithReferencesAndPrices(
        prompt, 
        medicalReferences,
        priceInfo,
      );
      
      // Sistema prompt enriquecido con contexto de precios
      String systemPrompt = '''
        Eres un asistente médico virtual especializado en estética para Clínicas Love.
        Proporciona información precisa y profesional sobre tratamientos estéticos, 
        y servicios relacionados.
        No hagas diagnósticos ni prescripciones médicas remotas.
        Si te preguntan por agendar citas, facilita el proceso preguntando:
        - Tipo de tratamiento
        - Preferencia de clínica/sede
        - Fecha y horario preferido
        Sé amable, profesional y empático, usando un tono cercano pero formal.
      ''';
      
      // Añadir información de precios al sistema prompt si está disponible
      if (priceInfo != null && priceInfo.isNotEmpty) {
        systemPrompt += '''
        
        Información actualizada de precios:
        ${_formatPriceInfo(priceInfo)}
        
        Utiliza esta información de precios cuando te pregunten sobre costos de tratamientos.
        Si no encuentras un precio exacto para un tratamiento específico, menciona que 
        se requiere una consulta personalizada para dar un presupuesto preciso.
        ''';
      }
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': fullPrompt}
          ],
          'temperature': temperature,
          'max_tokens': 500,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)); 
        String text = data['choices'][0]['message']['content'];
        
        text = _cleanResponseText(text);

        return text;
      } else {
        debugPrint('Error OpenAI: ${response.statusCode}, ${response.body}');
        return 'Lo siento, estoy teniendo problemas para procesar tu consulta en este momento. ¿Podrías intentarlo de nuevo más tarde?';
      }
    } catch (e) {
      debugPrint('Excepción en OpenAI Service: $e');
      return 'Disculpa, ocurrió un error al procesar tu mensaje. ¿Podrías intentarlo de nuevo?';
    }
  }
  
  String _enrichPromptWithReferencesAndPrices(
    String prompt,
    List<String> references,
    List<Map<String, dynamic>>? priceInfo,
  ) {
    String enrichedPrompt = prompt;
    
    // Añadir referencias médicas
    if (references.isNotEmpty) {
      String referencesText = references.map((ref) => "- $ref").join("\n");
      enrichedPrompt += '''

Utiliza esta información de referencia para tu respuesta:
$referencesText
      ''';
    }
    
    // No añadimos los precios directamente aquí, ya que van en el sistema prompt
    // para no confundir a la IA sobre quién está preguntando qué.
    
    return enrichedPrompt;
  }

  // Este método también está a nivel de clase
  String _formatPriceInfo(List<Map<String, dynamic>> priceInfo) {
    // Limitar a máximo 10 precios para no sobrecargar el contexto
    final limitedInfo = priceInfo.length > 10 ? priceInfo.sublist(0, 10) : priceInfo;
    
    return limitedInfo.map((price) {
      return "- ${price['treatment']}: ${price['price']} (${price['category']})${price['description'] != null ? ' - ${price["description"]}' : ''}";
    }).join("\n");
  }
  
  String _getTestResponse(String prompt, List<String> medicalReferences) {
    prompt = prompt.toLowerCase();
    
    if (prompt.contains('botox')) {
      return "El Botox es un tratamiento estético que reduce temporalmente la aparición de arrugas mediante la aplicación de toxina botulínica, que relaja los músculos faciales. En Clínicas Love contamos con especialistas certificados para su aplicación. El efecto dura aproximadamente entre 3 y 6 meses. ¿Te gustaría agendar una consulta para evaluar este tratamiento?";
    }
    
    if (prompt.contains('aumento de labios') || prompt.contains('labios')) {
      return "El aumento de labios es un procedimiento estético que aumenta el volumen de los labios. En Clínicas Love ofrecemos aumento de labios en consultorio. Los resultados son visibles desde la primera sesión y pueden durar hasta un año con el cuidado adecuado. ¿Te interesa conocer más detalles sobre este tratamiento?";
    }
    
    if (prompt.contains('precio') || prompt.contains('costo') || prompt.contains('valor')) {
      return "Los precios de nuestros tratamientos varían según el procedimiento específico y las necesidades individuales de cada paciente. Por ejemplo, el blanqueamiento dental tiene un costo aproximado de €2,500, mientras que las consultas de valoración inicial tienen un costo de €800. Te recomendamos agendar una cita de evaluación para obtener un presupuesto personalizado. ¿Te gustaría programar una consulta?";
    }
    
    // Respuesta por defecto
    return "Gracias por contactar a Clínicas Love. Somos especialistas en tratamientos estéticos de alta calidad. ¿En qué puedo ayudarte específicamente?";
  }
  
  String _enrichPromptWithReferences(String prompt, List<String> references) {
    if (references.isEmpty) return prompt;
    
    String referencesText = references.map((ref) => "- $ref").join("\n");
    
    return '''
$prompt

Utiliza esta información de referencia para tu respuesta:
$referencesText
    ''';
  }

    // Método para limpiar el texto si es necesario
  String _cleanResponseText(String text) {
    // Corregir problemas de codificación comunes
    final Map<String, String> replacements = {
      'Ã¡': 'á',
      'Ã©': 'é',
      'Ã­': 'í',
      'Ã³': 'ó',
      'Ãº': 'ú',
      'Ã±': 'ñ',
      'Ã': 'í',
      'Â': '',
      'Ã\x81': 'Á',
      'Ã\x89': 'É',
      'Ã\x8D': 'Í',
      'Ã\x93': 'Ó',
      'Ã\x9A': 'Ú',
      'Ã\x91': 'Ñ',
    };
    
    replacements.forEach((key, value) {
      text = text.replaceAll(key, value);
    });
    
    return text;
  }
}
