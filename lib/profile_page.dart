import 'package:flutter/material.dart';
import 'models/profile_model.dart';
import 'services/profile_service.dart';
import 'services/auth_service.dart';
import 'edit_profile_page.dart';
import 'providers/language_provider.dart';
import 'i18n/app_localizations.dart';
import 'package:provider/provider.dart'; 
import 'providers/user_provider.dart';
import 'services/supabase.dart';
import 'utils/adaptive_sizing.dart';
import 'services/analytics_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:share_plus/share_plus.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();  
  final SupabaseService _supabaseService = SupabaseService();
  Profile? _profile;
  bool _isLoading = true;
  late AppLocalizations localizations; 

@override
void initState() {
  super.initState();
  AnalyticsService().logPageView('profile_page');
  _loadProfile();
  
  // Registrar cuando el usuario entra a la página de perfil
  final currentUser = _supabaseService.client.auth.currentUser;
  if (currentUser != null) {
    try {
      // Convertir createdAt de String a DateTime
      final DateTime createdAtDate = DateTime.parse(currentUser.createdAt);
      
      AnalyticsService().logInteraction('profile_page_entered', {
        'user_registered_days': DateTime.now().difference(createdAtDate).inDays,
        // CAMBIO AQUÍ: usar lastSignInAt directamente sin convertir
        'last_sign_in': currentUser.lastSignInAt,
      });
    } catch (e) {
      // Registrar sin el campo calculado en caso de error
      AnalyticsService().logInteraction('profile_page_entered', {
        'last_sign_in': currentUser.lastSignInAt,
        'parse_error': e.toString(),
      });
      debugPrint('Error al convertir fecha de creación: $e');
    }
  }
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  localizations = AppLocalizations.of(context);
}

  Future<void> _loadProfile() async {
    try {
      print("Cargando perfil de usuario...");
      setState(() {
        _isLoading = true;
      });
      
      final token = await _authService.getToken();
      print("Token obtenido: ${token != null ? 'Sí' : 'No'}");
      
      if (token == null) {
        print("No hay token, redirigiendo a login...");
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      
      // Usar ProfileService para obtener el perfil usando Supabase
      final profile = await _profileService.getProfile(token);
      
      if (profile != null) {
        print("Perfil cargado: ${profile.name}");
        setState(() {
          _profile = profile;
          _isLoading = false;
        });

        // Registrar análisis de completitud de perfil
      AnalyticsService().logInteraction('profile_loaded', {
        'profile_completion': _calculateProfileCompletion(),
        'has_consents': profile.consents != null,
      });
    
      } else {
        print("No se encontró perfil, redirigiendo a login");
        if (!mounted) return;
        // Opcional: mostrar un mensaje antes de redirigir
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró tu perfil. Por favor vuelve a iniciar sesión.'),
            backgroundColor: Colors.orange,
          ),
        );
        // Permitir que el usuario vea el mensaje antes de redirigir
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print("Error al cargar perfil: $e");
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar perfil: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    AdaptiveSize.initialize(context);

    final isSmallScreen = AdaptiveSize.screenWidth < 360; 


    
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Back arrow and title
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: AdaptiveSize.getIconSize(context, baseSize: 20),
                          ),
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/home', arguments: {'tabIndex': 1});
                          },
                        ),
                        Text(
                          localizations.get('profile'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18.sp : 20.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                SizedBox(height: 24.h),
                // Profile section
                Row(
                  children: [
                  Container(
                    width: isSmallScreen ? 70.w : 80.w,
                    height: isSmallScreen ? 70.h : 80.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.w,
                      ),
                    ),
                    child: ClipOval(
                      child: _profile?.avatarUrl != null
                        ? Image.network(
                              _profile!.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              size: AdaptiveSize.getIconSize(context, baseSize: 40),
                              color: Colors.white,
                            ),
                      ),
                    ),
                    SizedBox(width: 16.w), 
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profile?.name ?? 'Loading...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 16.sp : 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _profile?.location ?? 'No location',
                            style: TextStyle(
                              color: const Color(0xFF9DABB8),
                              fontSize: isSmallScreen ? 12.sp : 14.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),

                // Menu items
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildMenuItem(localizations.get('contact_information')), // Traducción
                        _buildMenuItem(localizations.get('payment_methods')), // Traducción
                        
                        // Opción de idioma
                        _buildMenuItem(
                          localizations.get('language'), // Traducción  
                          badge: Provider.of<LanguageProvider>(context)
                                .getLanguageName(Provider.of<LanguageProvider>(context)
                                .currentLocale.languageCode),
                          withBadge: true
                        ),
                        
                        _buildMenuItem(localizations.get('my_wishlist')), // Traducción
                        _buildMenuItem(localizations.get('favorites')), // Traducción
                        _buildMenuItem(localizations.get('my_reviews')), // Traducción
                        _buildMenuItem(localizations.get('gift_cards')), // Traducción
                        // Añadir un separador visual para la sección de privacidad
                        SizedBox(height: 24.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFF2A2F37), width: 1.w),
                              bottom: BorderSide(color: Color(0xFF2A2F37), width: 1.w),
                            ),
                          ),
                          child: Text(
                            localizations.get('privacy_and_data'),
                            style: TextStyle(
                              color: Color(0xFF9DABB8),
                              fontSize: isSmallScreen ? 12.sp : 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),

                        // Opciones de privacidad y datos personales usando el método _buildMenuItem existente
                        _buildMenuItem(localizations.get('download_my_data')),
                        _buildMenuItem(localizations.get('manage_consents')),
                        _buildMenuItem(
                          localizations.get('delete_account'),
                          withBadge: true,
                          badge: "⚠️",
                        ),
                      ],
                    ),
                  ),
                ),
                // Logout button
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                      onPressed: _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C2126),
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12.h : 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.w),
                        ),
                      ),
                      child: Text(
                        localizations.get('logout'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

  Future<void> _handleLogout() async {
    try {
      // Calcular la duración aproximada de la sesión
      final currentUser = _supabaseService.client.auth.currentUser;
      final lastSignInAt = currentUser?.lastSignInAt;
      int sessionDurationMinutes = 0;
      
      if (lastSignInAt != null) {
        try {
          // Convertir el string a DateTime
          final DateTime lastSignInDateTime = DateTime.parse(lastSignInAt);
          sessionDurationMinutes = DateTime.now().difference(lastSignInDateTime).inMinutes;
        } catch (e) {
          debugPrint('Error al convertir fecha de último inicio de sesión: $e');
          // En caso de error, dejar sessionDurationMinutes en 0
        }
      }
      
      // Registrar evento de cierre de sesión
      AnalyticsService().logInteraction('user_logout', {
        'user_id': currentUser?.id,
        'session_duration_minutes': sessionDurationMinutes,
        'profile_completion': _calculateProfileCompletion(),
      });
      
      // Resto de tu código existente
      Provider.of<UserProvider>(context, listen: false).logout();
      await SupabaseService().signOut();
      await AuthService().logout(context: context);
      
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      debugPrint('❌ Error en logout: $e');
    }
  }

  // Método para calcular completitud del perfil
  double _calculateProfileCompletion() {
    if (_profile == null) return 0.0;
    
    int totalFields = 6; // Nombre, ubicación, email, avatar, teléfono, etc.
    int completedFields = 0;
    
    if (_profile!.name?.isNotEmpty ?? false) completedFields++;
    if (_profile!.location?.isNotEmpty ?? false) completedFields++;
    if (_profile!.email?.isNotEmpty ?? false) completedFields++;
    if (_profile!.avatarUrl?.isNotEmpty ?? false) completedFields++;
    if (_profile!.phone?.isNotEmpty ?? false) completedFields++;
    // Añade más campos según tu modelo de Profile
    
    return (completedFields / totalFields) * 100;
  }
  
  // _buildMenuItem method
  Widget _buildMenuItem(String title, {String? badge, bool withBadge = false}) {

    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    return GestureDetector(
      onTap: () async {
        
        // Registrar la interacción con el elemento del menú
        AnalyticsService().logInteraction('menu_item_clicked', {
          'menu_item': title,
          'user_id': _supabaseService.client.auth.currentUser?.id,
        });

        // Usar las claves de traducción para manejar la navegación
        if (title == localizations.get('contact_information')) {
          final updatedProfile = await Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => EditProfilePage(profile: _profile!),
            )
          );
          
          if (updatedProfile != null) {
            setState(() {
              _profile = updatedProfile;
            });

           // Registrar finalización de edición de perfil
            AnalyticsService().logInteraction('edit_profile_completed', {
              'profile_completion_after': _calculateProfileCompletion(),
              'fields_changed': _getChangedFields(_profile!, updatedProfile),
            });
          }
        } 
        else if (title == localizations.get('language')) {
          Navigator.pushNamed(context, '/language-settings');
        }
        else if (title == localizations.get('payment_methods')) {
          Navigator.pushNamed(context, '/payment-methods');
        }
        else if (title == localizations.get('my_wishlist')) {
          Navigator.pushNamed(context, '/wishlist');
        }
        else if (title == localizations.get('favorites')) {
          Navigator.pushNamed(context, '/favorites');
        }
        else if (title == localizations.get('my_reviews')) {
          Navigator.pushNamed(context, '/reviews');
        }
        else if (title == localizations.get('gift_cards')) {
          Navigator.pushNamed(context, '/gift-cards');
        }
        else if (title == localizations.get('download_my_data')) {
          _downloadPersonalData();
        }
        else if (title == localizations.get('manage_consents')) {
          _showConsentManager();
        }
        else if (title == localizations.get('delete_account')) {
          _showDeleteAccountConfirmation();
        }
      },
      child: Container(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12.h : 16.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF2A2F37),
            width: 1.w,
          ),
        ),
      ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14.sp : 16.sp,
              ),
            ),
            if (title == localizations.get('my_reviews')) 
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w, 
                      vertical: isSmallScreen ? 1.h : 2.h
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1980E6),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Text(
                      '15% OFF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10.sp : 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.chevron_right,
                    color: Color(0xFF9DABB8),
                    size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 20 : 24),
                  ),
                ],
              )
            else if (withBadge && badge != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w, 
                      vertical: isSmallScreen ? 1.h : 2.h
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1980E6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: Color(0xFF1980E6),
                        fontSize: isSmallScreen ? 10.sp : 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.chevron_right,
                    color: Color(0xFF9DABB8),
                    size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 20 : 24),
                  ),
                ],
              )
            else
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9DABB8),
              ),
          ],
        ),
      ),
    );
  }
  // Método para detectar qué campos se cambiaron en el perfil
  Map<String, bool> _getChangedFields(Profile oldProfile, Profile newProfile) {
    Map<String, bool> changedFields = {};
    
    changedFields['name'] = oldProfile.name != newProfile.name;
    changedFields['location'] = oldProfile.location != newProfile.location;
    changedFields['avatar'] = oldProfile.avatarUrl != newProfile.avatarUrl;
    changedFields['email'] = oldProfile.email != newProfile.email;
    changedFields['phone'] = oldProfile.phone != newProfile.phone;
    // Añade más campos según tu modelo
    
    return changedFields;
    
  }

  // Método para crear botones de privacidad con estilo unificado
