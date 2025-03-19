import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'services/supabase.dart';
import 'i18n/app_localizations.dart';

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
      );
      
      if (!mounted) return;
      
      if (response.user != null) {
        // Si la autenticación es automática, ir a home
        if (response.session != null) {
          // Registro exitoso y sesión creada
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('registration_success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // Si requiere confirmación de email
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('email_verification_sent')),
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
    return Scaffold(
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Logo y encabezado
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0, bottom: 30.0),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 80.0,
                        ),
                      ),
                    ),
                    
                    // Título
                    Text(
                      localizations.get('create_account'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      localizations.get('fill_details'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16.0,
                      ),
                    ),
                    const SizedBox(height: 32.0),
                    
                    // Formulario de registro
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Nombre completo
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: localizations.get('full_name'),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.person, color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                            ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations.get('please_enter_name');
                                }
                                return null;
                              },
                            ),
                          const SizedBox(height: 16.0),
                          
                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: localizations.get('email'),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.email, color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
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
                          const SizedBox(height: 16.0),
                          
                          // Teléfono
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: localizations.get('phone'),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.phone, color: Colors.white70),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localizations.get('please_enter_phone');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16.0),
                          
                          // Contraseña
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_passwordVisible,
                            style: const TextStyle(color: Colors.white),
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
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
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
                          const SizedBox(height: 16.0),
                          
                          // Confirmar contraseña
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_confirmPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: localizations.get('confirm_password'),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _confirmPasswordVisible = !_confirmPasswordVisible;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.white70),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Colors.red),
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
                          const SizedBox(height: 16.0),
                          
                          // Términos y condiciones
                          Row(
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
                                child: Checkbox(
                                  value: _acceptTerms,
                                  onChanged: (value) {
                                    setState(() {
                                      _acceptTerms = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(color: Colors.white70),
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
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          
                          // Mensaje de error
                          if (_errorMessage != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: 24.0),
                          
                          // Botón de registro
                          SizedBox(
                            width: double.infinity,
                            height: 55.0,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registerWithEmail,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF1980E6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      localizations.get('register'),
                                      style: const TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          
                          // Separador
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Colors.white60)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(localizations.get('or_register_with'), style: const TextStyle(color: Colors.white70)),
                              ),
                              const Expanded(child: Divider(color: Colors.white60)),
                            ],
                          ),

                          const SizedBox(height: 24.0),
                          
                          // Botones de redes sociales
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Google
                              _socialButton(
                                onPressed: () => _signInWithProvider(OAuthProvider.google),
                                icon: 'assets/icons/google.svg',
                                label: 'Google',
                                backgroundColor: Colors.white,
                                textColor: Colors.black87,
                              ),

                              _socialButton(
                                onPressed: () => _signInWithProvider(OAuthProvider.apple),
                                icon: 'assets/icons/apple.svg',
                                label: 'Apple',
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                              ),

                              _socialButton(
                                onPressed: () => _signInWithProvider(OAuthProvider.facebook),
                                icon: 'assets/icons/facebook.svg',
                                label: 'Facebook',
                                backgroundColor: const Color(0xFF1877F2),
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                          const SizedBox(height: 32.0),
                          
                          // Link para iniciar sesión
                          RichText(
                            text: TextSpan(
                              text: localizations.get('already_have_account') + ' ',
                              style: const TextStyle(color: Colors.white70),
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
                          const SizedBox(height: 24.0),
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
    );
  }

  Widget _socialButton({
    required VoidCallback onPressed,
    required String icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: textColor,
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      icon: SvgPicture.asset(
        icon,
        height: 20.0,
        width: 20.0,
      ),
      label: Text(label),
    );
  }

  void _showTermsAndConditions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.get('terms_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'TÉRMINOS Y CONDICIONES DE USO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'Al utilizar la aplicación de Clínicas Love, usted acepta estos términos y condiciones en su totalidad. Si no está de acuerdo con estos términos y condiciones o cualquier parte de estos términos y condiciones, no debe utilizar esta aplicación.',
              ),
              SizedBox(height: 16),
              Text(
                '1. PRIVACIDAD DE LOS DATOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Nos comprometemos a proteger la privacidad de los usuarios. La información personal recopilada se utilizará únicamente para los fines específicos relacionados con los servicios ofrecidos por Clínicas Love.',
              ),
              SizedBox(height: 8),
              Text(
                '2. SERVICIOS OFRECIDOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Nuestra aplicación ofrece servicios de información, comunicación y coordinación con nuestras clínicas estéticas. No ofrecemos diagnósticos médicos ni recomendaciones de tratamiento a través de la aplicación sin una consulta previa presencial.',
              ),
              SizedBox(height: 8),
              Text(
                '3. LIMITACIONES DE RESPONSABILIDAD',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Clínicas Love no se hace responsable de cualquier daño que pueda resultar del uso incorrecto de la aplicación o de la interpretación incorrecta de la información proporcionada a través de ella.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.get('close')),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.get('privacy_policy_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'POLÍTICA DE PRIVACIDAD',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'En Clínicas Love, nos comprometemos a proteger y respetar su privacidad. Esta Política de Privacidad describe cómo recopilamos, utilizamos y compartimos su información personal.',
              ),
              SizedBox(height: 16),
              Text(
                '1. INFORMACIÓN QUE RECOPILAMOS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Recopilamos información personal como su nombre, dirección de correo electrónico, número de teléfono e historial médico relevante para los servicios que ofrecemos.',
              ),
              SizedBox(height: 8),
              Text(
                '2. CÓMO UTILIZAMOS SU INFORMACIÓN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Utilizamos su información para proporcionar los servicios solicitados, comunicarnos con usted sobre citas y tratamientos, y mejorar nuestros servicios.',
              ),
              SizedBox(height: 8),
              Text(
                '3. COMPARTIR INFORMACIÓN',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'No compartimos su información con terceros excepto con proveedores de servicios que nos ayudan a operar nuestra aplicación y servicios, o según lo requiera la ley.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.get('close')),
          ),
        ],
      ),
    );
  }
}