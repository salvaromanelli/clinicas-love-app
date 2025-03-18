import 'package:flutter/material.dart';
import 'main.dart';
import 'appointments.dart';
import 'ofertas_promo_page.dart';
import 'profile_page.dart' as profile;
import 'i18n/app_localizations.dart'; // Añadir importación

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const HomePage(),
    const OfertasPromosPage(),
    const RecomendacionesPage(),
    const profile.ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Obtener instancia de traducciones
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: _pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            color: const Color(0xFF1C2126),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.home, localizations.get('home'), _selectedIndex == 0, 0),
              _buildNavItem(Icons.shopping_bag, localizations.get('products'), _selectedIndex == 1, 1),
              _buildNavItem(Icons.calendar_today, localizations.get('my_appointments'), _selectedIndex == 2, 2),
              _buildNavItem(Icons.person, localizations.get('profile'), _selectedIndex == 3, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, int index) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF9DABB8),
              size: 24.0,
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF9DABB8),
                fontSize: 13.0,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis, // Añadir ellipsis si no cabe
              maxLines: 1, // Limitar a una línea
            ),
          ],
        ),
      ),
    );
  }
}