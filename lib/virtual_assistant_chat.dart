import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'booking_page.dart';
import 'services/openai_service.dart' as ai;
import 'services/medical_reference_service.dart';
import 'services/appointment_service.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'config/env.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'i18n/app_localizations.dart';
import 'services/prices_service.dart';

class VirtualAssistantChat extends StatefulWidget {
  const VirtualAssistantChat({super.key});

  @override
  State<VirtualAssistantChat> createState() => _VirtualAssistantChatState();
}

class _VirtualAssistantChatState extends State<VirtualAssistantChat> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatViewModel _viewModel;
  late AnimationController _animationController;
  late Animation<double> _animationPulse;
  bool _showSuggestions = true;
  late AppLocalizations localizations;
  

  
late bool _isViewModelInitialized = false;

@override
void initState() {
  super.initState();
  
  // Configuración de animación
  _animationController = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..repeat(reverse: true);
  
  _animationPulse = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeInOut,
  ));
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  localizations = AppLocalizations.of(context);
  
  // Inicializar ViewModel solo una vez
  if (!_isViewModelInitialized) {
    debugPrint('🔧 Inicializando servicios del asistente virtual...');

    // Inicializar servicios usando la configuración de entorno
    final openAIService = ai.OpenAIService(
      apiKey: Env.openAIApiKey,
      model: 'gpt-3.5-turbo',
      testMode: Env.useAITestMode,
    );
    
    final referenceService = MedicalReferenceService();
    final appointmentService = AppointmentService();
    
    // Inicializar ViewModel con el nuevo servicio
    _viewModel = ChatViewModel(
      openAIService: openAIService,
      referenceService: referenceService,
      appointmentService: appointmentService,
      localizations: localizations,
    );
    
    _isViewModelInitialized = true;
    
    // Enviar mensaje de bienvenida
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_viewModel.messages.isEmpty) {
        debugPrint('👋 Enviando mensaje de bienvenida');
        _viewModel.sendWelcomeMessage();
      }
    });
  }
}

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
    // Obtener ancho de pantalla para diseño responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final verticalPadding = isSmallScreen ? 8.0 : 16.0;
    
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<ChatViewModel>(
        builder: (context, viewModel, _) {
          // Ejecutar scroll cuando cambian los mensajes
          if (viewModel.messages.isNotEmpty) {
            _scrollToBottom();
          }
          
          return Scaffold(
            appBar: AppBar(
              title: Text(localizations.get('virtual_assistant')),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              actions: [
                if (!isSmallScreen)
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showInfoDialog(context),
                    tooltip: localizations.get('about_assistant'),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _resetChat(context),
                  tooltip: localizations.get('restart_conversation'),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Área de mensajes
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        image: DecorationImage(
                          image: const AssetImage('assets/images/Clinicas fondo.jpg'),
                          colorFilter: ColorFilter.mode(
                            Colors.white.withOpacity(0.1),
                            BlendMode.dstATop,
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: viewModel.messages.isEmpty
                          ? _buildWelcomeMessage()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.symmetric(
                                vertical: verticalPadding,
                                horizontal: isSmallScreen ? 8.0 : 16.0,
                              ),
                              itemCount: viewModel.messages.length + 
                                (_showSuggestions && viewModel.suggestedReplies.isNotEmpty ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index < viewModel.messages.length) {
                                  return _buildMessage(viewModel.messages[index]);
                                } else {
                                  return _buildSuggestedReplies(viewModel.suggestedReplies);
                                }
                              },
                            ),
                    ),
                  ),
                  
                  // Indicador de escritura
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: viewModel.isTyping ? 40 : 0,
                    child: viewModel.isTyping 
                      ? Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(width: 16),
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1980E6)),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(localizations.get('assistant_typing'),
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                  ),
                  
                  // Campo para escribir mensajes
                  _buildMessageComposer(isSmallScreen),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  topLeft: message.isUser ? Radius.circular(16) : Radius.circular(0),
                  topRight: !message.isUser ? Radius.circular(16) : Radius.circular(0),
                ),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ],
              ),
              child: message.isUser 
                ? Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  )
                : MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: Color(0xFF303030),
                      ),
                      strong: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      a: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 8),
          if (message.isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildSuggestedReplies(List<String> suggestions) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: SizedBox(
        height: 45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            return ActionChip(
              label: Text(
                suggestions[index],
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
              backgroundColor: const Color(0xFFE3F2FD),
              elevation: 1,
              shadowColor: Colors.black26,
              onPressed: () {
                _sendMessage(suggestions[index]);
                setState(() {
                  _showSuggestions = false;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1980E6), Color(0xFF1464B3)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.smart_toy,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF757575), Color(0xFF616161)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  Widget _buildWelcomeMessage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16.0 : 32.0,
          vertical: 24.0,
        ),
        child: AnimatedBuilder(
          animation: _animationPulse,
          builder: (context, child) => Transform.scale(
            scale: _animationPulse.value,
            child: child,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: isSmallScreen ? 80 : 100,
                      height: isSmallScreen ? 80 : 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.smart_toy_outlined,
                        size: isSmallScreen ? 48 : 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      localizations.get('welcome_title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localizations.get('welcome_description'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                localizations.get('try_questions'),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                _buildSuggestionChip(localizations.get('what_treatments')),
                _buildSuggestionChip(localizations.get('whitening_prices')),
                _buildSuggestionChip(localizations.get('available_hours')),
                _buildSuggestionChip(localizations.get('want_appointment')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(text),
      backgroundColor: Colors.white,
      side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      avatar: Icon(
        Icons.chat_bubble_outline,
        size: 18,
        color: Theme.of(context).colorScheme.primary,
      ),
      elevation: 1,
      shadowColor: Colors.black26,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onPressed: () {
        _sendMessage(text);
      },
    );
  }

  Widget _buildMessageComposer(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8.0 : 12.0,
        vertical: isSmallScreen ? 8.0 : 12.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.07),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: localizations.get('write_message_here'),
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: isSmallScreen ? 14 : 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: isSmallScreen ? 40 : 48,
                width: isSmallScreen ? 40 : 48,
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onTap: () {
                if (_messageController.text.trim().isNotEmpty) {
                  _sendMessage(_messageController.text);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    _messageController.clear();
    setState(() {
      _showSuggestions = false;
    });
    
    // Detectar palabras de confirmación para el flujo de reservas
    final lowerText = text.toLowerCase();
    final isConfirmingAppointment = _viewModel.isBookingFlow && 
        (lowerText == 'confirmar' || 
        lowerText == 'confirmo' || 
        lowerText == 'si' || 
        lowerText == 'sí' || 
        lowerText == 'ok' || 
        lowerText.contains('confirm'));
    
    if (isConfirmingAppointment) {
      debugPrint('✅ Detectada confirmación de cita: "$text"');
    }
    
    _viewModel.sendMessage(text);
  }

  void _resetChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.get('restart_conversation')),
        content: Text(localizations.get('restart_confirmation')),
        actions: [
          TextButton(
            child: Text(localizations.get('cancel')),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text(localizations.get('restart')),
            onPressed: () {
              _viewModel.resetChat();
              Navigator.of(context).pop();
              setState(() {
                _showSuggestions = true;
              });
            },
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.get('virtual_assistant')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.get('assistant_help_with')),
            SizedBox(height: 8),
            Text(localizations.get('treatments_info')),
            Text(localizations.get('prices_promotions')),
            Text(localizations.get('opening_hours')),
            Text(localizations.get('appointment_scheduling')),
            SizedBox(height: 16),
            Text(localizations.get('specialist_consultation_reminder')),
          ],
        ),
        actions: [
          ElevatedButton(
            child: Text(localizations.get('understood')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}

// Para que este archivo funcione, asegúrate de implementar las clases AppointmentInfo y ChatMessage:

class AppointmentInfo {
  String? treatmentId;
  String? clinicId;
  DateTime? date;
  String? notes;
  
  bool get hasBasicInfo => treatmentId != null;
  bool get isComplete => treatmentId != null && clinicId != null && date != null;
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text, 
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}