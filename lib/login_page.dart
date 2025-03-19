import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase.dart';
import 'services/auth_service.dart';
import 'i18n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  final Widget child;
  const LoginPage({super.key, required this.child});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();
  final _storage = const FlutterSecureStorage();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;
  late AppLocalizations localizations; 

  // Método de login principal - corregido
  Future<void> _handleLogin() async {
    // Validación del formulario
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    
    // Establecer estado de carga ANTES de iniciar el proceso
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Iniciar sesión con Supabase
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Obtener y guardar token
        final token = await _supabaseService.getToken();
        if (token != null) {
          await _authService.saveToken(token);
          
          if (!mounted) return;
          
          // Logs para depuración
          print("Inicio de sesión exitoso, token: ${token.substring(0, min(10, token.length))}...");
          print("Redirigiendo a página de perfil...");
          
          // Navegar a la página de perfil y eliminar historial de navegación
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/profile', 
            (route) => false
          );
        } else {
          throw Exception(localizations.get('auth_token_error'));
        }
      } else {
        throw Exception(localizations.get('auth_error'));
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
      print("Error de autenticación: ${e.message}");
    } catch (e) {
      // Manejo más amigable de errores comunes
      String errorMsg;
      
      if (e.toString().contains('Invalid login credentials')) {
        errorMsg = localizations.get('invalid_credentials');
      } else if (e.toString().contains('Email not confirmed')) {
        errorMsg = localizations.get('email_not_confirmed');
      } else if (e.toString().contains('network')) {
        errorMsg = localizations.get('network_error');
      } else {
        errorMsg = '${localizations.get('error')}: ${e.toString()}';
      }

      
      setState(() {
        _errorMessage = errorMsg;
      });
      print("Error de login: $errorMsg");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  localizations = AppLocalizations.of(context);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background navigation
          widget.child,
          
          // Login overlay
          Container(
            color: const Color(0xFF111418).withOpacity(0.95),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with back button and logo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                        ),
                        Expanded(
                          child: Center(
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                height: 60.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48.0),
                      ],
                    ),
                  ),
                  // Login form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Form( // Añadido Form
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 32.0),
                            Text(
                              localizations.get('login'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                              Text(
                                localizations.get('welcome_to_clinics'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            const SizedBox(height: 32.0),
                            
                            // Email field with icon - cambiado a TextFormField
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: localizations.get('email'),
                                labelStyle: TextStyle(color: Colors.white70),
                                prefixIcon: Icon(Icons.email, color: Colors.white70),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations.get('please_enter_email');
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return localizations.get('enter_valid_email');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16.0),
                            
                            // Password field with toggle visibility - cambiado a TextFormField
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: localizations.get('password'),
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _passwordVisible = !_passwordVisible;
                                    });
                                  },
                                ),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations.get('please_enter_password');
                                }
                                return null;
                              },
                              obscureText: !_passwordVisible,
                              style: const TextStyle(color: Colors.white),
                            ),
                            
                            // Forgot password link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: Text(
                                  localizations.get('forgot_password'),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            
                            // Error message
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.redAccent),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            
                            const SizedBox(height: 24.0),
                            
                            // Login button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1980E6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  disabledBackgroundColor: Colors.grey,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        localizations.get('login'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 24.0),
                            
                            // Or divider
                            Row(
                              children: [
                                const Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Text(
                                    localizations.get('or_continue_with'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                                const Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                            
                            const SizedBox(height: 24.0),
                            
                            // Social login buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildSocialButton(
                                  onPressed: () => _handleSocialLogin('google'),
                                  iconPath: 'assets/images/google_icon.png',
                                  label: 'Google',
                                ),
                                _buildSocialButton(
                                  onPressed: () => _handleSocialLogin('facebook'),
                                  iconPath: 'assets/images/facebook_icon.png',
                                  label: 'Facebook',
                                ),
                                _buildSocialButton(
                                  onPressed: () => _handleSocialLogin('apple'),
                                  iconPath: 'assets/images/apple_icon.png',
                                  label: 'Apple',
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24.0),
                            
                            // Register link
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/register');
                                },
                                child: Text(
                                  localizations.get('no_account_register'),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Social login button widget
  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required String iconPath,
    required String label,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: Image.asset(
                iconPath,
                height: 28,
                width: 28,
                errorBuilder: (context, error, stackTrace) {
                  // En caso de que no encuentre la imagen, mostrar un icono genérico
                  return Icon(
                    label == 'Google' ? Icons.g_mobiledata : 
                    label == 'Facebook' ? Icons.facebook : 
                    Icons.apple,
                    color: Colors.white,
                    size: 28,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Social login handling
  Future<void> _handleSocialLogin(String provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool success = false;
      OAuthProvider oauthProvider;
      
      // Determinar el proveedor OAuth
      switch (provider) {
        case 'google':
          oauthProvider = OAuthProvider.google;
          break;
          
        case 'facebook':
          oauthProvider = OAuthProvider.facebook;
          break;
          
        case 'apple':
          oauthProvider = OAuthProvider.apple;
          break;
          
        default:
          throw Exception(localizations.get('unsupported_provider'));
      }
      
      // Iniciar el flujo OAuth
      success = await _supabaseService.client.auth.signInWithOAuth(
        oauthProvider,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );

      // Verificar si el proceso de redirección OAuth comenzó correctamente
      if (success) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.get('redirect_to_complete_login')),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'No se pudo iniciar el proceso de autenticación con $provider';
        });
      }
    } catch (e) {
      setState(() {
       _errorMessage = '${localizations.get('auth_process_failed')} $provider';
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations.get('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Diálogo para recuperar contraseña
  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(localizations.get('recover_password')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizations.get('password_reset_instructions'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: localizations.get('email'),
                        prefixIcon: const Icon(Icons.email),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return localizations.get('please_enter_email');
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return localizations.get('enter_valid_email');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.get('cancel')),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() {
                        isLoading = true;
                      });
                      
                      try {
                        await _supabaseService.resetPassword(emailController.text.trim());
                        
                        // Cerrar el diálogo
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          
                          // Mostrar mensaje de éxito
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(localizations.get('password_reset_email_sent')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${localizations.get('error')}: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1980E6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(localizations.get('send')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}