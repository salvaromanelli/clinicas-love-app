class Clinic {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phoneNumber;
  final String imageUrl;
  final List<String> services;
  final String schedule;
  final double rating;
  double? distance; // Distancia calculada desde la posición actual del usuario

  Clinic({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phoneNumber,
    required this.imageUrl,
    required this.services,
    required this.schedule,
    required this.rating,
    this.distance,
  });

  factory Clinic.fromJson(Map<String, dynamic> json) {
    List<String> services = [];
    if (json['services'] != null) {
      services = List<String>.from(json['services']);
    }
    
    return Clinic(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      phoneNumber: json['phone_number'],
      imageUrl: json['image_url'],
      services: services,
      schedule: json['schedule'],
      rating: json['rating'] ?? 4.5,
    );
  }
}