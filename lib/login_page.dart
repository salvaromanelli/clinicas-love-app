import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase.dart';

class LoginPage extends StatefulWidget {
  final Widget child;
  const LoginPage({super.key, required this.child});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabaseService = SupabaseService();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 32.0),
                          const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          const Text(
                            'Bienvenido a Clínicas Love',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 32.0),
                          
                          // Email field with icon
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
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
                          ),
                          const SizedBox(height: 16.0),
                          
                          // Password field with toggle visibility
                          TextField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
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
                            obscureText: !_passwordVisible,
                            style: const TextStyle(color: Colors.white),
                          ),
                          
                          // Forgot password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(color: Colors.white70),
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
                                  : const Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(
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
                            children: const [
                              Expanded(child: Divider(color: Colors.white24)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'O continúa con',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white24)),
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
                              child: const Text(
                                '¿No tienes cuenta? Regístrate',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ],
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

  // Login with email and password
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      // Validación básica
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Por favor complete todos los campos');
      }

      // Iniciar sesión con Supabase
      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Guardar el token de sesión
        final token = await _supabaseService.getToken();
        await _storage.write(key: 'auth_token', value: token);
        
        if (!mounted) return;
        
        // Navegar a la página principal
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorMessage = 'Error de autenticación. Por favor verifique sus credenciales.';
        });
      }
    } catch (e) {
      // Manejo más amigable de errores comunes de Supabase
      String errorMsg;
      
      if (e.toString().contains('Invalid login credentials')) {
        errorMsg = 'Email o contraseña incorrectos';
      } else if (e.toString().contains('Email not confirmed')) {
        errorMsg = 'Por favor confirma tu email antes de iniciar sesión';
      } else if (e.toString().contains('network')) {
        errorMsg = 'Error de conexión. Verifica tu internet';
      } else {
        errorMsg = 'Error: ${e.toString()}';
      }
      
      setState(() {
        _errorMessage = errorMsg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// Reemplaza el método _handleSocialLogin completo

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
        throw Exception('Proveedor no soportado');
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
        const SnackBar(
          content: Text('Serás redirigido para completar el inicio de sesión'),
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
      _errorMessage = 'Error al iniciar sesión con $provider: ${e.toString()}';
    });
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
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
              title: const Text('Recuperar Contraseña'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Te enviaremos un email con instrucciones para restablecer tu contraseña.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu correo electrónico';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Ingresa un correo electrónico válido';
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
                  child: const Text('Cancelar'),
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
                            const SnackBar(
                              content: Text('Se ha enviado un correo para restablecer tu contraseña'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
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
                      : const Text('Enviar'),
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