Widget _privacyActionButton({
  required IconData icon,
  required String text,
  required VoidCallback onPressed,
  Color textColor = Colors.white,
}) {
  return InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(8.w),
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16.sp,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white54),
        ],
      ),
    ),
  );
}

// Método auxiliar para mostrar un diálogo de carga
Widget _showLoadingDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1C2126),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16.w),
            Text(
              localizations.get('please_wait'),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    },
  );
  return Container(); // Dummy para el return
}

// Método para exportar datos como JSON
Future<void> _exportDataAsJson(Map<String, dynamic> userData) async {
  // Esta es una implementación simple - comparte el texto JSON
  final json = jsonEncode(userData);
  
  await Share.share(
    json,
    subject: 'Mis datos personales - Clínicas Love',
  );
  
  // En una implementación real, aquí podrías:
  // 1. Guardar el JSON en un archivo local
  // 2. Permitir al usuario compartirlo por correo o descargarlo
  // 3. Ofrecer opciones de formato (JSON, PDF, etc.)
}

  // Método para descargar datos personales
  Future<void> _downloadPersonalData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16.w),
              Text(
                localizations.get('please_wait'),
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // Obtener los datos del usuario
      final userId = _supabaseService.client.auth.currentUser?.id;
      if (userId == null) {
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }
      
      final userData = await _profileService.getUserData(userId);
      
      // Cerrar el diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();
      
      // Mostrar los datos y opción para exportar
      _showDataExportDialog(userData);
    } catch (e) {
      // Cerrar el diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();
      
      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // Diálogo para mostrar y exportar datos personales
  void _showDataExportDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126),
          title: Text(
            localizations.get('your_personal_data'),
            style: TextStyle(color: Colors.white),
          ),
          content: Container(
            width: double.maxFinite,
            height: 400.h,
            child: ListView(
              children: [
                // Mostrar todos los datos del usuario de manera formateada
                ...userData.entries.map((entry) {
                  // No mostrar datos sensibles como contraseñas
                  if (entry.key.contains('password') || entry.key == 'id') {
                    return SizedBox();
                  }
                  
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatFieldName(entry.key),
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          entry.value?.toString() ?? 'No disponible',
                          style: TextStyle(color: Colors.white),
                        ),
                        Divider(color: Colors.white30),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                localizations.get('export_as_json'),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: () async {
                // Exportar datos como JSON
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Función de exportación en desarrollo")),
                );
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                localizations.get('close'),
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Método para gestionar consentimientos
  void _showConsentManager() {
    showDialog(
      context: context,
      builder: (context) {
        // Valores iniciales para los consentimientos
        bool personalDataConsent = _profile?.consents?['data_processing'] ?? false;
        bool healthDataConsent = _profile?.consents?['health_data'] ?? false;
        bool marketingConsent = _profile?.consents?['marketing'] ?? false;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2126),
              title: Text(
                localizations.get('manage_consents'),
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    localizations.get('consent_description') ?? 'Gestiona tus consentimientos de datos',
                    style: TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Consentimiento para datos personales básicos
                  SwitchListTile(
                    title: Text(
                      localizations.get('personal_data_consent') ?? 'Datos personales',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      localizations.get('personal_data_consent_desc') ?? 'Necesario para usar la app',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    value: personalDataConsent,
                    onChanged: (value) {
                      setState(() {
                        personalDataConsent = value;
                      });
                    },
                  ),
                  
                  // Consentimiento para datos de salud
                  SwitchListTile(
                    title: Text(
                      localizations.get('health_data_consent') ?? 'Datos de salud',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      localizations.get('health_data_consent_desc') ?? 'Para simulaciones y tratamientos',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    value: healthDataConsent,
                    onChanged: (value) {
                      setState(() {
                        healthDataConsent = value;
                      });
                    },
                  ),
                  
                  // Consentimiento para marketing (opcional)
                  SwitchListTile(
                    title: Text(
                      localizations.get('marketing_consent') ?? 'Marketing',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      localizations.get('marketing_consent_desc') ?? 'Ofertas y promociones',
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    value: marketingConsent,
                    onChanged: (value) {
                      setState(() {
                        marketingConsent = value;
                      });
                    },
                  ),
                ],
              ),
    ),
              actions: [
                TextButton(
                  child: Text(
                    localizations.get('cancel') ?? 'Cancelar',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text(
                    localizations.get('save') ?? 'Guardar',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  onPressed: () async {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF1C2126),
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16.w),
                              Text(
                                localizations.get('please_wait') ?? 'Por favor, espera...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    
                    try {
                      await _profileService.updateConsents({
                        'data_processing': personalDataConsent,
                        'health_data': healthDataConsent,
                        'marketing': marketingConsent,
                        'consent_timestamp': DateTime.now().toIso8601String(),
                        'consent_version': '1.0',
                      });
                      
                      Navigator.of(context, rootNavigator: true).pop(); // Cerrar loading
                      Navigator.of(context).pop(); // Cerrar diálogo
                      
                      _loadProfile(); // Recargar perfil
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(localizations.get('consents_updated') ?? 'Consentimientos actualizados')),
                      );
                    } catch (e) {
                      Navigator.of(context, rootNavigator: true).pop(); // Cerrar loading
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para confirmación de eliminación de cuenta
  void _showDeleteAccountConfirmation() {
    final passwordController = TextEditingController();
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2126),
              title: Text(
                localizations.get('delete_account_title') ?? '¿Eliminar cuenta?',
                style: TextStyle(color: Colors.red),
              ),
              content: SingleChildScrollView( 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 48.sp,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    localizations.get('delete_account_warning') ?? 'Esta acción eliminará todos tus datos',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    localizations.get('delete_account_irreversible') ?? 'Esta acción es irreversible',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.h),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: localizations.get('confirm_password') ?? 'Confirma tu contraseña',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white30),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
      ),
              actions: [
                TextButton(
                  child: Text(
                    localizations.get('cancel') ?? 'Cancelar',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                if (isLoading)
                  CircularProgressIndicator()
                else
                  TextButton(
                    child: Text(
                      localizations.get('delete_permanently') ?? 'Eliminar permanentemente',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (innerContext) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF1C2126),
                            title: Text(
                              localizations.get('final_confirmation') ?? 'Confirmación final',
                              style: TextStyle(color: Colors.red),
                            ),
                            content: Text(
                              localizations.get('no_way_back') ?? 'No hay vuelta atrás',
                              style: TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(
                                child: Text(localizations.get('cancel') ?? 'Cancelar'),
                                onPressed: () => Navigator.of(innerContext).pop(),
                              ),
                              TextButton(
                                child: Text(
                                  localizations.get('yes_delete_account') ?? 'Sí, eliminar cuenta',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onPressed: () async {
                                  Navigator.of(innerContext).pop(); // Cerrar diálogo interno
                                  
                                  setState(() {
                                    isLoading = true;
                                  });
                                  
                                  try {
                                    // Reemplazar el SnackBar con la implementación real
                                    setState(() {
                                      isLoading = true;
                                    });

                                    // Llamar al método de eliminación de cuenta
                                    final success = await _profileService.deleteAccount(
                                      password: passwordController.text
                                    );
                                    
                                    if (success) {
                                      // Cerrar diálogo actual y salir a login
                                      Navigator.of(context).pop();
                                      
                                      // Registrar analítica para la eliminación de cuenta
                                      AnalyticsService().logInteraction('account_deleted', {
                                        'account_age_days': _accountAgeDays(),
                                      });
                                      
                                      // Logout del usuario
                                      await _authService.logout(context: context);
                                      
                                      // Navegar a la pantalla de login
                                      Navigator.of(context).pushNamedAndRemoveUntil(
                                        '/login', 
                                        (route) => false,
                                      );
                                      
                                      // Informar al usuario
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(localizations.get('account_deleted_success') ?? 'Cuenta eliminada correctamente'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        isLoading = false;
                                      });
                                      
                                      // Mostrar error genérico
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(localizations.get('account_deletion_failed') ?? 'No se pudo eliminar la cuenta'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() {
                                      isLoading = false;
                                    });
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para formatear nombres de campos
  String _formatFieldName(String key) {
    final formattedKey = key.replaceAll('_', ' ');
    return formattedKey.split(' ').map((word) {
      return word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  // Método para calcular la edad de la cuenta en días
  int _accountAgeDays() {
    final currentUser = _supabaseService.client.auth.currentUser;
    if (currentUser?.createdAt == null) return 0;
    
    try {
      final createdAt = DateTime.parse(currentUser!.createdAt);
      return DateTime.now().difference(createdAt).inDays;
    } catch (e) {
      return 0;
    }
  }

  
}