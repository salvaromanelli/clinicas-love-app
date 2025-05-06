import 'package:flutter/material.dart';
import 'package:flutter_application_1/AI_Treatment_Simulator.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:intl/date_symbol_data_local.dart';
import 'ofertas_promo_page.dart';
import 'educacion_contenido_page.dart';
import 'main_navigation.dart';
import 'profile_page.dart' as profile;
import 'integracion_redes_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'virtual_assistant_chat.dart';
import 'boton_asistente.dart';
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
import 'utils/adaptive_sizing.dart';
import 'services/analytics_service.dart';
import 'dart:async';
import 'services/http_service.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  final startTime = DateTime.now();
    // Carga las variables de entorno antes de inicializar la app
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
  HttpService.initialize(); // Inicializa el cliente HTTP
  setupTokenRefreshTimer();
  
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


  // Registrar tiempo de inicialización
  final initDuration = DateTime.now().difference(startTime).inMilliseconds;
  AnalyticsService().logInteraction('app_initialized', {
    'init_duration_ms': initDuration,
    'supabase_initialized': true,
    'notifications_initialized': true,
  });
   
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

        // Usar TextTheme con tamaños adaptables
        textTheme: ThemeData.light().textTheme.apply(
          fontSizeFactor: 1.0, // Esto se ajustará dinámicamente con MediaQuery
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
        '/ofertas-promo': (context) => const OfertasPromosPage(),
        '/educacion-contenido': (context) => const EducacionContenidoPage(),
        '/profile': (context) => const profile.ProfilePage(),
        '/integracion-redes': (context) => const IntegracionRedesPage(),
        '/login': (context) => LoginPage(child: MainNavigation()), 
        '/register': (context) => RegisterPage(),
        '/boton-asistente': (context) => const AnimatedAssistantButton(),
        '/assistant': (context) => const VirtualAssistantChat(),
        '/simulation': (context) => const AITreatmentSimulator(),
        '/clinicas': (context) => const ClinicasPage(),
        '/book-appointment': (context) => const AppointmentBookingPage(),
        '/reviews': (context) => const ReviewsPage(),
        '/language-settings': (context) => const LanguageSettingsPage(),

        },
          builder: (context, child) {
            // Inicializar AdaptiveSize al principio para asegurar que esté disponible
            AdaptiveSize.initialize(context);
            
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
                  Positioned(
                    bottom: AdaptiveSize.h(20), // Usar .h para adaptativo
                    left: AdaptiveSize.w(20),   // Usar .w para adaptativo
                    child: const AnimatedAssistantButton(),
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

    // Registrar inicio de la aplicación
    AnalyticsService().logInteraction('app_launched', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    _checkUserAndNavigate();
  }

  _checkUserAndNavigate() async {
    // Verificar si hay un usuario autenticado
    final isLoggedIn = await SupabaseService().isLoggedIn();
    
    // Sincronizar UserProvider independiente de dónde navegue
    if (mounted) {
      AuthService.syncUserWithProvider(context);
      print('🔄 Sincronizando usuario en SplashScreen');
    }
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      if (isLoggedIn) {
        // Registrar inicio de sesión automático
        AnalyticsService().logInteraction('auto_login', {
          'user_id': SupabaseService().client.auth.currentUser?.id,
        });
        
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Registrar redirección a login
        AnalyticsService().logInteraction('redirect_to_login', {
          'from': 'splash_screen',
        });
        
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
            height: AdaptiveSize.getLogoSize(context, baseSize: 100.0),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DateTime _pageEnteredTime = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    AnalyticsService().logPageView('home_page');
  }
  
  @override
  void dispose() {
    AnalyticsService().logInteraction('home_page_exited', {
      'time_spent_seconds': DateTime.now().difference(_pageEnteredTime).inSeconds,
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize para esta pantalla
    AdaptiveSize.initialize(context);
    
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
                padding: EdgeInsets.symmetric(horizontal: AdaptiveSize.w(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo sin círculo de fondo
                    Padding(
                      padding: EdgeInsets.only(top: AdaptiveSize.h(24), bottom: AdaptiveSize.h(16)),
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: AdaptiveSize.getLogoSize(context, baseSize: 70.0),
                          ),
                        ),
                      ),
                    ),

                    // Título principal con estilo mejorado
                    Text(
                      localizations.get('how_can_we_help'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AdaptiveSize.sp(26),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: AdaptiveSize.h(16)),
                    
                    // Tarjeta del asistente virtual destacada
                    _buildAssistantCard(context),
                    
                    SizedBox(height: AdaptiveSize.h(24)),
                    
                    // Sección de servicios principales
                    Row(
                      children: [
                        Text(
                          localizations.get('our_services'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AdaptiveSize.sp(18),
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
                            iconSize: AdaptiveSize.getIconSize(context, baseSize: 20.0),
                            padding: EdgeInsets.all(AdaptiveSize.w(8)),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Navigator.pushNamed(context, '/language-settings');
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AdaptiveSize.h(16)),
                    
                    // Grid de opciones con diseño mejorado
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      crossAxisSpacing: AdaptiveSize.w(16),
                      mainAxisSpacing: AdaptiveSize.h(16),
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
                    SizedBox(height: AdaptiveSize.h(24)),
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
    // Asegurar que AdaptiveSize esté inicializado
    AdaptiveSize.initialize(context);
    final localizations = AppLocalizations.of(context);
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: AdaptiveSize.h(8)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1980E6), Color(0xFF0077CC)],
        ),
        borderRadius: BorderRadius.circular(AdaptiveSize.w(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1980E6).withOpacity(0.4),
            blurRadius: AdaptiveSize.w(12),
            offset: Offset(0, AdaptiveSize.h(4)),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AdaptiveSize.w(16)),
          onTap: () {
            // Registrar evento de clic en asistente
            AnalyticsService().logInteraction('assistant_card_clicked', {
              'source': 'home_page',
              'position': 'top_card',
            });
            
            Navigator.pushNamed(context, '/assistant');
          },
          child: Padding(
            padding: EdgeInsets.all(AdaptiveSize.w(20)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(AdaptiveSize.w(12)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: AdaptiveSize.getIconSize(context, baseSize: 28.0),
                  ),
                ),
                SizedBox(width: AdaptiveSize.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.get('virtual_assistant'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AdaptiveSize.sp(18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: AdaptiveSize.h(2)),
                      Text(
                        localizations.get('virtual_assistant_desc'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AdaptiveSize.sp(14),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: AdaptiveSize.getIconSize(context, baseSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, String title, String imageUrl, IconData icon, String route) {
    // Asegurarse de que AdaptiveSize esté inicializado
    AdaptiveSize.initialize(context);
    
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdaptiveSize.w(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Registrar evento de navegación a servicio
          AnalyticsService().logInteraction('service_card_clicked', {
            'service_name': title,
            'route': route,
            'source': 'home_page',
          });
          
          Navigator.pushNamed(context, route);
        },
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
                    top: AdaptiveSize.h(8),
                    right: AdaptiveSize.w(8),
                    child: Container(
                      padding: EdgeInsets.all(AdaptiveSize.w(6)),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1980E6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: AdaptiveSize.getIconSize(context, baseSize: 18.0),
                      ),
                    ),
                  ),
                ]
              )
            ),
          
            // Título
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AdaptiveSize.w(8), 
                  vertical: AdaptiveSize.h(4)
                ),
                child: Center(
                  child: Text(
                    _getTranslatedTitle(context, title),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AdaptiveSize.sp(14),
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
}

  void setupTokenRefreshTimer() {
    // Verificar el token cada 10 minutos
    Timer.periodic(const Duration(minutes: 10), (_) async {
      final authService = AuthService();
      final success = await authService.refreshTokenIfNeeded();
      
      if (!success) {
        // Forzar cierre de sesión si la renovación falló
        await authService.logout();
        navigatorKey.currentState?.pushReplacementNamed('/login');
      }
    });
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



