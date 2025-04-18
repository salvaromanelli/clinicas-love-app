import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/language_provider.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; // Importar AdaptiveSize

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    final languageProvider = Provider.of<LanguageProvider>(context);
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418), // Fondo oscuro consistente
      appBar: AppBar(
        title: Text(
          localizations.get('language_settings'),
          style: TextStyle(fontSize: 18.sp),
        ),
        backgroundColor: const Color(0xFF1C2126), // Color de AppBar consistente
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: AdaptiveSize.getIconSize(context, baseSize: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                localizations.get('select_language'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 16.sp : 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1980E6), // Azul primario consistente
                ),
              ),
            ),
            _buildLanguageOption(
              context, 
              'Español', 
              'es', 
              languageProvider,
              flagPath: 'assets/images/esp.png',
              isSmallScreen: isSmallScreen,
            ),
            _buildLanguageOption(
              context, 
              'English', 
              'en', 
              languageProvider,
              flagPath: 'assets/images/united-kingdom.png',
              isSmallScreen: isSmallScreen,
            ),
            _buildLanguageOption(
              context, 
              'Català', 
              'ca', 
              languageProvider,
              flagPath: 'assets/images/cat.png',
              isSmallScreen: isSmallScreen,
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                localizations.get('language_info'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLanguageOption(
    BuildContext context, 
    String name, 
    String code, 
    LanguageProvider provider, 
    {String? flagPath, bool isSmallScreen = false}
  ) {
    final isSelected = provider.currentLocale.languageCode == code;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isSelected 
            ? const Color(0xFF1980E6).withOpacity(0.15) 
            : const Color(0xFF1C2126),
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFF1980E6)
              : Colors.transparent,
          width: 1.w,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w, 
          vertical: isSmallScreen ? 6.h : 8.h,
        ),
        leading: SizedBox(
          width: isSmallScreen ? 36.w : 40.w,
          height: isSmallScreen ? 36.h : 40.h,
          child: flagPath != null 
            ? CircleAvatar(
                backgroundImage: AssetImage(flagPath),
              )
            : CircleAvatar(
                backgroundColor: const Color(0xFF1980E6).withOpacity(0.2),
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                    color: const Color(0xFF1980E6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: isSmallScreen ? 14.sp : 16.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: Colors.white,
          ),
        ),
        trailing: isSelected 
            ? Icon(
                Icons.check_circle, 
                color: const Color(0xFF1980E6),
                size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 20 : 24),
              )
            : null,
        onTap: () {
          provider.setLocale(Locale(code));
        },
      ),
    );
  }
}