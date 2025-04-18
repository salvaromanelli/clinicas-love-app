import 'package:flutter/material.dart';
import 'services/profile_service.dart';
import 'services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; 

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
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Definir si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Obtener localizaciones
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button and title
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: AdaptiveSize.getIconSize(context, baseSize: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Mis Reseñas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 18.sp : 20.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Promotion banner
            _buildPromotionBanner(isSmallScreen),
            
            // Reviews section title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Text(
                'Mis reseñas anteriores',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 16.sp : 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            // Reviews list
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _myReviews.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'Aún no has dejado ninguna reseña.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _myReviews.length,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemBuilder: (context, index) {
                        final review = _myReviews[index];
                        return _buildReviewCard(review, isSmallScreen);
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionBanner(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1980E6), Color(0xFF0077CC)],
        ),
        borderRadius: BorderRadius.circular(16.w),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1980E6).withOpacity(0.3),
            blurRadius: 8.w,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.w),
        child: Stack(
          children: [
            // Elementos decorativos de fondo
            Positioned(
              right: -20.w,
              top: -20.h,
              child: Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              left: -15.w,
              bottom: -15.h,
              child: Container(
                width: 80.w,
                height: 80.h,
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
                borderRadius: BorderRadius.circular(16.w),
                onTap: () => _showGoogleReviewsDialog(isSmallScreen),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: AdaptiveSize.getIconSize(context, baseSize: 28),
                          ),
                        ],
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6.w,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '¡Obtén 15% de Descuento!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  Icons.verified,
                                  color: Colors.amber,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Comparte tu experiencia en Google Reviews',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 12.sp : 14.sp,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.w),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4.w,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Text(
                          'COMPARTIR',
                          style: TextStyle(
                            color: const Color(0xFF1980E6),
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 10.sp : 12.sp,
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

  Widget _buildReviewCard(Map<String, dynamic> review, bool isSmallScreen) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      color: const Color(0xFF1C2126),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    review['clinic'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 14.sp : 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildRatingStars(review['rating'], isSmallScreen),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              review['text'],
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fecha: ${_formatDate(review['date'])}',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: isSmallScreen ? 10.sp : 12.sp,
                  ),
                ),
                review['posted_to_google']
                  ? _buildGoogleBadge(isSmallScreen)
                  : TextButton(
                      onPressed: () => _shareExistingReview(review, isSmallScreen),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Compartir en Google',
                        style: TextStyle(
                          color: const Color(0xFF1980E6),
                          fontSize: isSmallScreen ? 10.sp : 12.sp,
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

  Widget _buildRatingStars(double rating, bool isSmallScreen) {
    final iconSize = AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 14 : 16);
    
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return Icon(Icons.star, color: Colors.amber, size: iconSize);
        } else if (index < rating.ceil() && index >= rating.floor()) {
          return Icon(Icons.star_half, color: Colors.amber, size: iconSize);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: iconSize);
        }
      }),
    );
  }

  Widget _buildGoogleBadge(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle, 
            color: Colors.green, 
            size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 10 : 12),
          ),
          SizedBox(width: 4.w),
          Text(
            'Publicada en Google',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 10.sp : 12.sp,
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

  void _showGoogleReviewsDialog(bool isSmallScreen) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Reinicializar AdaptiveSize en el builder del diálogo
        AdaptiveSize.initialize(context);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.w),
          ),
          backgroundColor: const Color(0xFF1C2126),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Obtén 15% de Descuento!',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18.sp : 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Text(
                  'Comparte tu experiencia en Google Reviews y recibe un 15% de descuento en tu próximo tratamiento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 20.h),
                Container(
                  height: isSmallScreen ? 100.h : 120.h,
                  width: isSmallScreen ? 100.w : 120.w,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.rate_review,
                    size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 50 : 60),
                    color: Colors.white54,
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1980E6),
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.w),
                    ),
                  ),
                  onPressed: () {
                    _openGoogleReviews();
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star, 
                        color: Colors.white,
                        size: AdaptiveSize.getIconSize(context, baseSize: 20),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Escribir Reseña',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showHowItWorksDialog(isSmallScreen);
                  },
                  child: Text(
                    '¿Cómo funciona?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmallScreen ? 12.sp : 14.sp,
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

  void _showHowItWorksDialog(bool isSmallScreen) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Reinicializar AdaptiveSize en el builder del diálogo
        AdaptiveSize.initialize(context);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.w),
          ),
          backgroundColor: const Color(0xFF1C2126),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cómo obtener tu 15% de descuento',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16.sp : 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16.h),
                _buildInstructionStep('1', 'Haz clic en "Escribir Reseña"', isSmallScreen),
                _buildInstructionStep('2', 'Comparte tu experiencia en Google', isSmallScreen),
                _buildInstructionStep('3', 'Toma una captura de pantalla de tu reseña', isSmallScreen),
                _buildInstructionStep('4', 'Muestra la captura en recepción al agendar tu próximo tratamiento', isSmallScreen),
                _buildInstructionStep('5', '¡Disfruta de tu 15% de descuento!', isSmallScreen),
                SizedBox(height: 20.h),
                Text(
                  'Términos y condiciones:',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '• Descuento válido por 3 meses\n• Aplicable en tratamientos seleccionados\n• No acumulable con otras promociones',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10.sp : 12.sp,
                    color: Colors.white60,
                  ),
                ),
                SizedBox(height: 20.h),
                Align(
                  alignment: Alignment.center,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.w),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Entendido',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 12.sp : 14.sp,
                      ),
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

  Widget _buildInstructionStep(String number, String text, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24.w,
            height: 24.h,
            decoration: const BoxDecoration(
              color: Color(0xFF1980E6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGoogleReviews() async {
    // URL de Google Maps para la ubicación del negocio
    const String googleReviewUrl = 'https://g.co/kgs/No6pWjU';
    
    try {
      await launchUrl(Uri.parse(googleReviewUrl));
    } catch (e) {
      print('No se pudo abrir la URL: $e');
    }
    
    // Mostrar mensaje
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abriendo Google Reviews...'),
        backgroundColor: Color(0xFF1980E6),
      ),
    );
    
    // Registrar intento
    _registerReviewAttempt();
  }

  void _registerReviewAttempt() async {
    try {
      final userId = await _authService.getCurrentUserId();
      if (userId != null) {
        await _profileService.registerReviewAttempt(userId);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias! Tu descuento del 15% ha sido registrado'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _loadReviews();
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

  void _shareExistingReview(Map<String, dynamic> review, bool isSmallScreen) async {
    // Reinicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C2126),
        title: Text(
          '¿Compartir esta reseña?',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 16.sp : 18.sp,
          ),
        ),
        content: Text(
          'Compartirás esta reseña en Google Maps para obtener un 15% de descuento.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 12.sp : 14.sp,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.w),
        ),
        contentPadding: EdgeInsets.all(16.w),
        actionsPadding: EdgeInsets.only(right: 16.w, bottom: 8.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(fontSize: isSmallScreen ? 12.sp : 14.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1980E6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.w),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 12.w, 
                vertical: isSmallScreen ? 6.h : 8.h
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Compartir',
              style: TextStyle(
                fontSize: isSmallScreen ? 12.sp : 14.sp,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Crear texto pre-formateado para la reseña
      final reviewText = '${review['text']}\n\nReseña de ${review['clinic']} - ${review['rating']}/5 ⭐';
      
      // URL de Google Maps
      const String googleReviewUrl = 'https://g.co/kgs/No6pWjU';
      
      try {
        await launchUrl(Uri.parse(googleReviewUrl));
        
        final userId = await _authService.getCurrentUserId();
        if (userId != null) {
          await _profileService.registerReviewAttempt(
            userId, 
            reviewId: review['id']
          );
          
          await Future.delayed(const Duration(seconds: 1));
          _loadReviews();
        }
      } catch (e) {
        print('No se pudo abrir la URL: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al abrir Google Maps',
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}