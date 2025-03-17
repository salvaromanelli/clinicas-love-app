import 'package:flutter/foundation.dart';
import 'dart:io';
import '../services/youcam_service.dart';

class YouCamProvider with ChangeNotifier {
  final YouCamService _service;
  bool _isProcessing = false;
  String? _errorMessage;

  YouCamProvider(this._service);

  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  Future<File?> simulateTreatment({
    required File imageFile,
    required String treatmentType,
    required double intensity,
  }) async {
    try {
      _isProcessing = true;
      _errorMessage = null;
      notifyListeners();

      // Configura los parámetros adecuados según el tipo de tratamiento
      Map<String, dynamic> params = {};
      
      switch (treatmentType) {
        case 'lips':
          params = {
            'lip_volume': (intensity * 100).toInt(),
            'lip_reshape': (intensity * 70).toInt(),
          };
          break;
        case 'nose':
          params = {
            'nose_reshape': (intensity * 100).toInt(),
            'nose_slim': (intensity * 80).toInt(),
          };
          break;
        case 'botox':
          params = {
            'wrinkle_reduction': (intensity * 100).toInt(),
          };
          break;
        case 'fillers':
          params = {
            'volume': (intensity * 100).toInt(),
            'face_slim': (intensity * 50).toInt(),
          };
          break;
        case 'skincare':
          params = {
            'skin_smoothing': (intensity * 100).toInt(),
            'texture_correction': (intensity * 100).toInt(),
          };
          break;
        case 'lifting':
          params = {
            'lifting': (intensity * 100).toInt(),
            'jaw_contour': (intensity * 50).toInt(),
          };
          break;
        default:
          params = {
            'skin_smoothing': (intensity * 100).toInt(),
          };
      }

      // Llama al servicio existente con los parámetros correctos
      final result = await _service.applyTreatment(
        image: imageFile, 
        treatmentType: treatmentType,
        params: params,
      );

      _isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = "Error al procesar la imagen: $e";
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}