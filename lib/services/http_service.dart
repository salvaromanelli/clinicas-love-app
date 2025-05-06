import 'package:http/http.dart' as http;
import '../utils/auth_interceptor.dart';
import '../services/auth_service.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  late final http.Client client;
  
  factory HttpService() {
    return _instance;
  }
  
  HttpService._internal() {
    // Inicializar el cliente HTTP con el interceptor
    client = AuthInterceptor(http.Client(), AuthService());
  }
  
  // Método para inicializar explícitamente si es necesario
  static initialize() {
    HttpService();
  }
}

// Cliente HTTP global con autenticación
final httpClient = HttpService().client;