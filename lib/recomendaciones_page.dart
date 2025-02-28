import 'package:flutter/material.dart';

class RecomendacionesPage extends StatelessWidget {
  const RecomendacionesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Column(
          children: [
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón atrás
                  IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');  // Changed from pop to pushReplacementNamed
                    },
                 ),
                  // Logo en el centro
                  Expanded(
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
                  // Espacio vacío para mantener el logo centrado
                  const SizedBox(width: 48.0),
                ],
              ),
            ),
            // Título
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Recomendado para ti',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.015,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16.0),
            // Subtítulo
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Crea una cuenta para acceder a nuestras recomendaciones personalizadas.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16.0),
            // Botones de opciones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildButton('Continuar con Google', const Color(0xFF293038)),
                  const SizedBox(height: 8.0),
                  _buildButton('Continuar con Facebook', const Color(0xFF293038)),
                  const SizedBox(height: 8.0),
                  _buildButton('Continuar con Apple', const Color(0xFF293038)),
                  const SizedBox(height: 8.0),
                  _buildButton('Crear cuenta', Colors.transparent),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            // Términos y condiciones
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Al continuar, aceptas los Términos de uso y la Política de privacidad.',
                style: TextStyle(
                  color: Color(0xFF9DABB8),
                  fontSize: 14.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),

          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color color) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}