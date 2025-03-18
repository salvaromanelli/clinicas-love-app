import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('es');
  
  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  // Cargar el idioma guardado
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'es';
    
    setLocale(Locale(languageCode));
  }

  // Cambiar y guardar el idioma seleccionado
  Future<void> setLocale(Locale locale) async {
    if (!['es', 'en', 'ca'].contains(locale.languageCode)) return;
    
    _currentLocale = locale;
    
    // Guardar preferencia
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    
    notifyListeners();
  }

  // Obtener el nombre del idioma basado en el código
  String getLanguageName(String code) {
    switch (code) {
      case 'es': return 'Español';
      case 'en': return 'English';
      case 'ca': return 'Català';
      default: return 'Español';
    }
  }
}