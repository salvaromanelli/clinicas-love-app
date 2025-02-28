import 'package:flutter/material.dart';


class PostTratamientoPage extends StatelessWidget {
  const PostTratamientoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Column(
          children: [
            // Logo en el centro superior
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
                'Post-tratamiento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
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
                'Seguimiento de tratamiento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.015,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            // Descripción
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Hemos programado tu seguimiento post-tratamiento. Te notificaremos cuando sea el momento de tomar fotos y enviarlas.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Próxima cita
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Próxima cita',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '15 de enero',
                        style: TextStyle(
                          color: Color(0xFF9DABB8),
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '10:00 AM',
                    style: TextStyle(
                      color: Color(0xFF9DABB8),
                      fontSize: 14.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),


            // Programa tu seguimiento
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: const Color(0xFF293038),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Programa tu seguimiento',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4.0),
                                      Text(
                                        'Toma fotos en casa siguiendo nuestras instrucciones',
                                        style: TextStyle(
                                          color: Color(0xFF9DABB8),
                                          fontSize: 14.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 80.0,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                      image: const DecorationImage(
                                        image: NetworkImage(
                                          'https://cdn.usegalileo.ai/sdxl10/3177f0db-f23f-4b83-8888-e4b0e15ba2c1.png',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Bottom Navigation Bar
                                       Container(
                          color: const Color(0xFF1C2126),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(context, '/home');
                                },
                                child: _buildNavItem(Icons.home, 'Inicio', false),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/ofertas-promos');
                                },
                                child: _buildNavItem(Icons.shopping_bag, 'Productos', false),
                              ),
                              _buildNavItem(Icons.calendar_today, 'Mis citas', true),
                              _buildNavItem(Icons.person, 'Perfil', false),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget _buildNavItem(IconData icon, String label, bool isActive) {
                final color = isActive ? Colors.white : const Color(0xFF9DABB8);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(height: 4.0),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12.0,
                      ),
                    ),
                  ],
                );
              }
            }