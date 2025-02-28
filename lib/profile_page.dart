import 'package:flutter/material.dart';
import 'models/profile_model.dart';
import 'services/profile_service.dart';
import 'services/auth_service.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();  // Add this line
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

Future<void> _loadProfile() async {
  try {
    final token = await _authService.getToken();
    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    final profile = await _profileService.getProfile(token);
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error loading profile: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
              // Back arrow and title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              // Profile section
              Row(
                children: [
                  Container(
                    width: 80.0,
                    height: 80.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                    ),
                    child: ClipOval(
                      child: _profile?.avatarUrl != null
                        ? Image.network(
                            _profile!.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.white,
                              );
                            },
                          )
                        : const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                    ),
                  ),
                  const SizedBox(width: 16.0), // Added comma here
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?.name ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _profile?.location ?? 'No location',
                        style: const TextStyle(
                          color: Color(0xFF9DABB8),
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32.0),

              // Menu items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildMenuItem('Contact Information'),
                      _buildMenuItem('Payment methods'),
                      _buildMenuItem('My Wishlist'),
                      _buildMenuItem('Favorites'),
                      _buildMenuItem('My Reviews'),
                      _buildMenuItem('Gift Cards'),
                    ],
                  ),
                ),
              ),

              // Logout button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleLogout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2126),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    child: const Text(
                      'Log out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> _handleLogout() async {
  final authService = AuthService();
  await authService.logout();
  if (!mounted) return;
  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
}
// Replace the existing _buildMenuItem method
Widget _buildMenuItem(String title) {
  return GestureDetector(
    onTap: () {
      switch (title) {
        case 'Contact Information':
          Navigator.pushNamed(context, '/contact-info');
          break;
        case 'Payment methods':
          Navigator.pushNamed(context, '/payment-methods');
          break;
        case 'My Wishlist':
          Navigator.pushNamed(context, '/wishlist');
          break;
        case 'Favorites':
          Navigator.pushNamed(context, '/favorites');
          break;
        case 'My Reviews':
          Navigator.pushNamed(context, '/reviews');
          break;
        case 'Gift Cards':
          Navigator.pushNamed(context, '/gift-cards');
          break;
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF2A2F37),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16.0,
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF9DABB8),
          ),
        ],
      ),
    ),
  );
}
}