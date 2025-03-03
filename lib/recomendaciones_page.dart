import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

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
                      Navigator.pushReplacementNamed(context, '/login');
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
                  _buildButton(context, 'Continuar con Google', const Color(0xFF293038), 'assets/images/Googl-icon.png'),
                  const SizedBox(height: 8.0),
                  _buildButton(context, 'Continuar con Facebook', const Color(0xFF293038), 'assets/images/FB-icon.png', _loginWithFacebook),
                  const SizedBox(height: 8.0),
                  _buildButton(context, 'Continuar con Apple', const Color(0xFF293038), 'assets/images/Appl-icon.png'),
                  const SizedBox(height: 8.0),
                  Center(child: _buildTextButton(context, 'Crear cuenta')),
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

Widget _buildButton(BuildContext context, String text, Color color, [String? iconPath, Function? onPressed]) {
  return ElevatedButton(
    onPressed: () {
      if (onPressed != null) {
        onPressed(context);
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      minimumSize: const Size(double.infinity, 56.0), // Altura fija para todos los botones
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (iconPath != null)
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: SizedBox(
              width: 20.0,
              height: 20.0,
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildTextButton(BuildContext context, String text) {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/register');
      },
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

  Future<void> _loginWithFacebook(BuildContext context) async {
    final LoginResult result = await FacebookAuth.instance.login();

    if (result.status == LoginStatus.success) {
      final userData = await FacebookAuth.instance.getUserData(fields: "name,email,picture.width(200),birthday");

      final String name = userData['name'];
      final String email = userData['email'];
      final String pictureUrl = userData['picture']['data']['url'];
      final String birthday = userData['birthday'];

      // Aquí puedes crear el perfil de usuario con los datos obtenidos
      // Por ejemplo, puedes navegar a una página de perfil y pasar los datos
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilePage(
            name: name,
            email: email,
            pictureUrl: pictureUrl,
            birthday: birthday,
          ),
        ),
      );
    } else {
      print(result.status);
      print(result.message);
    }
  }
}

class ProfilePage extends StatelessWidget {
  final String name;
  final String email;
  final String pictureUrl;
  final String birthday;

  const ProfilePage({
    Key? key,
    required this.name,
    required this.email,
    required this.pictureUrl,
    required this.birthday,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(pictureUrl),
              radius: 50.0,
            ),
            const SizedBox(height: 16.0),
            Text(
              name,
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              email,
              style: const TextStyle(
                fontSize: 16.0,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Fecha de nacimiento: $birthday',
              style: const TextStyle(
                fontSize: 16.0,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}