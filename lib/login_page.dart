import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase.dart';
import 'services/auth_service.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; 

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }

  // Método de login principal
  Future<void> _handleLogin() async {
    // Validación del formulario
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        final token = await _supabaseService.getToken();
        if (token != null) {
          await _authService.saveToken(token);
          
          if (!mounted) return;
          
          print("Inicio de sesión exitoso, token: ${token.substring(0, min(10, token.length))}...");
          print("Redirigiendo a página de perfil...");
          
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

  // Método para manejar la autenticación con redes sociales
  Future<void> _handleSocialLogin(String provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      AuthResponse? response;
      
      // Determinar el proveedor y llamar al método correspondiente
      switch (provider) {
        case 'google':
          // Mostrar mensaje provisional mientras implementas la funcionalidad completa
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Inicio de sesión con Google aún no implementado',
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          break;
          
        case 'facebook':
          // Mostrar mensaje provisional para Facebook
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Inicio de sesión con Facebook aún no implementado',
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          break;
          
        case 'apple':
          // Mostrar mensaje provisional para Apple
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Inicio de sesión con Apple aún no implementado',
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.orange.shade700,
            ),
          );
          break;
          
        default:
          throw Exception('Proveedor desconocido: $provider');
      }
      
      /* 
      // Código para implementar después cuando estén listos los métodos en SupabaseService
      
      // Verificar respuesta y manejar sesión
      if (response?.user != null) {
        final token = await _supabaseService.getToken();
        if (token != null) {
          await _authService.saveToken(token);
          
          if (!mounted) return;
          
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/profile', 
            (route) => false
          );
        } else {
          throw Exception(localizations.get('auth_token_error'));
        }
      } else {
        throw Exception(localizations.get('social_auth_error'));
      }
      */
      
    } catch (e) {
      String errorMsg;
      
      if (e.toString().contains('canceled') || e.toString().contains('cancelado')) {
        errorMsg = localizations.get('auth_cancelled') ?? 'Autenticación cancelada';
      } else if (e.toString().contains('network')) {
        errorMsg = localizations.get('network_error') ?? 'Error de red';
      } else {
        errorMsg = '${localizations.get('error') ?? 'Error'}: ${e.toString()}';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize para dimensiones responsivas
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
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
                  // Header con botón atrás y logo
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: AdaptiveSize.getIconSize(context, baseSize: 20),
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
                                height: isSmallScreen ? 50.h : 60.h,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 48.w),
                      ],
                    ),
                  ),
                  
                  // Contenido del formulario
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 32.h),
                            Text(
                              localizations.get('login'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 24.sp : 28.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              localizations.get('welcome_to_clinics'),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                              ),
                            ),
                            SizedBox(height: 32.h),
                            
                            // Campo de email con icono
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: localizations.get('email'),
                                labelStyle: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSmallScreen ? 14.sp : 16.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.email, 
                                  color: Colors.white70,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 22),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                              ),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                              ),
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
                            SizedBox(height: 16.h),
                            
                            // Campo de contraseña con toggle
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: localizations.get('password'),
                                labelStyle: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSmallScreen ? 14.sp : 16.sp,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock, 
                                  color: Colors.white70,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 22),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.white70,
                                    size: AdaptiveSize.getIconSize(context, baseSize: 22),
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                              ),
                            ),
                            
                            // Enlace de olvidé contraseña
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, 
                                    vertical: 4.h
                                  ),
                                ),
                                child: Text(
                                  localizations.get('forgot_password'),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Mensaje de error
                            if (_errorMessage != null)
                              Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: isSmallScreen ? 13.sp : 14.sp,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            
                            SizedBox(height: 24.h),
                            
                            // Botón de login
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1980E6),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.w),
                                  ),
                                  disabledBackgroundColor: Colors.grey,
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20.h,
                                        width: 20.w,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        localizations.get('login'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            
                            SizedBox(height: 24.h),
                            
                            // Divisor "O"
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.white24)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Text(
                                    localizations.get('or_continue_with'),
                                    style: TextStyle(
                                      color: Colors.white70, 
                                      fontSize: isSmallScreen ? 11.sp : 12.sp,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.white24)),
                              ],
                            ),
                            
                            SizedBox(height: 24.h),
                            
                            // Botones de redes sociales
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildSocialButton(
                                  onPressed: () => _handleSocialLogin('google'),
                                  iconPath: 'assets/images/google_icon.png',
                                  label: 'Google',
                                  isSmallScreen: isSmallScreen,
                                ),
                                _buildSocialButton(
                                  onPressed: () => _handleSocialLogin('facebook'),
                                  iconPath: 'assets/images/facebook_icon.png',
                                  label: 'Facebook',
                                  isSmallScreen: isSmallScreen,
                                ),
                                _buildSocialButton(
                                  onPressed: () => _handleSocialLogin('apple'),
                                  iconPath: 'assets/images/apple_icon.png',
                                  label: 'Apple',
                                  isSmallScreen: isSmallScreen,
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 24.h),
                            
                            // Enlace de registro
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/register');
                                },
                                child: Text(
                                  localizations.get('no_account_register'),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isSmallScreen ? 13.sp : 14.sp,
                                  ),
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

  // Widget de botón de red social adaptativo
  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required String iconPath,
    required String label,
    required bool isSmallScreen,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: isSmallScreen ? 50.w : 60.w,
            height: isSmallScreen ? 50.h : 60.h,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.w),
              border: Border.all(color: Colors.white24),
            ),
            child: Center(
              child: Image.asset(
                iconPath,
                height: isSmallScreen ? 24.h : 28.h,
                width: isSmallScreen ? 24.w : 28.w,
                errorBuilder: (context, error, stackTrace) {
                  // Icono de respaldo
                  return Icon(
                    label == 'Google' ? Icons.g_mobiledata : 
                    label == 'Facebook' ? Icons.facebook : 
                    Icons.apple,
                    color: Colors.white,
                    size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 24 : 28),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70, 
              fontSize: isSmallScreen ? 11.sp : 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  // Diálogo de olvido de contraseña adaptativo
  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;

    showDialog(
      context: context,
      builder: (context) {
        // Reinicializar AdaptiveSize dentro del diálogo
        AdaptiveSize.initialize(context);
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2126),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.w)),
              title: Text(
                localizations.get('recover_password'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 18.sp : 20.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizations.get('password_reset_instructions'),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.sp : 14.sp,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14.sp : 15.sp,
                      ),
                      decoration: InputDecoration(
                        labelText: localizations.get('email'),
                        labelStyle: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 14.sp : 15.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.email,
                          size: AdaptiveSize.getIconSize(context, baseSize: 22),
                          color: Colors.white70,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.w),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.w),
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.w),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF262A33),
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
              contentPadding: EdgeInsets.all(16.w),
              actionsPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w, 
                      vertical: 8.h,
                    ),
                  ),
                  child: Text(
                    localizations.get('cancel'),
                    style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() {
                        isLoading = true;
                      });
                      
                      try {
                        await _supabaseService.resetPassword(emailController.text.trim());
                        
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                localizations.get('password_reset_email_sent'),
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              backgroundColor: Colors.green.shade700,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${localizations.get('error')}: ${e.toString()}',
                              style: TextStyle(fontSize: 14.sp),
                            ),
                            backgroundColor: Colors.red.shade700,
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          localizations.get('send'),
                          style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
                        ),
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