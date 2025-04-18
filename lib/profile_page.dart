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


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();  
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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

  final localizations = AppLocalizations.of(context);

  
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
                  SizedBox(width: 16.w), // Added comma here
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
    // Primero limpiar el UserProvider
    Provider.of<UserProvider>(context, listen: false).logout();
    
    // Luego cerrar sesión en Supabase
    await SupabaseService().signOut();
    
    // Eliminar el token de autenticación
    await AuthService().logout(context: context);
    
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  } catch (e) {
    debugPrint('❌ Error en logout: $e');
  }
}
  // _buildMenuItem method
Widget _buildMenuItem(String title, {String? badge, bool withBadge = false}) {
  final localizations = AppLocalizations.of(context);
  final isSmallScreen = AdaptiveSize.screenWidth < 360;
  
  return GestureDetector(
    onTap: () async {
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
}