import 'package:flutter/foundation.dart';

class Profile {
  final String id;
  String? name;
  final String email;
  String? phone;
  String? avatarUrl;
  String? location;
  final DateTime? createdAt;
  DateTime? updatedAt;

  Profile({
    required this.id,
    this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

factory Profile.fromJson(Map<String, dynamic> json) {
  return Profile(
    id: json['id'],
    name: json['full_name'] ?? json['name'],
    email: json['email'],
    phone: json['phone'] ?? json['phone_number'],
    avatarUrl: json['avatar_url'],
    location: json['location'], // Añadir esta línea
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
  );
}

Map<String, dynamic> toJson() {
  return {
    'full_name': name,
    'phone_number': phone,
    'avatar_url': avatarUrl,
    'location': location, // Añadir esta línea
    'updated_at': DateTime.now().toIso8601String(),
  };
}

  @override
  String toString() {
    return 'Profile{id: $id, name: $name, email: $email, phone: $phone, avatarUrl: $avatarUrl}';
  }

  // Opcional: añade un método de copia para facilitar la actualización
Profile copyWith({
  String? name,
  String? phone,
  String? avatarUrl,
  String? location,
}) {
  return Profile(
    id: id,
    name: name ?? this.name,
    email: email,
    phone: phone ?? this.phone,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    location: location ?? this.location,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
}