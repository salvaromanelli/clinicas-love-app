import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserModel {
  final String userId;
  final String? name;
  final String? profileImageUrl;
  
  UserModel({
    required this.userId,
    this.name,
    this.profileImageUrl,
  });

  // Convertir a JSON para guardar en SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Crear desde JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] as String,
      name: json['name'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool get isLoggedIn => _user != null;
  UserModel? get user => _user;
  
  UserProvider() {
    _loadUserData();
  }

  // Cargar datos del usuario guardados localmente
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    
    if (userJson != null) {
      try {
        // Convertir la cadena JSON a un Map
        final Map<String, dynamic> userData = Map<String, dynamic>.from(
          // Usar dart:convert para parsear el string JSON
          jsonDecode(userJson)
        );
        
        _user = UserModel.fromJson(userData);
        debugPrint('✅ Usuario cargado: ${_user?.name}, URL: ${_user?.profileImageUrl}');
        notifyListeners();
      } catch (e) {
        debugPrint('❌ Error cargando datos del usuario: $e');
      }
    } else {
      debugPrint('ℹ️ No hay datos de usuario guardados');
    }
  }

  // Guardar el usuario en SharedPreferences
  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user != null) {
      // Convertir a JSON string usando jsonEncode
      final String userJson = jsonEncode(_user!.toJson());
      await prefs.setString('user_data', userJson);
      debugPrint('💾 Datos de usuario guardados correctamente');
    } else {
      await prefs.remove('user_data');
      debugPrint('🗑️ Datos de usuario eliminados');
    }
  }

  // Establecer el usuario actual (login)
  void setUser(UserModel user) {
    _user = user;
    _saveUserData();
    notifyListeners();
  }
  
  // Cerrar sesión
  void logout() {
    _user = null;
    _saveUserData();
    notifyListeners();
    debugPrint('🚪 Usuario deslogueado en UserProvider');
  }

  // Actualizar solo la imagen de perfil
  void updateProfileImage(String imageUrl) {
    if (_user != null) {
      _user = UserModel(
        userId: _user!.userId,
        name: _user!.name,
        profileImageUrl: imageUrl,
      );
      _saveUserData();
      notifyListeners();
    }
  }
}