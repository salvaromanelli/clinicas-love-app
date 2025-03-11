import 'package:flutter/material.dart';
import 'services/profile_service.dart';
import 'services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _myReviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Obtener el ID del usuario autenticado
      final userId = await _authService.getCurrentUserId();
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      
      // Obtener reseñas desde Supabase
      final reviews = await _profileService.getUserReviews(userId);
      
      setState(() {
        _myReviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
      print("Error al cargar reseñas: $e");
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar reseñas: ${e.toString()}'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button and title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Mis Reseñas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Promotion banner
            _buildPromotionBanner(),
            
            // Reviews section title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text(
                'Mis reseñas anteriores',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            // Reviews list
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _myReviews.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Aún no has dejado ninguna reseña.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _myReviews.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemBuilder: (context, index) {
                        final review = _myReviews[index];
                        return _buildReviewCard(review);
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

Widget _buildPromotionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1980E6), Color(0xFF0077CC)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1980E6).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Elemento decorativo de fondo
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            // Elemento decorativo de fondo
            Positioned(
              left: -15,
              bottom: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            // Contenido principal
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showGoogleReviewsDialog(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 28,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reemplazar Row con un widget que maneje mejor el espacio
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: const [
                                Text(
                                  '¡Obtén 15% de Descuento!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  Icons.verified,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Comparte tu experiencia en Google Reviews',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'COMPARTIR',
                          style: TextStyle(
                            color: Color(0xFF1980E6),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Reemplazar parte del _buildReviewCard
Widget _buildReviewCard(Map<String, dynamic> review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: const Color(0xFF1C2126),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review['clinic'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildRatingStars(review['rating']),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review['text'],
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fecha: ${_formatDate(review['date'])}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                review['posted_to_google']
                  ? _buildGoogleBadge()
                  : TextButton(
                      onPressed: () => _shareExistingReview(review),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Compartir en Google',
                        style: TextStyle(
                          color: Color(0xFF1980E6),
                          fontSize: 12,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < rating.ceil() && index >= rating.floor()) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 16);
        }
      }),
    );
  }

  Widget _buildGoogleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle, color: Colors.green, size: 12),
          SizedBox(width: 4),
          Text(
            'Publicada en Google',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final parts = dateString.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  void _showGoogleReviewsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF1C2126),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¡Obtén 15% de Descuento!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Comparte tu experiencia en Google Reviews y recibe un 15% de descuento en tu próximo tratamiento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.rate_review,
                    size: 60,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1980E6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _openGoogleReviews();
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.star, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Escribir Reseña',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showHowItWorksDialog();
                  },
                  child: const Text(
                    '¿Cómo funciona?',
                    style: TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF1C2126),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cómo obtener tu 15% de descuento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInstructionStep('1', 'Haz clic en "Escribir Reseña"'),
                _buildInstructionStep('2', 'Comparte tu experiencia en Google'),
                _buildInstructionStep('3', 'Toma una captura de pantalla de tu reseña'),
                _buildInstructionStep('4', 'Muestra la captura en recepción al agendar tu próximo tratamiento'),
                _buildInstructionStep('5', '¡Disfruta de tu 15% de descuento!'),
                const SizedBox(height: 20),
                const Text(
                  'Términos y condiciones:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Descuento válido por 3 meses\n• Aplicable en tratamientos seleccionados\n• No acumulable con otras promociones',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Entendido',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1980E6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGoogleReviews() async {
    // URL de Google Maps para la ubicación del negocio
    // Reemplaza este URL con el de tu negocio real
    const String googleReviewUrl = 'https://g.co/kgs/No6pWjU';
    
    // Aquí implementarías la lógica para abrir el URL (con url_launcher package)
     try {
      await launchUrl(Uri.parse(googleReviewUrl));
    } catch (e) {
      print('No se pudo abrir la URL: $e');
    }
    
    // Por ahora, solo mostraremos un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo Google Reviews...'),
        backgroundColor: Color(0xFF1980E6),
      ),
    );
    
    // También registramos que el usuario inició el proceso
    _registerReviewAttempt();
  }

  void _registerReviewAttempt() async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _profileService.registerReviewAttempt(userId);
        
        // Actualizar la interfaz después de registrar el intento
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias! Tu descuento del 15% ha sido registrado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Recargar las reseñas después de un breve retraso
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _loadReviews(); // Recargar las reseñas para actualizar el estado
        }
      }
    } catch (e) {
      print('Error al registrar intento de reseña: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar la reseña: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Método para compartir una reseña existente en Google
  void _shareExistingReview(Map<String, dynamic> review) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2126),
        title: const Text(
          '¿Compartir esta reseña?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Compartirás esta reseña en Google Maps para obtener un 15% de descuento.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1980E6),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Compartir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Crear texto pre-formateado para la reseña
      final reviewText = '${review['text']}\n\nReseña de ${review['clinic']} - ${review['rating']}/5 ⭐';
      
      // URL de Google Maps para la ubicación del negocio
      const String googleReviewUrl = 'https://g.co/kgs/No6pWjU';
      
      try {
        // Abrir la página de reseñas
        await launchUrl(Uri.parse(googleReviewUrl));
        
        // Registrar que esta reseña específica se compartió en Google
        final userId = await _authService.getCurrentUserId();
        if (userId != null) {
          await _profileService.registerReviewAttempt(
            userId, 
            reviewId: review['id']
          );
          
          // Actualizar la UI después de un momento
          await Future.delayed(const Duration(seconds: 1));
          _loadReviews();
        }
      } catch (e) {
        print('No se pudo abrir la URL: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al abrir Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
}