import 'package:flutter/material.dart';
import 'recomendaciones_page.dart';
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
import 'nuestras_clinicas.dart';
import 'services/supabase.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Asegúrate de que los widgets están inicializados
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar Supabase
  await SupabaseService.initialize();
  
  runApp(const MyApp());
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
     
      
      routes: {
        '/home': (context) => const MainNavigation(),
        '/recomendaciones': (context) => const RecomendacionesPage(),
        '/post-tratamiento': (context) => const PostTratamientoPage(),
        '/ofertas-promos': (context) => const OfertasPromosPage(),
        '/educacion-contenido': (context) => const EducacionContenidoPage(),
        '/profile': (context) => const profile.ProfilePage(),
        '/integracion-redes': (context) => const IntegracionRedesPage(),
        '/login': (context) => LoginPage(child: MainNavigation()), 
        '/register': (context) => RegisterPage(),
        '/assistant': (context) => const VirtualAssistantChat(),
        '/boton-asistente': (context) => const AnimatedAssistantButton(),
        '/simulation': (context) => const TreatmentSimulationPage(),
        '/clinicas': (context) => const ClinicasPage(),

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
          // Background Image
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/Clinicas_love_fondo.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
            // Dark overlay for better text readability
          Container(
            color: const Color.fromRGBO(0, 0, 0, 0.5),  // Replace withOpacity with fromRG

          ),
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Logo in center top
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
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
                ),

                
            // Título
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Hable con nuestro asistente virtual',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8.0),
            // Descripción
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Responda a preguntas sobre tratamientos, precios y disponibilidad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16.0),
            // Grid de opciones
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildOption(
                    context,
                    'Simulación de resultados',
                     'https://cdn.usegalileo.ai/sdxl10/5413b550-9ddd-4735-a640-8c153c8d010f.png',
                  ),
                  _buildOption(
                    context,
                    'Conecta tus redes sociales y obten descuentos',
                    'assets/images/walomeca.jpg',
                  ),
                  _buildOption(
                    context,
                    'Educación y contenido',
                    'https://cdn.usegalileo.ai/sdxl10/95b8b74e-1725-4e02-9556-9871b471a3aa.png',
                  ),
                  _buildOption(
                    context,
                    'Conozca nuestras clínicas',
                    'https://cdn.usegalileo.ai/sdxl10/fbf4fb0e-c6f7-4cf0-b034-82fb42940f56.png',
                  ),
                    ],
                  ),
                ),
            // Botón
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56.0, // Altura similar al botón anterior
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/assistant');
                      },
                      icon: const Icon(
                        Icons.support_agent,
                        color: Colors.white,
                        size: 28.0,
                      ),
                      label: const Text(
                        'Consulta con nuestro asistente virtual',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1980E6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// En la clase HomePage, modifica el método build para hacer el _buildOption clickeable
Widget _buildOption(BuildContext context, String title, String imageUrl) {
  return GestureDetector(
    onTap: () {
      if (title == 'Simulación de resultados') {
        Navigator.pushNamed(context, '/simulation');
      } else if (title == 'Educación y contenido') {  // Add this condition
        Navigator.pushNamed(context, '/educacion-contenido');
      } else if (title == 'Conecta tus redes sociales y obten descuentos') {  // Add this condition
        Navigator.pushNamed(context, '/integracion-redes');
      } else if (title == 'Conozca nuestras clínicas') {  // Añade esta condición
        Navigator.pushNamed(context, '/clinicas');
      }
    },
    child: Column(
      children: [
        Container(
          width: 100.0,
          height: 100.0,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageUrl.startsWith('http') 
                ? NetworkImage(imageUrl) 
                : AssetImage(imageUrl) as ImageProvider,
              fit: BoxFit.cover,
            ),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
}