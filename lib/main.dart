import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';  // Asegúrate de que esta importación esté correcta
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
import 'simulacion_resultados.dart';
import 'services/supabase.dart';
import 'clinicas_cerca.dart';
import 'booking_page.dart';
import 'services/notificaciones.dart';
import 'recomendaciones_page.dart';
import 'reviews_page.dart';
import 'package:provider/provider.dart';
import 'providers/youcam_provider.dart';
import 'services/youcam_service.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  // Asegurar que los widgets estén inicializados antes de cualquier operación
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar formato de fechas
  await initializeDateFormatting('es', null);
  
  // Inicializar otros servicios
  await SupabaseService.initialize();
  await NotificationService().initialize();
   
  // Crear una instancia del servicio YouCam con tu API key
  final youCamService = YouCamService(apiKey: 'PjbPnjhSKjgSKM8xDdx80LauBNenasqF');
   
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => YouCamProvider(youCamService)),
        // otros providers...
      ],
      child: const MyApp(),
    )
  );
}

  
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      title: 'Clínicas Love',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1980E6)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es'),
     
      
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
        '/assistant': (context) => const VirtualAssistantChat(),
        '/boton-asistente': (context) => const AnimatedAssistantButton(),
        '/simulation': (context) => SimulacionResultadosPage(),
        '/clinicas': (context) => const ClinicasPage(),
        '/book-appointment': (context) => const AppointmentBookingPage(),
        '/reviews': (context) => const ReviewsPage(),

        },
        builder: (context, child) {
          // Obtener la ruta actual con depuración
          final String? currentRoute = ModalRoute.of(context)?.settings.name;
          print('Ruta actual: $currentRoute'); // Esto ayudará a ver qué ruta se está usando
          
          // Aseguramos que child no sea null para evitar errores
          final Widget safeChild = child ?? const SizedBox();
          
          // Verificación explícita para SplashScreen
          if (child is SplashScreen) {
            print('Detectado SplashScreen');
            return safeChild;
          }
          
          // Verificación explícita para HomePage y MainNavigation
          if (child is HomePage || child is MainNavigation) {
            print('Detectado HomePage o MainNavigation');
            return safeChild;
          }
          
          // Verificación por ruta
          if (currentRoute == '/assistant' || 
              currentRoute == '/home' || 
              currentRoute == '/') {
            print('Detectado ruta sin botón: $currentRoute');
            return safeChild;
          }
          
          // Para todas las demás pantallas, mostrar el botón flotante
          print('Mostrando botón en ruta: $currentRoute');
          return Scaffold(
            body: safeChild,
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 80.0, right: 10.0),
              child: AnimatedAssistantButton(),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          );
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
    await Future.delayed(const Duration(seconds: 2));
    
    // Verificar si hay un usuario autenticado
    final isLoggedIn = await SupabaseService().isLoggedIn();
    
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
                    // Logo con efecto de elevación
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
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
                    ),

                    // Título principal con estilo mejorado
                    const Text(
                      '¿Cómo podemos ayudarte hoy?',
                      style: TextStyle(
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
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Nuestros Servicios',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                          'Simulación de Resultados',
                          'https://cdn.usegalileo.ai/sdxl10/5413b550-9ddd-4735-a640-8c153c8d010f.png',
                          Icons.photo_filter,
                          '/simulation',
                        ),
                        _buildServiceCard(
                          context,
                          'Conecta tus Redes',
                          'assets/images/walomeca.jpg',
                          Icons.share,
                          '/integracion-redes',
                        ),
                        _buildServiceCard(
                          context,
                          'Educación y Contenido',
                          'https://cdn.usegalileo.ai/sdxl10/95b8b74e-1725-4e02-9556-9871b471a3aa.png',
                          Icons.menu_book,
                          '/educacion-contenido',
                        ),
                        _buildServiceCard(
                          context,
                          'Nuestras Clínicas',
                          'https://cdn.usegalileo.ai/sdxl10/fbf4fb0e-c6f7-4cf0-b034-82fb42940f56.png',
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
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Asistente Virtual',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Consulta sobre tratamientos, precios y disponibilidad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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


