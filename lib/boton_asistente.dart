import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'virtual_assistant_chat.dart';
import 'main.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart';

class AnimatedAssistantButton extends StatefulWidget {
  const AnimatedAssistantButton({super.key});

  @override
  State<AnimatedAssistantButton> createState() => _AnimatedAssistantButtonState();
}

class _AnimatedAssistantButtonState extends State<AnimatedAssistantButton> with SingleTickerProviderStateMixin {
  bool _showTooltip = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late AppLocalizations localizations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }

  @override
  void initState() {
    super.initState();
    
    // Configurar animaciones mejoradas
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Animación más lenta para mejor legibilidad
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut), // Menos elástico para mejor legibilidad
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    // Mostrar tooltip después de 1.5 segundos
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showTooltip = true;
          });
          _animationController.forward();
          
          // Aumentado a 8 segundos para dar tiempo a leer
          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) {
              _animationController.reverse().then((_) {
                setState(() {
                  _showTooltip = false;
                });
              });
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usar una proporción mayor del ancho disponible
    final screenWidth = MediaQuery.of(context).size.width;
    final tooltipWidth = screenWidth < 360 ? screenWidth * 0.6 : screenWidth * 0.5;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showTooltip)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    margin: EdgeInsets.only(bottom: AdaptiveSize.h(8)),
                    padding: EdgeInsets.symmetric(
                      horizontal: AdaptiveSize.w(16), 
                      vertical: AdaptiveSize.h(12)  // Más espacio vertical
                    ),
                    constraints: BoxConstraints(
                      maxWidth: tooltipWidth,  // Ancho mayor para más texto
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1980E6).withOpacity(0.15),
                          blurRadius: 10.0,
                          spreadRadius: 1.0,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF1980E6).withOpacity(0.1),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: const Color(0xFF1980E6),
                          size: AdaptiveSize.sp(18),  // Icono ligeramente más grande
                        ),
                        SizedBox(width: AdaptiveSize.w(10)),
                        // Texto con más espacio y mejor configuración
                        Flexible(
                          child: Text(
                            localizations.get('need_help_chat_with_me'),
                            style: TextStyle(
                              color: const Color(0xFF1980E6),
                              fontWeight: FontWeight.w500,  // Un poco menos bold para mejor legibilidad
                              fontSize: AdaptiveSize.sp(13),  // Tamaño de texto ligeramente mayor
                              height: 1.3,  // Mejor espaciado entre líneas
                            ),
                            overflow: TextOverflow.visible,  // Permitir que se muestre todo el texto
                            maxLines: 3,  // Permitir hasta 3 líneas para mensajes largos
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        // Botón flotante (sin cambios)
        SizedBox(
          width: AdaptiveSize.w(56),
          height: AdaptiveSize.w(56),
          child: FloatingActionButton(
            onPressed: () {
              navigatorKey.currentState?.pushNamed('/assistant');
            },
            backgroundColor: const Color(0xFF1980E6),
            elevation: 4.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdaptiveSize.w(28)),
            ),
            child: Icon(
              Icons.support_agent,
              color: Colors.white,
              size: AdaptiveSize.sp(26),
            ),
          ),
        ),
      ],
    );
  }
}