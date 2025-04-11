import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/claude_assistant_service.dart' as ai;
import 'viewmodels/chat_viewmodel.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'i18n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' ;
import 'providers/user_provider.dart';
import 'services/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? additionalContext; // Para almacenar contexto adicional
  
  ChatMessage({
    required this.text,
    required this.isUser,
    this.additionalContext,
  });
}

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
  
  _syncUserStateFromSupabase();

    // Añadir un listener para cambios de autenticación
  SupabaseService().client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedOut) {
      debugPrint('🔄 Evento de cierre de sesión detectado en chat');
      // Limpiar el UserProvider cuando se detecte un logout
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.logout();
        
        // Forzar reconstrucción para actualizar UI
        setState(() {});
      }
    }
  });
  
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

  // Nuevo método para sincronizar el estado de usuario directamente desde Supabase
Future<void> _syncUserStateFromSupabase() async {
  try {
    final supabase = SupabaseService().client;
    final currentUser = supabase.auth.currentUser;
    
    debugPrint('🔍 Verificando usuario de Supabase: ${currentUser?.id}');
    
    if (currentUser != null) {
      try {
        // Cambiar para obtener TODOS los campos y hacer logging completo
        final userData = await supabase
            .from('profiles')
            .select('*')  // Seleccionar todos los campos para ver qué contiene realmente
            .eq('id', currentUser.id)
            .single();
        
        debugPrint('📝 Datos completos del perfil: $userData');
        
        // Comprobar todos los posibles nombres de campo para la URL del avatar
        String? avatarUrl = userData['avatar_url'] ?? 
                          userData['profile_image_url'] ?? 
                          userData['image_url'] ?? 
                          userData['photo_url'] ?? 
                          userData['profile_picture'] ??
                          userData['image'];
        
        debugPrint('🖼️ URL de avatar encontrada: $avatarUrl');
        
        // Crear modelo de usuario con la URL del avatar real
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(UserModel(
          userId: currentUser.id,
          name: userData['full_name'] ?? userData['name'] ?? currentUser.email,
          profileImageUrl: avatarUrl,
        ));
        
        // Forzar reconstrucción para mostrar el avatar
        if (mounted) setState(() {});
        
      } catch (e) {
        debugPrint('❌ Error obteniendo datos del usuario: $e');
        
        // Como fallback, intentar con metadatos del usuario
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final avatarUrl = currentUser.userMetadata?['avatar_url'];
        
        debugPrint('🔍 Intentando con metadatos: $avatarUrl');
        
        userProvider.setUser(UserModel(
          userId: currentUser.id,
          name: currentUser.email,
          profileImageUrl: avatarUrl,
        ));
      }
    } else {
      debugPrint('⚠️ No hay usuario autenticado en Supabase');
    }
  } catch (e) {
    debugPrint('❌ Error sincronizando usuario: $e');
  }
}


