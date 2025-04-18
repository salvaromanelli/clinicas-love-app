import 'package:flutter/material.dart';

class AdaptiveSize {
  // Variables estáticas para toda la app
  static late double screenWidth;
  static late double screenHeight;
  static late double textScaleFactor;
  static bool _isInitialized = false;
  
  // Dimensiones base para cálculos proporcionales
  static const double _baseWidth = 375.0; // iPhone X
  static const double _baseHeight = 812.0;

  // Método para inicializar una sola vez (desde MaterialApp.builder)
  static void initialize(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    textScaleFactor = mediaQuery.textScaleFactor;
    _isInitialized = true;
  }
  
  // Asegurar que las dimensiones estén inicializadas
  static void _ensureInitialized(BuildContext context) {
    if (!_isInitialized) {
      initialize(context);
    }
  }
  
  // NUEVOS MÉTODOS PARA ESCALAMIENTO PROPORCIONAL
  // Ancho adaptativo
  static double w(double width) => (width / _baseWidth) * screenWidth;
  
  // Alto adaptativo
  static double h(double height) => (height / _baseHeight) * screenHeight;
  
  // Tamaño de texto adaptativo
  static double sp(double size) => w(size) * textScaleFactor;
  
  // MANTENER TUS MÉTODOS ACTUALES
  static double getIconSize(BuildContext context, {required double baseSize}) {
    _ensureInitialized(context);
    
    double scaleFactor = 1.0;
    if (screenWidth < 320) {
      scaleFactor = 0.75;
    } else if (screenWidth < 375) {
      scaleFactor = 0.85;
    } else if (screenWidth < 414) {
      scaleFactor = 0.95;
    }
    
    return baseSize * scaleFactor;
  }

  static double getLogoSize(BuildContext context, {required double baseSize}) {
    _ensureInitialized(context);
    
    final smallerDimension = screenWidth < screenHeight ? screenWidth : screenHeight;
    
    double scaleFactor = 1.0;
    if (smallerDimension < 320) {
      scaleFactor = 0.7;
    } else if (smallerDimension < 375) {
      scaleFactor = 0.8;
    } else if (smallerDimension < 414) {
      scaleFactor = 0.9;
    } else if (smallerDimension >= 800) {
      scaleFactor = 1.2;
    }
    
    return baseSize * scaleFactor;
  }

  static double getTextSize(BuildContext context, {required double baseSize}) {
    _ensureInitialized(context);
    
    double scaleFactor = 1.0;
    if (screenWidth < 320) {
      scaleFactor = 0.8;
    } else if (screenWidth < 375) {
      scaleFactor = 0.85;
    } else if (screenWidth < 414) {
      scaleFactor = 0.9;
    }
    
    return baseSize * scaleFactor;
  }

  static double getPaddingSize(BuildContext context, {required double baseSize}) {
    _ensureInitialized(context);
    
    double scaleFactor = 1.0;
    if (screenWidth < 320) {
      scaleFactor = 0.7;
    } else if (screenWidth < 375) {
      scaleFactor = 0.8;
    } else if (screenWidth < 414) {
      scaleFactor = 0.9;
    }
    
    return baseSize * scaleFactor;
  }
  
  // Determinar tipo de dispositivo
  static DeviceType getDeviceType(BuildContext context) {
    _ensureInitialized(context);
    
    if (screenWidth > 900) return DeviceType.desktop;
    if (screenWidth > 600) return DeviceType.tablet;
    return DeviceType.phone;
  }
}

// Enumeración para tipos de dispositivo
enum DeviceType { phone, tablet, desktop }

// Extensiones para sintaxis limpia
extension SizeExtension on num {
  double get w => AdaptiveSize.w(toDouble());
  double get h => AdaptiveSize.h(toDouble());
  double get sp => AdaptiveSize.sp(toDouble());
}