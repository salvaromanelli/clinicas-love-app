import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'virtual_assistant_chat.dart'; // ignore: unused_import
import 'main.dart';

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

  @override
  void initState() {
    super.initState();
    
    // Configurar animaciones
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    // Mostrar tooltip después de 2 segundos
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showTooltip = true;
          });
          _animationController.forward();
          
          // Ocultar tooltip después de 5 segundos
          Future.delayed(const Duration(seconds: 5), () {
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
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4.0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "¿Necesitas ayuda? ¡Chatea conmigo!",
                          style: TextStyle(
                            color: Color(0xFF1980E6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Color(0xFF1980E6),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        FloatingActionButton(
          onPressed: () {
            // Usar navigatorKey para navegación garantizada
            navigatorKey.currentState?.pushNamed('/assistant');
          },
          backgroundColor: const Color(0xFF1980E6),
          child: const Icon(
            Icons.support_agent,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}