import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Las claves se leen del archivo .env (ver .env.example), nunca del código.
  static final String openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  // Configuración de entorno
  static final bool isProduction = false; // Cambiar a true para producción

  // Opciones de servicios
  static final bool useAITestMode = false; // Cambiar a true para usar respuestas simuladas
}
