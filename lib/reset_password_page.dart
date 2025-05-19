import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';  
import 'services/supabase.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart';
import 'utils/security_utils.dart';
import 'utils/secure_logger.dart';


class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabaseService = SupabaseService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;
  String? _resetCode;


  @override
  void initState() {
    super.initState();
    // Obtener el código de los argumentos de la ruta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      
      if (args != null) {
        if (args is String) {
          // Es un código normal
          setState(() {
            _resetCode = args;
          });
          SecureLogger.log('Código de reset recibido: $_resetCode', sensitive: false);
        } else if (args is Map<String, dynamic> && args['isError'] == true) {
          // Es un error proveniente del deep link
          setState(() {
            _errorMessage = 'El enlace ha expirado. Por favor solicita uno nuevo.';
          });
          
          // Mostrar modal automáticamente para solicitar nuevo código
          Future.delayed(Duration(milliseconds: 500), () {
            _showRequestNewTokenDialog();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).get('passwords_dont_match');
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      SecureLogger.log('Intentando actualizar contraseña con código: $_resetCode', sensitive: false);
      
      // PASO 1: Usar directamente el método de recuperación de contraseña
      if (_resetCode != null) {
        // Necesitamos el email del usuario para este flujo
        final String? email = _emailController.text.isNotEmpty ? _emailController.text : null;
        
        if (email == null) {
          throw Exception('Se requiere correo electrónico');
        }
        
        // Verificar OTP con email y token
        final response = await _supabaseService.client.auth.verifyOTP(
          email: email,  // Añadir el email aquí
          type: OtpType.recovery,
          token: _resetCode,
        );
        
        SecureLogger.log('Verificación OTP completada: ${response.session != null}', sensitive: false);
        
        // Con la sesión activa, actualizar la contraseña
        if (response.session != null) {
          await _supabaseService.client.auth.updateUser(
            UserAttributes(password: _passwordController.text),
          );
          
          SecureLogger.log('Contraseña actualizada correctamente', sensitive: false);
        }
      } else {
        throw Exception('No se recibió código de recuperación');
      }
        
        if (!mounted) return;
        
        // Mostrar mensaje de éxito y navegar al login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).get('password_reset_success')),
            backgroundColor: Colors.green,
          )
        );
        
        // Navegar a login después de actualizar contraseña
        SecurityUtils.navigateToSafely(context, '/login');
        } catch (e) {
          SecureLogger.log('Error al resetear contraseña: $e', sensitive: false);
          
          // Manejo específico para token expirado
          if (e.toString().contains('otp_expired') || e.toString().contains('Token has expired')) {
            setState(() {
              _errorMessage = AppLocalizations.of(context).get('token_expired_error') ?? 
                'El enlace de recuperación ha expirado. Por favor solicita uno nuevo.';
              _isLoading = false;
            });
            
            // Mostrar botón para solicitar nuevo código
            _showRequestNewTokenDialog();
          } else {
            setState(() {
              _errorMessage = AppLocalizations.of(context).get('password_reset_error');
              _isLoading = false;
            });
          }
        }
    } 


  void _showRequestNewTokenDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).get('token_expired') ?? 'Código expirado'),
        content: Text(AppLocalizations.of(context).get('token_expired_message') ?? 
          'El código de recuperación ha expirado. ¿Deseas solicitar uno nuevo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).get('cancel') ?? 'Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // Ya tienes el email porque lo pides en el formulario
              if (_emailController.text.isEmpty) {
                setState(() {
                  _errorMessage = AppLocalizations.of(context).get('valid_email_required') ?? 
                    'Por favor ingresa tu correo electrónico';
                });
                return;
              }
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                // Solicitar nuevo código directamente desde aquí
                await _supabaseService.resetPassword(_emailController.text);

                // Cerrar cualquier sesión parcial creada
                await _supabaseService.client.auth.signOut();
                
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });
                
                // Mostrar confirmación
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).get('reset_link_sent') ?? 
                      'Se ha enviado un nuevo enlace a tu correo'),
                    backgroundColor: Colors.green,
                  )
                );
                  } catch (e) {
                    // También intentar cerrar sesión en caso de error
                    try {
                      await _supabaseService.client.auth.signOut();
                    } catch (_) {}
                    
                    setState(() {
                      _isLoading = false;
                      _errorMessage = 'Error al solicitar nuevo código: ${e.toString()}';
                    });
                  }
            },
            child: Text(AppLocalizations.of(context).get('request_new_code') ?? 'Solicitar nuevo código'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    AdaptiveSize.initialize(context);
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(title: Text(localizations.get('reset_password'))),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    localizations.get('create_new_password'),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 24.h),

                  // Campos para email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: localizations.get('email'),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => (value == null || !value.contains('@')) 
                      ? localizations.get('valid_email_required')
                      : null,
                  ),
                  SizedBox(height: 16.h),
                  
                  // Campos para contraseña
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: localizations.get('new_password'),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                    obscureText: !_passwordVisible,
                    validator: (value) => (value == null || value.length < 6) 
                      ? localizations.get('password_too_short')
                      : null,
                  ),
                  
                  SizedBox(height: 16.h),
                  
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: localizations.get('confirm_password'),
                      suffixIcon: IconButton(
                        icon: Icon(_confirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                      ),
                    ),
                    obscureText: !_confirmPasswordVisible,
                    validator: (value) => (value == null || value != _passwordController.text) 
                      ? localizations.get('passwords_dont_match')
                      : null,
                  ),
                  
                  if (_errorMessage != null)
                    Padding(
                      padding: EdgeInsets.only(top: 16.h),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red, fontSize: 14.sp),
                      ),
                    ),
                  
                  SizedBox(height: 32.h),
                  
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    child: _isLoading 
                      ? const CircularProgressIndicator()
                      : Text(localizations.get('update_password')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}