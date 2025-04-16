import 'package:flutter/material.dart';

class AdaptiveSize {
  static double getIconSize(BuildContext context, {required double baseSize}) {
    final width = MediaQuery.of(context).size.width;
    
    double scaleFactor = 1.0;
    if (width < 320) {
      scaleFactor = 0.75;
    } else if (width < 375) {
      scaleFactor = 0.85;
    } else if (width < 414) {
      scaleFactor = 0.95;
    }
    
    return baseSize * scaleFactor;
  }

  static double getLogoSize(BuildContext context, {required double baseSize}) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    
    final smallerDimension = width < height ? width : height;
    
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
    final width = MediaQuery.of(context).size.width;
    
    double scaleFactor = 1.0;
    if (width < 320) {
      scaleFactor = 0.8;
    } else if (width < 375) {
      scaleFactor = 0.85;
    } else if (width < 414) {
      scaleFactor = 0.9;
    }
    
    return baseSize * scaleFactor;
  }

    static double getPaddingSize(BuildContext context, {required double baseSize}) {
    final width = MediaQuery.of(context).size.width;
    
    double scaleFactor = 1.0;
    if (width < 320) {
      scaleFactor = 0.7; // Menor padding para pantallas muy pequeñas
    } else if (width < 375) {
      scaleFactor = 0.8; // Para pantallas iPhone SE o similares
    } else if (width < 414) {
      scaleFactor = 0.9; // Para pantallas iPhone 8 Plus o similares
    }
    
    return baseSize * scaleFactor;
  }

}