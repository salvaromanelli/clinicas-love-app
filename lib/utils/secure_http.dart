import 'package:http/http.dart' as http;

// Función para crear un cliente HTTP que solo permita HTTPS
http.Client createSecureHttpClient() {
  return _SecureHttpClient();
}

class _SecureHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Verificar que todas las solicitudes usen HTTPS
    if (!request.url.toString().startsWith('https://')) {
      throw Exception('Solo se permiten solicitudes HTTPS: ${request.url}');
    }
    return _inner.send(request);
  }
  
  @override
  void close() {
    _inner.close();
  }
}