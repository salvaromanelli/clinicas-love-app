class Profile {
  final int id;
  final String name;
  final String email;
  final String? location;
  final String? avatarUrl;

  Profile({
    required this.id,
    required this.name,
    required this.email,
    this.location,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      location: json['location'],
      avatarUrl: json['avatar_url'],
    );
  }
}