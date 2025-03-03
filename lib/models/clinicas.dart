class Clinica {
  final String id;
  final String nombre;
  final String direccion;
  final String telefono;
  final String? horario;
  final String? imagen;
  final double latitud;
  final double longitud;
  final double? rating;
  double? distancia; // Distancia desde la ubicación del usuario

  Clinica({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    this.horario,
    this.imagen,
    required this.latitud,
    required this.longitud,
    this.rating,
    this.distancia,
  });

  factory Clinica.fromJson(Map<String, dynamic> json) {
    return Clinica(
      id: json['id'],
      nombre: json['name'],
      direccion: json['address'],
      telefono: json['phone_number'],
      horario: json['schedule'],
      imagen: json['image_url'],
      latitud: (json['latitude'] is int) 
          ? (json['latitude'] as int).toDouble() 
          : json['latitude'] as double,
      longitud: (json['longitude'] is int) 
          ? (json['longitude'] as int).toDouble() 
          : json['longitude'] as double,
      rating: json['rating']?.toDouble(),
    );
  }
}