@override
void didChangeDependencies() {
  super.didChangeDependencies();
  localizations = AppLocalizations.of(context);
  
  // Inicializar ViewModel solo una vez
  if (!_isViewModelInitialized) {
    debugPrint('🔧 Inicializando servicios del asistente virtual...');

    // Usar la clave de Claude desde el archivo .env
    final claudeService = ai.ClaudeAssistantService(
      apiKey: dotenv.env['CLAUDE_API_KEY'],  // ✅ Correcto: usa la clave de Claude
      model: 'claude-3-haiku-20240307',
      useFallback: true,  // Activar respuestas de respaldo cuando la API falla
    );

    
    // Inicializar ViewModel con el servicio Claude
    _viewModel = ChatViewModel(
      aiService: claudeService,
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
                        color: const Color(0xFFE8EAED),
                        image: DecorationImage(
                          image: const AssetImage('assets/images/Clinicas fondo.jpg'),
                          colorFilter: ColorFilter.mode(
                            Colors.white.withOpacity(0.15),
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

  Widget _buildScheduleButton() {
    return Center(
      child: Transform.scale(
        scale: 0.9,
        child: ElevatedButton(
          onPressed: () {
            _handleAppLink('app://schedule');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1980E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.calendar_today, color: Colors.white, size: 18), // Reducir tamaño del icono
              SizedBox(width: 6), // Reducir espacio
              Flexible( // Añadir Flexible aquí
                child: Text(
                  'Agendar una cita',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15, // Reducir un poco el tamaño de fuente
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis, 
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Añadir después del método _buildScheduleButton()
  Widget _buildClinicasButton() {
    return Center(
      child: Transform.scale(
        scale: 0.9,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushNamed('/clinicas');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1980E6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.location_on, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Ver clínicas en mapa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildMessage(ChatMessage message) {
  final shouldShowScheduleButton = message.additionalContext == "show_schedule_button" ||
                                  message.text.contains('[Agendar una cita](app://schedule)');
  
  // línea para definir processedText
  final processedText = message.text.replaceAll('[Agendar una cita](app://schedule)', '');
  
  final shouldShowClinicasButton = message.additionalContext == "show_clinics_button" || 
                                  message.additionalContext == "show_clinic_button" || 
                                  message.text.contains('(app://clinicas)');

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  : const Color(0xFFF0F2F5), 
              borderRadius: BorderRadius.circular(16).copyWith(
                topLeft: message.isUser ? Radius.circular(16) : Radius.circular(0),
                topRight: !message.isUser ? Radius.circular(16) : Radius.circular(0),
              ),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 1),
                  blurRadius: 3, // Sombra más pronunciada
                  spreadRadius: 0.5,
                  color: Colors.black.withOpacity(0.15),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mostrar el texto del mensaje sin el enlace
                if (processedText.isNotEmpty)
                MarkdownBody(
                  data: processedText,
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      if (href.startsWith('app://')) {
                        // Manejo existente para enlaces internos de la app
                        _handleAppLink(href);
                      } else if (href.startsWith('https://wa.me/')) {
                        // Nuevo manejo para enlaces de WhatsApp
                        final Uri uri = Uri.parse(href);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          debugPrint('❌ No se pudo abrir el enlace de WhatsApp: $href');
                        }
                      } else {
                        // Cualquier otro enlace externo
                        final Uri uri = Uri.parse(href);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          debugPrint('❌ No se pudo abrir el enlace: $href');
                        }
                      }
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: message.isUser ? Colors.white : const Color(0xFF303030),
                      fontSize: 15.0,
                    ),
                    strong: TextStyle(
                      color: message.isUser ? Colors.white : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    a: TextStyle(
                      // Hacer los enlaces más evidentes
                      color: message.isUser ? Colors.white.withOpacity(0.9) : Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                  
                // Mostrar el botón si el mensaje contiene el enlace
                if (shouldShowScheduleButton)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildScheduleButton(),
                  ),
                  
                // Mostrar el botón de clínicas si corresponde
                if (shouldShowClinicasButton)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildClinicasButton(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (message.isUser) _buildUserAvatar(),
      ],
    ),
  );
}

  void _handleAppLink(String href) {
    if (href == 'app://schedule') {
      // Redirigir a la página de agendar citas
      Navigator.pushNamed(context, '/book-appointment');
    } else if (href == 'app://clinicas') {
      // Redirigir a la página de clínicas cercanas
      Navigator.pushNamed(context, '/clinicas');
    } else {
      debugPrint('🔗 Enlace desconocido: $href');
    }
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
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final isLoggedIn = userProvider.isLoggedIn;
      
      debugPrint('🔍 Estado de login en _buildUserAvatar: $isLoggedIn');
      
      if (isLoggedIn) {
        final user = userProvider.user;
        String? profileImageUrl = user?.profileImageUrl;
        
        debugPrint('📸 URL de avatar encontrado: $profileImageUrl');
        
        // Si tenemos una URL de imagen válida
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          return Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ Error cargando imagen: $error');
                  return _buildDefaultUserAvatar();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
      
      return _buildDefaultUserAvatar();
    } catch (e) {
      debugPrint('⚠️ Excepción en _buildUserAvatar: $e');
      return _buildDefaultUserAvatar();
    }
  }

  // Método auxiliar para avatar por defecto
  Widget _buildDefaultUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7986CB), Color(0xFF3F51B5)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.person, color: Colors.white, size: 20),
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
          color: const Color(0xFFF0F2F5), // Color más oscuro para el área de composición
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -1),
              blurRadius: 4,
              color: Colors.black.withOpacity(0.09), // Sombra más pronunciada
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

    final lowerText = text.toLowerCase();
    final currentLanguage = localizations.locale.languageCode;

      // NUEVO: Intentar identificar consultas sobre tratamientos específicos
    if (_mightBeTreatmentQuery(lowerText)) {
      _viewModel.addUserMessage(text);
      _viewModel.setTyping(true);
      
      debugPrint('🧠 INTERCEPTANDO CONSULTA DE TRATAMIENTO ESPECÍFICO CON IA');
      
      // Usar el método de reconocimiento de tratamientos basado en IA
      _viewModel.recognizeAndRespondToTreatment(text).then((treatmentInfo) {
        _viewModel.addBotMessage(
          treatmentInfo,
          additionalContext: "show_schedule_button",
          userQuery: text
        );
      });
      
      return;
    }
    
    // PRIMERO: Interceptar consultas sobre CATÁLOGO GENERAL
    // Esta condición debe tener la más alta prioridad
    if (_containsAny(lowerText, ['tratamientos', 'servicios', 'catálogo', 'ofrecen', 'tienen', 'realizan']) && 
        !_containsAny(lowerText, ['nariz', 'facial', 'cara', 'labios', 'piel', 'botox', 'ácido', 'especifico', 'específico']) &&
        (_containsAny(lowerText, ['que', 'cuáles', 'cuales', 'lista', 'todos', 'disponibles']))) {
      
      _viewModel.addUserMessage(text);
      _viewModel.setTyping(true);
      
      debugPrint('📚 INTERCEPTANDO CONSULTA DE CATÁLOGO GENERAL DE TRATAMIENTOS');
      
      // Usar el método para mostrar tratamientos por categoría
      _viewModel.getAllTreatmentsByCategory().then((treatmentsInfo) {
        _viewModel.addBotMessage(
          treatmentsInfo,
          additionalContext: "show_schedule_button",
          userQuery: text
        );
      });
      
      return;
    }

    if ((_containsAny(lowerText, ['todos', 'lista', 'cuales', 'disponibles', 'que', 'tienen']) && 
    _containsAny(lowerText, ['tratamiento', 'ofrecen', 'servicios', 'procedimiento']) &&
    _containsAny(lowerText, ['nariz', 'facial', 'cara', 'labios', 'piel', 'cuerpo']))) {
    
    _viewModel.addUserMessage(text);
    _viewModel.setTyping(true);
    
    debugPrint('🗂️ INTERCEPTANDO CONSULTA DE TODOS LOS TRATAMIENTOS POR ÁREA');
    
    // Usar el método para listar todos los tratamientos del área
    _viewModel.getAllTreatmentsByArea(text).then((treatmentsInfo) {
      _viewModel.addBotMessage(
        treatmentsInfo,
        additionalContext: "show_schedule_button",
        userQuery: text
      );
    });
    
    return;
  }

    // Verificar si es una pregunta sobre ubicaciones
    final isLocationQuestion = _containsAny(lowerText, [
      'dónde', 'donde', 'ubicación', 'ubicacion', 'dirección', 
      'direccion', 'clínica', 'clinica', 'están', 'estan'
    ]);

    // INTERCEPTAR CONSULTAS DE UBICACIÓN
    if (isLocationQuestion) {
      _viewModel.addUserMessage(text);
      _viewModel.setTyping(true);
      
      _viewModel.processMessage(text, currentLanguage).then((response) {
        _viewModel.addBotMessage(response.text);
      });
      
      return;
    }

    // 1. INTERCEPTAR CONSULTAS DE PRECIOS
    if (_containsAny(lowerText, ['precio', 'cuesta', 'cuánto', 'cuanto', 'valor', 'tarifa', 'price', 'cost', 'how much', 'preu'])) {
      _viewModel.addUserMessage(text);
      _viewModel.setTyping(true);

      _viewModel.getSpecificPriceFromKnowledgeBase(text).then((priceInfo) {
        if (priceInfo.isNotEmpty) {
          _viewModel.addBotMessage(
            priceInfo,
            additionalContext: "show_schedule_button",
            userQuery: text

          );
        } else {
          _viewModel.addBotMessage(
            localizations.get('no_price_info'),
            additionalContext: "show_schedule_button",
            userQuery: text
          );
        }
      });

      return;
    }
    
    // Interceptar consultas generales sobre el catálogo de tratamientos
    if (_containsAny(lowerText, ['qué tratamientos', 'que tratamientos', 'tratamientos disponibles', 
                              'catálogo', 'catalogo', 'servicios disponibles', 'ofrecen', 'tienen']) && 
       !_containsAny(lowerText, ['nariz', 'facial', 'cara', 'labios', 'piel', 'cuerpo'])) {
    
    _viewModel.addUserMessage(text);
    _viewModel.setTyping(true);
    
    debugPrint('📚 INTERCEPTANDO CONSULTA DE CATÁLOGO GENERAL DE TRATAMIENTOS');
    
    // Usar el nuevo método para obtener tratamientos por categoría
    _viewModel.getAllTreatmentsByCategory().then((treatmentsInfo) {
      _viewModel.addBotMessage(
        treatmentsInfo,
        additionalContext: "show_schedule_button",
        userQuery: text
      );
    });
    
    return;
  }

    // 2. INTERCEPTAR CONSULTAS DE TRATAMIENTOS
    if (_containsAny(lowerText, ['tratamiento', 'ofrecen', 'servicios', 'hacen', 'realizan', 'procedimiento'])) {
      // Si está preguntando específicamente por "todos" o "lista" de tratamientos de un área
      if (_containsAny(lowerText, ['todos', 'lista', 'disponibles']) && 
          (_containsAny(lowerText, ['nariz', 'facial', 'cara', 'labios', 'piel', 'cuerpo']))) {
        
        _viewModel.addUserMessage(text);
        _viewModel.setTyping(true);
        
        // Usar el nuevo método para obtener todos los tratamientos del área
        _viewModel.getAllTreatmentsByArea(text).then((treatmentsInfo) {
          _viewModel.addBotMessage(
            treatmentsInfo,
            additionalContext: "show_schedule_button",
            userQuery: text
          );
        });
        
        return;
      } else {
        // Caso existente para consultas de tratamientos individuales
        _viewModel.addUserMessage(text);
        _viewModel.setTyping(true);
        
        _viewModel.getSpecificPriceFromKnowledgeBase(text).then((priceInfo) {
          if (priceInfo.isNotEmpty) {
            _viewModel.addBotMessage(
              priceInfo,
              additionalContext: "show_schedule_button",
              userQuery: text
            );
          } else {
            _viewModel.addBotMessage(
              localizations.get('no_price_info'),
              additionalContext: "show_schedule_button",
              userQuery: text
            );
          }
        });
        
        return;
      }
    }

    // 3. Para todas las demás consultas, usar Claude AI
    _viewModel.addUserMessage(text);
    _viewModel.setTyping(true);

    // Enviar el idioma actual al modelo de IA
    _viewModel.processMessage(text, currentLanguage).then((response) {
      // Añadir el botón de cita a todas las respuestas
      _viewModel.addBotMessage(
        response.text, 
        additionalContext: "show_schedule_button" ,
        userQuery: text 
      );
    });
  }

  // Modificar para ser más específico y NO atrapar preguntas generales
  bool _mightBeTreatmentQuery(String text) {
    // Si está preguntando por el catálogo general, NO es una consulta específica
    if (_containsAny(text.toLowerCase(), ['que tratamientos', 'qué tratamientos', 'cuales son', 'cuáles son', 'que ofrecen', 'qué ofrecen']) &&
        !_containsAny(text.toLowerCase(), ['nariz', 'facial', 'botox', 'rinoplastia', 'aumento'])) {
      return false;
    }
    
    // Palabras que indican que podría ser una consulta sobre tratamientos específicos
    final treatmentIndicators = [
      'botox', 'ácido', 'hialurónico', 'rinoplastia', 'rinomodelación', 
      'lifting', 'blefaroplastia', 'peeling', 'mastopexia', 'lipoestructura',
      'mesoterapia', 'liposuccion', 'abdominoplastia'
    ];
    
    for (final indicator in treatmentIndicators) {
      if (text.toLowerCase().contains(indicator)) {
        debugPrint('🔍 Detectado tratamiento específico: $indicator');
        return true;
      }
    }
    
    return false;
  }

  // Añade este método auxiliar
  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
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

  String _detectLanguage(String text) {
    // Detección básica basada en palabras comunes
    text = text.toLowerCase();
    
    // Palabras comunes en español
    List<String> spanishWords = ['el', 'la', 'los', 'las', 'de', 'en', 'para', 'que', 'como', 
                                'con', 'por', 'pero', 'si', 'qué', 'cuál', 'dónde', 'cuándo'];
    
    // Palabras comunes en inglés
    List<String> englishWords = ['the', 'of', 'and', 'to', 'in', 'that', 'for', 'is', 'on', 
                                'with', 'by', 'at', 'this', 'be', 'what', 'where', 'when', 'how'];
    
    // Palabras comunes en catalán
    List<String> catalanWords = ['el', 'la', 'els', 'les', 'de', 'en', 'amb', 'per', 'què', 
                                'com', 'si', 'però', 'quan', 'quant', 'on', 'quin'];

    // Contar coincidencias
    int spanishCount = 0;
    int englishCount = 0;
    int catalanCount = 0;
    
    for (String word in text.split(RegExp(r'[^a-zA-ZáéíóúàèòùÀÈÌÒÙçÇäëïöüÄËÏÖÜñÑ]+'))) {
      if (spanishWords.contains(word)) spanishCount++;
      if (englishWords.contains(word)) englishCount++;
      if (catalanWords.contains(word)) catalanCount++;
    }
    
    // Determinar el idioma más probable
    if (englishCount > spanishCount && englishCount > catalanCount) {
      return 'en';
    } else if (catalanCount > spanishCount && catalanCount > englishCount) {
      return 'ca';
    } else if (spanishCount > 0) {
      return 'es';
    }
    
    // Si no hay coincidencias claras, usar el idioma de la interfaz
    return localizations.locale.languageCode;
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
