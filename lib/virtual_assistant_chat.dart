import 'package:flutter/material.dart';
import 'booking_page.dart';

class VirtualAssistantChat extends StatefulWidget {
  const VirtualAssistantChat({super.key});

  @override
  State<VirtualAssistantChat> createState() => _VirtualAssistantChatState();
}

class _VirtualAssistantChatState extends State<VirtualAssistantChat> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente Virtual'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      // Añadir resizeToAvoidBottomInset para manejar el teclado
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        // Usa SafeArea para evitar problemas con notch/barra de navegación
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _buildWelcomeMessage()
                  : ListView.builder(
                      controller: _scrollController, // Usar el controlador de desplazamiento
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _messages[index];
                      },
                    ),
            ),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 8),
                    Text("Asistente está escribiendo..."),
                  ],
                ),
              ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }



  Widget _buildWelcomeMessage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "¡Hola! Soy el asistente virtual de Clínicas Love",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "¿En qué puedo ayudarte hoy?\nPuedo responder preguntas sobre nuestros tratamientos, precios, horarios o agendar una cita.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip("¿Qué tratamientos ofrecen?"),
              _buildSuggestionChip("Precios de blanqueamiento"),
              _buildSuggestionChip("Horarios disponibles"),
              _buildSuggestionChip("Quiero agendar una cita"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _sendMessage(text);
      },
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Escribe tu mensaje aquí...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send, // Acción enviar en el teclado
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: () {
              if (_messageController.text.trim().isNotEmpty) {
                _sendMessage(_messageController.text);
              }
            },
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
      ));
      _messageController.clear();
      _isTyping = true;
    });

     // Desplazar hacia abajo después de enviar un mensaje
    _scrollToBottom();

    // Simulación de respuesta del asistente virtual
    Future.delayed(const Duration(seconds: 1), () {
      _getAIResponse(text);
    });
  }

  void _getAIResponse(String query) {
    // Aquí implementarías la llamada a tu servicio de IA
    // Por ahora, simularemos respuestas básicas
    String response;

    query = query.toLowerCase();

    if (query.contains("tratamiento") || query.contains("ofrecen")) {
      response = "En Clínicas Love ofrecemos diversos tratamientos como blanqueamiento dental, ortodoncia, implantes dentales, limpieza dental profesional y más. ¿Te gustaría información detallada sobre alguno en particular?";
    } else if (query.contains("precio") || query.contains("costo") || query.contains("blanqueamiento")) {
      response = "El blanqueamiento dental tiene un precio desde \$2,500 MXN. Actualmente tenemos una promoción con 15% de descuento si agendas este mes. ¿Te interesa agendar una cita?";
    } else if (query.contains("horario") || query.contains("disponible")) {
      response = "Nuestro horario de atención es de lunes a viernes de 9:00 AM a 7:00 PM y sábados de 9:00 AM a 2:00 PM. ¿En qué día te gustaría agendar?";
    } else if (query.contains("cita") || query.contains("agendar")) {
      response = "¡Perfecto! Para agendar una cita necesitaré algunos datos: \n1. Tu nombre completo\n2. Teléfono de contacto\n3. Tratamiento que te interesa\n4. Fecha y hora preferida";
    } else {
      response = "Gracias por tu mensaje. ¿Puedes proporcionar más detalles para poder ayudarte mejor? Puedo informarte sobre tratamientos, precios, horarios o agendar una cita para ti.";
    }

    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(
        text: response,
        isUser: false,
      ));
    });
  

      // Desplazar hacia abajo después de recibir una respuesta
    _scrollToBottom();
  }

  void _bookAppointmentFromChat(
    {String? treatmentId, String? clinicId, DateTime? date, String? notes}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AppointmentBookingPage(
        preSelectedTreatmentId: treatmentId,
        preSelectedClinicId: clinicId,
        preSelectedDate: date,
        prefilledNotes: notes,
      ),
    ),
  );
}

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose(); // Liberar recursos  
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isUser 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return const CircleAvatar(
      backgroundColor: Color(0xFF1980E6),
      child: Icon(
        Icons.smart_toy,
        color: Colors.white,
      ),
    );
  }
  
  Widget _buildUserAvatar() {
    return const CircleAvatar(
      backgroundColor: Colors.grey,
      child: Icon(
        Icons.person,
        color: Colors.white,
      ),
    );
  }
}