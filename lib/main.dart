import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:intl/date_symbol_data_local.dart';
import 'post_tratamiento_page.dart';
import 'ofertas_promo_page.dart';
import 'educacion_contenido_page.dart';
import 'main_navigation.dart';
import 'profile_page.dart' as profile;
import 'integracion_redes_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'virtual_assistant_chat.dart';
import 'boton_asistente.dart';
import 'mediapipe_treatment_simulator.dart';
import 'services/supabase.dart';
import 'clinicas_cerca.dart';
import 'booking_page.dart';
import 'services/notificaciones.dart';
import 'appointments.dart';
import 'reviews_page.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'i18n/app_localizations.dart';
import 'language_settings_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/user_provider.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
    // Carga las variables de entorno antes que nada
  await dotenv.load(fileName: ".env");
  
  // Inicializar Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar formato de fechas
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('ca', null);
  
  // Inicializar otros servicios
  await SupabaseService.initialize();
  await NotificationService().initialize();
   
  runApp(
    MultiProvider(    
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()), 
      ],
      child: const MyApp(),
    )
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    
    return MaterialApp(
      navigatorKey: navigatorKey, 
      title: 'Clínicas Love',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1980E6)),
        useMaterial3: true,

        // Añadir esta configuración para texto adaptativo:
        textTheme: ThemeData.light().textTheme.copyWith(
          displayLarge: TextStyle(fontSize: 22.0),
          displayMedium: TextStyle(fontSize: 20.0),
          displaySmall: TextStyle(fontSize: 18.0),
          headlineMedium: TextStyle(fontSize: 16.0),
          headlineSmall: TextStyle(fontSize: 14.0),
          titleLarge: TextStyle(fontSize: 14.0),
          titleMedium: TextStyle(fontSize: 13.0),
          titleSmall: TextStyle(fontSize: 12.0),
          bodyLarge: TextStyle(fontSize: 14.0),
          bodyMedium: TextStyle(fontSize: 13.0),
          bodySmall: TextStyle(fontSize: 12.0),
        ),
      ),
      
      home: const SplashScreen(),
      
      // Configuración de localización actualizada
      locale: languageProvider.currentLocale,
      
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
        Locale('ca'),
      ],
     
      routes: {
        '/home': (context) => const MainNavigation(),
        '/recomendaciones': (context) => const RecomendacionesPage(),
        '/post-tratamiento': (context) => const PostTratamientoPage(),
        '/ofertas-promo': (context) => const OfertasPromosPage(),
        '/educacion-contenido': (context) => const EducacionContenidoPage(),
        '/profile': (context) => const profile.ProfilePage(),
        '/integracion-redes': (context) => const IntegracionRedesPage(),
        '/login': (context) => LoginPage(child: MainNavigation()), 
        '/register': (context) => RegisterPage(),
        '/boton-asistente': (context) => const AnimatedAssistantButton(),
        '/assistant': (context) => const VirtualAssistantChat(),
        '/simulation': (context) => FaceMeshTreatmentSimulator(
          initialTreatment: 'lips',
          initialIntensity: 0.5,
        ),
        '/clinicas': (context) => const ClinicasPage(),
        '/book-appointment': (context) => const AppointmentBookingPage(),
        '/reviews': (context) => const ReviewsPage(),
        '/language-settings': (context) => const LanguageSettingsPage(),

        },
          builder: (context, child) {
            // Obtener la ruta actual con depuración
            final String? currentRoute = ModalRoute.of(context)?.settings.name;
            print('Ruta actual: $currentRoute');
            
            // Aseguramos que child no sea null para evitar errores
            final Widget safeChild = child ?? const SizedBox();
            
            // Solo añadir botón asistente a las rutas específicas
            if (currentRoute == '/ofertas-promo' || currentRoute == '/appointments') {
              print('Añadiendo botón asistente a: $currentRoute');
              return Stack(
                children: [
                  safeChild,
                  const Positioned(
                    bottom: 20.0,
                    left: 20.0,
                    child: AnimatedAssistantButton(),
                  ),
                ],
              );
            }
            
            // Para todas las demás rutas, retornar el child sin botón asistente
            return safeChild;
          },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserAndNavigate();
  }

  _checkUserAndNavigate() async {
    // Verificar si hay un usuario autenticado
    final isLoggedIn = await SupabaseService().isLoggedIn();
    
    // AÑADIR ESTAS LÍNEAS: Sincronizar UserProvider independiente de dónde navegue
    if (mounted && context != null) {
      AuthService.syncUserWithProvider(context);
      print('🔄 Sincronizando usuario en SplashScreen');
    }
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      if (isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
          child: Image.asset(
            'assets/images/logo.png',
            height: 100.0,
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente elegante en lugar de imagen oscurecida
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A2647), Color(0xFF144272)],
              ),
            ),
          ),
          // Patrón decorativo sutil
          Opacity(
            opacity: 0.05,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/Clinicas_love_fondo.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Contenido principal
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo sin círculo de fondo
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 70.0,
                          ),
                        ),
                      ),
                    ),

                    // Título principal con estilo mejorado
                    Text(
                      localizations.get('how_can_we_help'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 16.0),
                    
                    // Tarjeta del asistente virtual destacada
                    _buildAssistantCard(context),
                    
                    const SizedBox(height: 24.0),
                    
                    // Sección de servicios principales
                    Row(
                      children: [
                        Text(
                          localizations.get('our_services'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(), // Empuja el botón hacia el lado derecho
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.language, color: Colors.white),
                            iconSize: 20,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Navigator.pushNamed(context, '/language-settings');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Grid de opciones con diseño mejorado
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                      childAspectRatio: 0.85,
                      children: [
                        _buildServiceCard(
                          context,
                          'simulation_results', // Clave de traducción
                          'assets/images/Simulador.jpg',
                          Icons.photo_filter,
                          '/simulation',
                        ),
                        _buildServiceCard(
                          context,
                          'connect_social', // Clave de traducción
                          'assets/images/descuento_redes.jpg',
                          Icons.share,
                          '/integracion-redes',
                        ),
                        _buildServiceCard(
                          context,
                          'education_content', // Clave de traducción
                          'assets/images/Contenido_educativo.webp',
                          Icons.menu_book,
                          '/educacion-contenido',
                        ),
                        _buildServiceCard(
                          context,
                          'our_clinics', // Clave de traducción
                          'assets/images/Nuestras_clinicas.jpg',
                          Icons.location_on,
                          '/clinicas',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),
                  ],   
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantCard(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Ajustar tamaños para pantallas pequeñas
    final titleSize = screenWidth < 360 ? 16.0 : 18.0;
    final descSize = screenWidth < 360 ? 12.0 : 14.0;
    final iconSize = screenWidth < 360 ? 24.0 : 28.0;


    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1980E6), Color(0xFF0077CC)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1980E6).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, '/assistant'),
          child: Padding(
            // Reducir el padding para pantallas pequeñas
            padding: EdgeInsets.all(screenWidth < 360 ? 16.0 : 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: iconSize, // Tamaño adaptado
                  ),
                ),
                const SizedBox(width: 12), // Reducir espacio
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.get('virtual_assistant'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize, // Tamaño adaptado
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2), // Reducir espacio
                      Text(
                        localizations.get('virtual_assistant_desc'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: descSize, // Tamaño adaptado
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String imageUrl, IconData icon, String route) {
    // Calcular el tamaño de fuente basado en el ancho de pantalla
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 12.0 : 14.0;
    
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen de fondo con overlay
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagen
                  imageUrl.startsWith('http')
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        )
                      : Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                        ),
                  // Overlay gradiente
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                  // Icono en esquina
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1980E6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Título
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reducir padding
                child: Center(
                  child: Text(
                    _getTranslatedTitle(context, title),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize, // Usar tamaño dinámico
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

    // Añadir este método a la clase HomePage
  double _getAdaptiveTextSize(BuildContext context, {required double baseSize}) {
    // Obtener el ancho de pantalla
    final width = MediaQuery.of(context).size.width;
    
    // Factor de escala basado en el ancho de pantalla
    double scaleFactor = 1.0;
    
    if (width < 320) {
      scaleFactor = 0.8; // Para pantallas muy pequeñas
    } else if (width < 375) {
      scaleFactor = 0.85; // Para pantallas iPhone SE o similares
    } else if (width < 414) {
      scaleFactor = 0.9; // Para pantallas iPhone 8 Plus o similares
    }
    
    return baseSize * scaleFactor;
  }

    String _getTranslatedTitle(BuildContext context, String englishTitle) {
    final localizations = AppLocalizations.of(context);
    
    // Mapa de títulos en español a claves de traducción
    final Map<String, String> titleToKey = {
      'Simulación de Resultados con IA': 'simulation_results',
      'Conecta tus Redes': 'connect_social',
      'Educación y Contenido': 'education_content',
      'Nuestras Clínicas': 'our_clinics',
      // Añadir más según necesites
    };
    
    final key = titleToKey[englishTitle] ?? englishTitle;
    return localizations.get(key);
  }
}


