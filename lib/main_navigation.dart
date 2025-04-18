import 'package:flutter/material.dart';
import 'main.dart';
import 'appointments.dart';
import 'ofertas_promo_page.dart';
import 'profile_page.dart' as profile;
import 'i18n/app_localizations.dart'; 
import 'utils/adaptive_sizing.dart';

// Añade esta clase que estaba faltando
class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
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
    // Asegurar que AdaptiveSize esté inicializado
    AdaptiveSize.initialize(context);
    
    // Obtener instancia de traducciones
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: _pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 65.h, // Usar .h para altura
          decoration: BoxDecoration(
            color: const Color(0xFF1C2126),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.1),
                blurRadius: 10.w, // Usar .w para blur
                offset: Offset(0, -5.h), // Usar .h para offset vertical
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildNavItem(Icons.home, localizations.get('home'), _selectedIndex == 0, 0),
              ),
              Expanded(
                child: _buildNavItem(Icons.shopping_bag, localizations.get('products'), _selectedIndex == 1, 1),
              ),
              Expanded(
                child: _buildNavItem(Icons.calendar_today, localizations.get('my_appointments'), _selectedIndex == 2, 2),
              ),
              Expanded(
                child: _buildNavItem(Icons.person, localizations.get('profile'), _selectedIndex == 3, 3),
              ),
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
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w), // Usar .h y .w
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF9DABB8),
              size: AdaptiveSize.getIconSize(context, baseSize: 24), // Usar getIconSize
            ),
            SizedBox(height: 4.h), // Usar .h
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF9DABB8),
                fontSize: 13.sp, // Usar .sp para texto
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}