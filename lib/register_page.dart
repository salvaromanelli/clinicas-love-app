import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/supabase.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; 
import 'utils/security_utils.dart';
import 'utils/secure_logger.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _supabaseService = SupabaseService();
  int _registerAttempts = 0;
  final int _maxRegisterAttempts = 5;

  
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _acceptDataProcessing = false;  // Para datos personales generales
  bool _acceptHealthDataProcessing = false;  // Específico para datos de salud
  bool _acceptMarketing = false;  // Opcional para comunicaciones de marketing
  String? _errorMessage;
  DateTime? _birthDate;
  bool _acceptTerms = false;
  late AppLocalizations localizations;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }

  Future<void> _registerWithEmail() async {
    if (_registerAttempts >= _maxRegisterAttempts) {
      setState(() {
        _errorMessage = localizations.get('too_many_attempts');
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

        // Validar que se haya seleccionado fecha de nacimiento
    if (_birthDate == null) {
      setState(() {
        _errorMessage = localizations.get('please_select_birth_date');
      });
      return;
    }
    
    if (!_acceptTerms) {
      setState(() {
        _errorMessage = localizations.get('terms_required');
      });
      return;
    }
    
    if (!_acceptTerms) {
      setState(() {
        _errorMessage = localizations.get('terms_required');
      });
      return;
    }

    // Después de la verificación de términos y condiciones
    if (!_acceptTerms) {
      setState(() {
        _errorMessage = localizations.get('terms_required');
      });
      return;
    }

    // Validar consentimiento para procesamiento de datos personales
    if (!_acceptDataProcessing) {
      setState(() {
        _errorMessage = localizations.get('personal_data_consent_required');
      });
      return;
    }

    // Validar consentimiento para procesamiento de datos de salud
    if (!_acceptHealthDataProcessing) {
      setState(() {
        _errorMessage = localizations.get('health_data_consent_required');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sanitizar todos los inputs antes de enviarlos
      final sanitizedEmail = SecurityUtils.sanitizeText(_emailController.text.trim());
      final sanitizedName = SecurityUtils.sanitizeText(_nameController.text.trim());
      final sanitizedPhone = SecurityUtils.sanitizeText(_phoneController.text.trim());
      // No sanitizamos la contraseña para no afectar su contenido
      final password = _passwordController.text;

      // Registrar usuario con datos sanitizados
      final response = await _supabaseService.signUp(
        email: sanitizedEmail,
        password: password,
        fullName: sanitizedName,
        phoneNumber: sanitizedPhone,
        birthDate: _birthDate,
        consent: {
          'terms_accepted': _acceptTerms,
          'data_processing': _acceptDataProcessing,
          'health_data': _acceptHealthDataProcessing,
          'marketing': _acceptMarketing,
          'consent_timestamp': DateTime.now().toIso8601String(),
          'consent_version': '1.0',
        }
      );
      
      if (!mounted) return;
      
      if (response.user != null) {
        // Si la autenticación es automática, ir a home
        if (response.session != null) {
          // Registro exitoso y sesión creada
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.get('registration_success'),
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.green,
            ),
          );
          SecurityUtils.navigateToSafely(context, '/home');
        } else {
          // Si requiere confirmación de email
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.get('email_verification_sent'),
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.blue,
            ),
          );
          SecurityUtils.navigateToSafely(context, '/login');
        }
      } else {
        setState(() {
          _errorMessage = 'Error al crear la cuenta. Intente nuevamente.';
        });
      }
      } on AuthException catch (e) {
        // Log seguro con detalles completos del error (para depuración)
        SecureLogger.log("Error de autenticación en registro: ${e.message}", sensitive: true);
        
        setState(() {
          // Mostrar al usuario solo mensajes controlados, no detalles técnicos
          if (e.message.contains("already registered")) {
            _errorMessage = localizations.get('email_already_registered');
          } else if (e.message.contains("weak password")) {
            _errorMessage = localizations.get('password_too_weak');
          } else if (e.message.contains("invalid email")) {
            _errorMessage = localizations.get('invalid_email_format');
          } else {
            _errorMessage = localizations.get('registration_error');
          }
        });
      } catch (e) {
        _registerAttempts++;
        
        // Log seguro con detalles completos del error (para depuración)
        SecureLogger.log("Error inesperado en registro: ${e.toString()}", sensitive: true);
        
        setState(() {
          // Mensaje genérico para el usuario (nunca mostrar el error real)
          _errorMessage = localizations.get('registration_error');
        });
    }
  }

  Future<void> _signInWithProvider(OAuthProvider provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabaseService.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.flutterquickstart://login-callback/',
      );
      // La redirección se maneja automáticamente
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${localizations.get('social_login_error')}: ${e.toString()}';
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
    
    return GestureDetector(
      // Ocultar teclado cuando se toca fuera de un campo de texto
      onTap: () => FocusScope.of(context).unfocus(),
      
      // Ocultar teclado cuando se desliza hacia abajo
      onVerticalDragDown: (_) => FocusScope.of(context).unfocus(),
      
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
            image: AssetImage('assets/images/Clinicas_love_fondo.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  children: [
                    // Logo y encabezado
                    Padding(
                      padding: EdgeInsets.only(top: 20.h, bottom: 30.h),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: isSmallScreen ? 60.h : 80.h,
                        ),
                      ),
                    ),
                    
                    // Título
                    Text(
                      localizations.get('create_account'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 20.sp : 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      localizations.get('fill_details'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 14.sp : 16.sp,
                      ),
                    ),
                    SizedBox(height: 32.h),
                    
                    // Formulario de registro
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Nombre completo
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.get('full_name'),
                              labelStyle: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 13.sp : 15.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.person, 
                                color: Colors.white70,
                                size: AdaptiveSize.getIconSize(context, baseSize: 22),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, 
                                vertical: isSmallScreen ? 12.h : 16.h,
                              ),
                              errorStyle: TextStyle(
                                fontSize: isSmallScreen ? 11.sp : 12.sp,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.get('please_enter_name');
                              }
                              
                              // Sanitizar para detectar intentos de XSS
                              final sanitizedValue = SecurityUtils.sanitizeText(value);
                              if (sanitizedValue != value) {
                                return localizations.get('invalid_characters_in_name');
                              }
                              
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          
                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.get('email'),
                              labelStyle: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 13.sp : 15.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.email, 
                                color: Colors.white70,
                                size: AdaptiveSize.getIconSize(context, baseSize: 22),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, 
                                vertical: isSmallScreen ? 12.h : 16.h,
                              ),
                              errorStyle: TextStyle(
                                fontSize: isSmallScreen ? 11.sp : 12.sp,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.get('please_enter_email');
                              }
                              
                              // Sanitizar valor para detectar inyecciones
                              final sanitizedValue = SecurityUtils.sanitizeText(value);
                              if (sanitizedValue != value) {
                                return localizations.get('invalid_characters_in_email');
                              }
                              
                              // Validación estricta de formato de email
                              if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                                return localizations.get('enter_valid_email');
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          
                          // Teléfono
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.get('phone'),
                              labelStyle: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 13.sp : 15.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.phone, 
                                color: Colors.white70,
                                size: AdaptiveSize.getIconSize(context, baseSize: 22),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, 
                                vertical: isSmallScreen ? 12.h : 16.h,
                              ),
                              errorStyle: TextStyle(
                                fontSize: isSmallScreen ? 11.sp : 12.sp,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.get('please_enter_phone');
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                                                    
                          // Selector de fecha de nacimiento
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000),
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.dark(
                                        primary: Color(0xFF1980E6),
                                        onPrimary: Colors.white,
                                        surface: Color(0xFF1C2126),
                                        onSurface: Colors.white,
                                      ),
                                      dialogBackgroundColor: const Color(0xFF1C2126),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              
                              if (picked != null) {
                                setState(() {
                                  _birthDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12.w),
                                border: Border.all(color: Colors.white70),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cake_outlined,
                                    color: Colors.white70,
                                    size: AdaptiveSize.getIconSize(context, baseSize: 22),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          localizations.get('birth_date'),
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: isSmallScreen ? 13.sp : 15.sp,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          _birthDate != null 
                                              ? "${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}"
                                              : localizations.get('select_date'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isSmallScreen ? 14.sp : 16.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                    size: AdaptiveSize.getIconSize(context, baseSize: 20),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.get('password'),
                              labelStyle: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 13.sp : 15.sp,
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, 
                                vertical: isSmallScreen ? 12.h : 16.h,
                              ),
                              errorStyle: TextStyle(
                                fontSize: isSmallScreen ? 11.sp : 12.sp,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.get('please_enter_password');
                              }
                              if (value.length < 6) {
                                return localizations.get('password_min_length');
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          
                          // Confirmar contraseña
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_confirmPasswordVisible,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: localizations.get('confirm_password'),
                              labelStyle: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 13.sp : 15.sp,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline, 
                                color: Colors.white70,
                                size: AdaptiveSize.getIconSize(context, baseSize: 22),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white70,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 22),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _confirmPasswordVisible = !_confirmPasswordVisible;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.w),
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w, 
                                vertical: isSmallScreen ? 12.h : 16.h,
                              ),
                              errorStyle: TextStyle(
                                fontSize: isSmallScreen ? 11.sp : 12.sp,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.get('please_confirm_password');
                              }
                              if (value != _passwordController.text) {
                                return localizations.get('passwords_dont_match');
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),

                          // Consentimiento para procesamiento de datos personales
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Theme(
                                data: ThemeData(
                                  checkboxTheme: CheckboxThemeData(
                                    fillColor: MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return Theme.of(context).colorScheme.primary;
                                        }
                                        return Colors.white70;
                                      },
                                    ),
                                  ),
                                ),
                                child: Transform.scale(
                                  scale: isSmallScreen ? 0.9 : 1.0,
                                  child: Checkbox(
                                    value: _acceptDataProcessing,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptDataProcessing = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 2.h),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isSmallScreen ? 12.sp : 14.sp,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: localizations.get('i_consent_personal_data'),
                                        ),
                                        TextSpan(
                                          text: ' ' + localizations.get('more_info'),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _showPersonalDataInfo();
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),

                          // Consentimiento para datos de salud
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Theme(
                                data: ThemeData(
                                  checkboxTheme: CheckboxThemeData(
                                    fillColor: MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return Theme.of(context).colorScheme.primary;
                                        }
                                        return Colors.white70;
                                      },
                                    ),
                                  ),
                                ),
                                child: Transform.scale(
                                  scale: isSmallScreen ? 0.9 : 1.0,
                                  child: Checkbox(
                                    value: _acceptHealthDataProcessing,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptHealthDataProcessing = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 2.h),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isSmallScreen ? 12.sp : 14.sp,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: localizations.get('i_consent_health_data'),
                                        ),
                                        TextSpan(
                                          text: ' ' + localizations.get('more_info'),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _showHealthDataInfo();
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          // Términos y condiciones
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Theme(
                                data: ThemeData(
                                  checkboxTheme: CheckboxThemeData(
                                    fillColor: MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                        if (states.contains(MaterialState.selected)) {
                                          return Theme.of(context).colorScheme.primary;
                                        }
                                        return Colors.white70;
                                      },
                                    ),
                                  ),
                                ),
                                child: Transform.scale(
                                  scale: isSmallScreen ? 0.9 : 1.0,
                                  child: Checkbox(
                                    value: _acceptTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptTerms = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 2.h),
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isSmallScreen ? 12.sp : 14.sp,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: localizations.get('i_accept') + ' ',
                                        ),
                                        TextSpan(
                                          text: localizations.get('terms_and_conditions'),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _showTermsAndConditions();
                                            },
                                        ),
                                        TextSpan(
                                          text: ' ' + localizations.get('and_the') + ' ',
                                        ),
                                        TextSpan(
                                          text: localizations.get('privacy_policy'),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              _showPrivacyPolicy();
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          
                          // Mensaje de error
                          if (_errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12.w),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          SizedBox(height: 24.h),
                          
                          // Botón de registro
                          SizedBox(
                            width: double.infinity,
                            height: isSmallScreen ? 48.h : 55.h,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registerWithEmail,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF1980E6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.w),
                                ),
                                disabledBackgroundColor: Colors.grey,
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10.h : 12.h),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.h,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.w,
                                      ),
                                    )
                                  : Text(
                                      localizations.get('register'),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14.sp : 16.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          
                          // Separador
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white60)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Text(
                                  localizations.get('or_register_with'), 
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white60)),
                            ],
                          ),

                          SizedBox(height: 24.h),
                          
                          // Botones de redes sociales (versión adaptativa)
                          Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            spacing: 8.w,
                            runSpacing: 12.h,
                            children: [
                              // Google
                              _socialButton(
                                onPressed: () => _signInWithProvider(OAuthProvider.google),
                                icon: 'assets/icons/google.svg',
                                label: 'Google',
                                backgroundColor: Colors.white,
                                textColor: Colors.black87,
                                isSmallScreen: isSmallScreen,
                              ),

                              // Apple
                              _socialButton(
                                onPressed: () => _signInWithProvider(OAuthProvider.apple),
                                icon: 'assets/icons/apple.svg',
                                label: 'Apple',
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                                isSmallScreen: isSmallScreen,
                              ),

                              // Facebook
                              _socialButton(
                                onPressed: () => _signInWithProvider(OAuthProvider.facebook),
                                icon: 'assets/icons/facebook.svg',
                                label: 'Facebook',
                                backgroundColor: const Color(0xFF1877F2),
                                textColor: Colors.white,
                                isSmallScreen: isSmallScreen,
                              ),
                            ],
                          ),
                          SizedBox(height: 32.h),
                          
                          // Link para iniciar sesión
                          RichText(
                            text: TextSpan(
                              text: localizations.get('already_have_account') + ' ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 13.sp : 15.sp,
                              ),
                              children: [
                                TextSpan(
                                  text: localizations.get('login'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      SecurityUtils.navigateToSafely(context, '/login');
                                    },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  // Botón de redes sociales adaptativo
  Widget _socialButton({
    required VoidCallback onPressed,
    required String icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required bool isSmallScreen,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12.w : 16.w, 
          vertical: isSmallScreen ? 10.h : 12.h,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.w),
        ),
        textStyle: TextStyle(
          fontSize: isSmallScreen ? 12.sp : 14.sp,
        ),
      ),
      icon: SvgPicture.asset(
        icon,
        height: isSmallScreen ? 16.h : 20.h,
        width: isSmallScreen ? 16.w : 20.w,
      ),
      label: Text(label),
    );
  }

  void _showPersonalDataInfo() {
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Sanitizar todos los textos
    final String dialogTitle = SecurityUtils.sanitizeText(localizations.get('personal_data_processing'));
    final String dataHeader = SecurityUtils.sanitizeText('INFORMACIÓN SOBRE PROCESAMIENTO DE DATOS PERSONALES');
    final String dataIntro = SecurityUtils.sanitizeText(
      'Clínicas Love recopilará y procesará sus datos personales como nombre, correo electrónico, teléfono y fecha de nacimiento con el fin de:'
    );
    final String dataPurposes = SecurityUtils.sanitizeText(
      '• Crear y gestionar su cuenta de usuario\n• Permitirle agendar citas\n• Comunicarnos con usted sobre nuestros servicios\n• Personalizar su experiencia en la aplicación'
    );
    final String dataStorage = SecurityUtils.sanitizeText(
      'Sus datos personales serán almacenados de forma segura y nunca se compartirán con terceros sin su consentimiento explícito.'
    );
    final String closeButton = SecurityUtils.sanitizeText(localizations.get('close'));
    
    showDialog(
      context: context,
      builder: (context) {
        AdaptiveSize.initialize(context);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.w),
          ),
          title: Text(
            dialogTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16.sp : 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dataHeader,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  dataIntro,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  dataPurposes,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  dataStorage,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.all(16.w),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1980E6),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              child: Text(
                closeButton,
                style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showHealthDataInfo() {
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Sanitizar todos los textos
    final String dialogTitle = SecurityUtils.sanitizeText(localizations.get('health_data_processing'));
    final String dataHeader = SecurityUtils.sanitizeText('INFORMACIÓN SOBRE PROCESAMIENTO DE DATOS DE SALUD');
    final String dataIntro = SecurityUtils.sanitizeText(
      'Clínicas Love recopilará y procesará información relacionada con su salud como:'
    );
    final String dataTypes = SecurityUtils.sanitizeText(
      '• Fotografías para simulación de tratamientos\n• Historial de tratamientos estéticos\n• Condiciones médicas relevantes para tratamientos\n• Preferencias de tratamientos'
    );
    final String dataPurposes = SecurityUtils.sanitizeText(
      'Esta información sensible se utiliza únicamente para:\n• Personalizar recomendaciones de tratamientos\n• Crear simulaciones visuales de resultados\n• Permitir a nuestros especialistas ofrecer un mejor servicio'
    );
    final String dataSecurity = SecurityUtils.sanitizeText(
      'Sus datos de salud están protegidos con medidas de seguridad adicionales y solo son accesibles para el personal médico autorizado.'
    );
    final String closeButton = SecurityUtils.sanitizeText(localizations.get('close'));
    
    showDialog(
      context: context,
      builder: (context) {
        AdaptiveSize.initialize(context);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.w),
          ),
          title: Text(
            dialogTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16.sp : 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dataHeader,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  dataIntro,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  dataTypes,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  dataPurposes,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  dataSecurity,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.all(16.w),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1980E6),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              child: Text(
                closeButton,
                style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
              ),
            ),
          ],
        );
      },
    );
  }

  // Diálogo de términos y condiciones adaptativo
  void _showTermsAndConditions() {
    // Inicializar AdaptiveSize para el diálogo
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Sanitizar todos los textos estáticos
    final String termsTitle = SecurityUtils.sanitizeText(localizations.get('terms_title'));
    final String termsHeader = SecurityUtils.sanitizeText('TÉRMINOS Y CONDICIONES DE USO');
    final String termsIntro = SecurityUtils.sanitizeText(
      'Al utilizar la aplicación de Clínicas Love, usted acepta estos términos y condiciones en su totalidad. Si no está de acuerdo con estos términos y condiciones o cualquier parte de estos términos y condiciones, no debe utilizar esta aplicación.'
    );
    final String privacyTitle = SecurityUtils.sanitizeText('1. PRIVACIDAD DE LOS DATOS');
    final String privacyText = SecurityUtils.sanitizeText(
      'Nos comprometemos a proteger la privacidad de los usuarios. La información personal recopilada se utilizará únicamente para los fines específicos relacionados con los servicios ofrecidos por Clínicas Love.'
    );
    final String servicesTitle = SecurityUtils.sanitizeText('2. SERVICIOS OFRECIDOS');
    final String servicesText = SecurityUtils.sanitizeText(
      'Nuestra aplicación ofrece servicios de información, comunicación y coordinación con nuestras clínicas estéticas. No ofrecemos diagnósticos médicos ni recomendaciones de tratamiento a través de la aplicación sin una consulta previa presencial.'
    );
    final String liabilityTitle = SecurityUtils.sanitizeText('3. LIMITACIONES DE RESPONSABILIDAD');
    final String liabilityText = SecurityUtils.sanitizeText(
      'Clínicas Love no se hace responsable de cualquier daño que pueda resultar del uso incorrecto de la aplicación o de la interpretación incorrecta de la información proporcionada a través de ella.'
    );
    final String closeButton = SecurityUtils.sanitizeText(localizations.get('close'));
    
    showDialog(
      context: context,
      builder: (context) {
        // Reinicializar AdaptiveSize dentro del builder del diálogo
        AdaptiveSize.initialize(context);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.w),
          ),
          title: Text(
            termsTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16.sp : 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  termsHeader,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  termsIntro,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  privacyTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  privacyText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  servicesTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  servicesText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  liabilityTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  liabilityText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.all(16.w),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1980E6),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              child: Text(
                closeButton,
                style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
              ),
            ),
          ],
        );
      },
    );
  }

  // Diálogo de política de privacidad adaptativo
  void _showPrivacyPolicy() {
    // Inicializar AdaptiveSize para el diálogo
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Sanitizar todos los textos estáticos
    final String policyTitle = SecurityUtils.sanitizeText(localizations.get('privacy_policy_title'));
    final String policyHeader = SecurityUtils.sanitizeText('POLÍTICA DE PRIVACIDAD');
    final String policyIntro = SecurityUtils.sanitizeText(
      'En Clínicas Love, nos comprometemos a proteger y respetar su privacidad. Esta Política de Privacidad describe cómo recopilamos, utilizamos y compartimos su información personal.'
    );
    final String dataTitle = SecurityUtils.sanitizeText('1. INFORMACIÓN QUE RECOPILAMOS');
    final String dataText = SecurityUtils.sanitizeText(
      'Recopilamos información personal como su nombre, dirección de correo electrónico, número de teléfono e historial médico relevante para los servicios que ofrecemos.'
    );
    final String useTitle = SecurityUtils.sanitizeText('2. CÓMO UTILIZAMOS SU INFORMACIÓN');
    final String useText = SecurityUtils.sanitizeText(
      'Utilizamos su información para proporcionar los servicios solicitados, comunicarnos con usted sobre citas y tratamientos, y mejorar nuestros servicios.'
    );
    final String shareTitle = SecurityUtils.sanitizeText('3. COMPARTIR INFORMACIÓN');
    final String shareText = SecurityUtils.sanitizeText(
      'No compartimos su información con terceros excepto con proveedores de servicios que nos ayudan a operar nuestra aplicación y servicios, o según lo requiera la ley.'
    );
    final String closeButton = SecurityUtils.sanitizeText(localizations.get('close'));
    
    showDialog(
      context: context,
      builder: (context) {
        // Reinicializar AdaptiveSize dentro del builder del diálogo
        AdaptiveSize.initialize(context);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.w),
          ),
          title: Text(
            policyTitle,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 16.sp : 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policyHeader,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  policyIntro,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  dataTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  dataText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  useTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  useText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  shareTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  shareText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
              ],
            ),
          ),
          contentPadding: EdgeInsets.all(16.w),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1980E6),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              ),
              child: Text(
                closeButton,
                style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
              ),
            ),
          ],
        );
      },
    );
  }
}