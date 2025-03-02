import 'package:flutter/material.dart';
import 'recomendaciones_page.dart';
import 'post_tratamiento_page.dart';
import 'ofertas_promo_page.dart';
import 'educacion_contenido_page.dart';
import 'main_navigation.dart';
import 'profile_page.dart';
import 'integracion_redes_page.dart';
import 'login_page.dart'; // Asegúrate de importar la página de login
import 'register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
return MaterialApp(
  title: 'Clínicas Love',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  ),
  home: const SplashScreen(),
  routes: {
    '/home': (context) => const MainNavigation(),
    '/recomendaciones': (context) => const RecomendacionesPage(),
    '/post-tratamiento': (context) => const PostTratamientoPage(),
    '/ofertas-promos': (context) => const OfertasPromosPage(),
    '/educacion-contenido': (context) => const EducacionContenidoPage(),
    '/profile': (context) => const ProfilePage(),
    '/integracion-redes': (context) => const IntegracionRedesPage(),
    '/login': (context) => LoginPage(child: MainNavigation()), 
    '/register': (context) => RegisterPage(),
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
    _navigateToHome();
  }

_navigateToHome() async {
  await Future.delayed(const Duration(seconds: 3), () {});
  Navigator.pushReplacementNamed(context, '/home');
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
                    'Confirme su cita',
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
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/recomendaciones');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1980E6),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Comenzar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
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
      if (title == 'Confirme su cita') {
        Navigator.pushNamed(context, '/post-tratamiento');
      } else if (title == 'Educación y contenido') {  // Add this condition
        Navigator.pushNamed(context, '/educacion-contenido');
      } else if (title == 'Conecta tus redes sociales y obten descuentos') {  // Add this condition
        Navigator.pushNamed(context, '/integracion-redes');
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