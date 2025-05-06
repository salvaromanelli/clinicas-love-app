import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/supabase.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; 

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

  
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Registrar usuario con Supabase
      final response = await _supabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        birthDate: _birthDate,
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
          Navigator.pushReplacementNamed(context, '/home');
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
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        setState(() {
          _errorMessage = 'Error al crear la cuenta. Intente nuevamente.';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
                                      Navigator.pushReplacementNamed(context, '/login');
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

  // Diálogo de términos y condiciones adaptativo
  void _showTermsAndConditions() {
    // Inicializar AdaptiveSize para el diálogo
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
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
            localizations.get('terms_title'),
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
                  'TÉRMINOS Y CONDICIONES DE USO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Al utilizar la aplicación de Clínicas Love, usted acepta estos términos y condiciones en su totalidad. Si no está de acuerdo con estos términos y condiciones o cualquier parte de estos términos y condiciones, no debe utilizar esta aplicación.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  '1. PRIVACIDAD DE LOS DATOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  'Nos comprometemos a proteger la privacidad de los usuarios. La información personal recopilada se utilizará únicamente para los fines específicos relacionados con los servicios ofrecidos por Clínicas Love.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '2. SERVICIOS OFRECIDOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  'Nuestra aplicación ofrece servicios de información, comunicación y coordinación con nuestras clínicas estéticas. No ofrecemos diagnósticos médicos ni recomendaciones de tratamiento a través de la aplicación sin una consulta previa presencial.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '3. LIMITACIONES DE RESPONSABILIDAD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  'Clínicas Love no se hace responsable de cualquier daño que pueda resultar del uso incorrecto de la aplicación o de la interpretación incorrecta de la información proporcionada a través de ella.',
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
                localizations.get('close'),
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
            localizations.get('privacy_policy_title'),
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
                  'POLÍTICA DE PRIVACIDAD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'En Clínicas Love, nos comprometemos a proteger y respetar su privacidad. Esta Política de Privacidad describe cómo recopilamos, utilizamos y compartimos su información personal.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  '1. INFORMACIÓN QUE RECOPILAMOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  'Recopilamos información personal como su nombre, dirección de correo electrónico, número de teléfono e historial médico relevante para los servicios que ofrecemos.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '2. CÓMO UTILIZAMOS SU INFORMACIÓN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  'Utilizamos su información para proporcionar los servicios solicitados, comunicarnos con usted sobre citas y tratamientos, y mejorar nuestros servicios.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '3. COMPARTIR INFORMACIÓN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.sp : 15.sp,
                  ),
                ),
                Text(
                  'No compartimos su información con terceros excepto con proveedores de servicios que nos ayudan a operar nuestra aplicación y servicios, o según lo requiera la ley.',
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
                localizations.get('close'),
                style: TextStyle(fontSize: isSmallScreen ? 13.sp : 14.sp),
              ),
            ),
          ],
        );
      },
    );
  }
}