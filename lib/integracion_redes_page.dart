import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile, ShareResult, ShareResultStatus;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/supabase.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart';

class IntegracionRedesPage extends StatefulWidget {
  const IntegracionRedesPage({super.key});

  @override
  State<IntegracionRedesPage> createState() => _IntegracionRedesPageState();
}

class _IntegracionRedesPageState extends State<IntegracionRedesPage> {
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _isLoading = false;
  bool _isDiscountGenerated = false;
  String _discountCode = '';
  String? _selectedImagePath;
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  late AppLocalizations localizations; 

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }
  
  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  // Método para mostrar opciones de imagen (cámara o galería)
  Future<void> _showImageSourceOptions() async {
    // Inicializar AdaptiveSize para el modal
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF293038),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AdaptiveSize.w(16)),
          topRight: Radius.circular(AdaptiveSize.w(16)),
        ),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: AdaptiveSize.h(16)),
              child: Text(
                localizations.get('how_to_share'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 16 : 18),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt, 
                color: const Color(0xFF1980E6),
                size: AdaptiveSize.getIconSize(context, baseSize: 24),
              ),
              title: Text(
                localizations.get('take_photo'), 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library, 
                color: const Color(0xFF1980E6),
                size: AdaptiveSize.getIconSize(context, baseSize: 24),
              ),
              title: Text(
                localizations.get('select_from_gallery'), 
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            SizedBox(height: AdaptiveSize.h(16)),
          ],
        );
      },
    );
  }

  // Método para tomar una foto con la cámara
  Future<void> _takePhoto() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImagePath = photo.path;
        });
      }
    } catch (e) {
      _showErrorSnackBar('${localizations.get('error_taking_photo')} $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para seleccionar imagen de la galería
  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      _showErrorSnackBar('${localizations.get('error_selecting_image')} $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para compartir en Instagram usando share_plus
  Future<void> _shareToInstagram() async {
    if (_selectedImagePath == null) {
      _showErrorSnackBar(localizations.get('select_image_first'));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear un XFile desde la ruta de la imagen
      final XFile imageFile = XFile(_selectedImagePath!);
      
      // Compartir usando share_plus
      final ShareResult result = await Share.shareXFiles(
        [imageFile],
        subject: localizations.get('my_experience_title'),
        text: localizations.get('my_experience_text'),
      );
      
      // Verificar si el usuario completó la acción de compartir
      if (result.status == ShareResultStatus.success || 
          result.status == ShareResultStatus.dismissed) {
        // Mostrar un diálogo de confirmación
        _showSharingConfirmationDialog();
      }
    } catch (e) {
      print("Error compartiendo: $e");
      _showErrorSnackBar('Error al compartir: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Diálogo para confirmar si compartió en Instagram
  void _showSharingConfirmationDialog() {
    setState(() {
      _isLoading = false;
    });
    
    // Inicializar AdaptiveSize para el diálogo
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF293038),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdaptiveSize.w(16)),
        ),
        title: Text(
          localizations.get('share_instagram_question'), 
          style: TextStyle(
            color: Colors.white,
            fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
          ),
        ),
        content: Text(
          localizations.get('confirm_instagram_share'),
          style: TextStyle(
            color: Colors.white70,
            fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
          ),
        ),
        contentPadding: EdgeInsets.all(AdaptiveSize.w(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: AdaptiveSize.w(16),
                vertical: AdaptiveSize.h(8),
              ),
            ),
            child: Text(
              localizations.get('no'),
              style: TextStyle(
                color: Colors.grey,
                fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateDiscountCode();
              _saveDiscountToSupabase();
              _showSuccessDialog();
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: AdaptiveSize.w(16),
                vertical: AdaptiveSize.h(8),
              ),
            ),
            child: Text(
              localizations.get('yes_shared'),
              style: TextStyle(
                color: const Color(0xFF1980E6),
                fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para compartir con Share_plus en otras redes sociales
  Future<void> _shareImageWithSharePlus() async {
    if (_selectedImagePath == null) {
      _showErrorSnackBar(localizations.get('select_image_first'));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Crear un XFile desde la ruta de la imagen
      final XFile imageFile = XFile(_selectedImagePath!);
      
      // Compartir usando share_plus
      final ShareResult result = await Share.shareXFiles(
        [imageFile],
        subject: localizations.get('my_experience_title'),
        text: localizations.get('my_experience_text'),
      );
      
      // Verificar si el usuario completó la acción de compartir
      if (result.status == ShareResultStatus.success || 
          result.status == ShareResultStatus.dismissed) {
        _generateDiscountCode();
        await _saveDiscountToSupabase();
        _showSuccessDialog();
      }
    } catch (e) {
      _showErrorSnackBar('Error al compartir: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para verificar la publicación en Instagram
  Future<void> _verifyInstagramPost() async {
    if (_tagController.text.trim().isEmpty) {
      _showErrorSnackBar(localizations.get('enter_instagram_username'));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Aquí simulamos la verificación con un delay
    // En una implementación real, se podría usar la API de Instagram
    await Future.delayed(const Duration(seconds: 2));

    _generateDiscountCode();
    await _saveDiscountToSupabase();
    _showSuccessDialog();

    setState(() {
      _isLoading = false;
    });
  }

  // Generar código de descuento aleatorio
  void _generateDiscountCode() {
    final uuid = const Uuid().v4().substring(0, 6).toUpperCase();
    setState(() {
      _discountCode = 'CL-$uuid';
      _isDiscountGenerated = true;
    });
  }

  // Guardar el descuento en Supabase
  Future<void> _saveDiscountToSupabase() async {
    try {
      final userId = _supabaseService.getCurrentUserId();
      
      if (userId == null) {
        _showErrorSnackBar(localizations.get('login_required'));
        return;
      }
      
      // Datos del descuento
      final discountData = {
        'user_id': userId,
        'code': _discountCode,
        'percentage': 10, // 10% de descuento
        'is_used': false,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'source': 'instagram_share'
      };
      
      // Guardar en la tabla discounts
      await _supabaseService.client
          .from('discounts')
          .insert(discountData);

    } catch (e) {
      print('Error guardando descuento: $e');
      // No mostramos el error al usuario para no arruinar la experiencia
      // pero registramos para depuración
    }
  }

  // Mostrar diálogo de éxito
  void _showSuccessDialog() {
    // Inicializar AdaptiveSize para el diálogo
    AdaptiveSize.initialize(context);
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF293038),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdaptiveSize.w(16)),
        ),
        title: Text(
          localizations.get('thanks_for_sharing'), 
          style: TextStyle(
            color: Colors.white,
            fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              localizations.get('discount_earned'),
              style: TextStyle(
                color: Colors.white70,
                fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
              ),
            ),
            SizedBox(height: AdaptiveSize.h(16)),
            Container(
              padding: EdgeInsets.all(AdaptiveSize.w(12)),
              decoration: BoxDecoration(
                color: const Color(0xFF1980E6),
                borderRadius: BorderRadius.circular(AdaptiveSize.w(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _discountCode,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 16 : 18),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy, 
                      color: Colors.white,
                      size: AdaptiveSize.getIconSize(context, baseSize: 20),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _discountCode));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.get('discount_copied'),
                            style: TextStyle(fontSize: AdaptiveSize.sp(14)),
                          ),
                          backgroundColor: const Color(0xFF1980E6),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: AdaptiveSize.h(16)),
            Text(
              localizations.get('discount_saved'),
              style: TextStyle(
                color: Colors.white70,
                fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        contentPadding: EdgeInsets.all(AdaptiveSize.w(16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: AdaptiveSize.w(16),
                vertical: AdaptiveSize.h(8),
              ),
            ),
            child: Text(
              localizations.get('accept'),
              style: TextStyle(
                color: const Color(0xFF1980E6),
                fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: AdaptiveSize.sp(14)),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize para dimensiones responsivas
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Back button and logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: AdaptiveSize.getIconSize(context, baseSize: 20),
                      ),
                      padding: EdgeInsets.all(AdaptiveSize.w(8)),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: AdaptiveSize.h(isSmallScreen ? 60 : 80),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AdaptiveSize.w(48)),
                  ],
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(AdaptiveSize.w(16)),
                          child: Text(
                            localizations.get('share_experience'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AdaptiveSize.sp(isSmallScreen ? 20 : 24),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Imagen seleccionada o mensaje para seleccionar
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: AdaptiveSize.w(24)),
                          child: GestureDetector(
                            onTap: _showImageSourceOptions,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AdaptiveSize.w(12)),
                              child: _selectedImagePath != null
                                  ? Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Image.file(
                                          File(_selectedImagePath!),
                                          width: double.infinity,
                                          height: AdaptiveSize.h(isSmallScreen ? 250 : 300),
                                          fit: BoxFit.cover,
                                        ),
                                        // Botón para cambiar imagen
                                        Positioned(
                                          right: AdaptiveSize.w(10),
                                          bottom: AdaptiveSize.h(10),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1980E6),
                                              borderRadius: BorderRadius.circular(AdaptiveSize.w(30)),
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                Icons.edit, 
                                                color: Colors.white,
                                                size: AdaptiveSize.getIconSize(context, baseSize: 20),
                                              ),
                                              onPressed: _showImageSourceOptions,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: AdaptiveSize.h(isSmallScreen ? 250 : 300),
                                      color: const Color(0xFF293038),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            color: const Color(0xFF1980E6),
                                            size: AdaptiveSize.getIconSize(context, baseSize: 64),
                                          ),
                                          SizedBox(height: AdaptiveSize.h(16)),
                                          Text(
                                            localizations.get('tap_to_select'),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: AdaptiveSize.h(8)),
                                          Text(
                                            localizations.get('show_experience'),
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        
                        // Texto informativo
                        Padding(
                          padding: EdgeInsets.all(AdaptiveSize.w(24)),
                          child: Column(
                            children: [
                              Text(
                                localizations.get('share_get_discount'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: AdaptiveSize.sp(isSmallScreen ? 20 : 24),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AdaptiveSize.h(12)),
                              Text(
                                localizations.get('share_discount_explanation'),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AdaptiveSize.h(24)),
                              
                              // Formulario para ingresar usuario de Instagram
                              Form(
                                key: _formKey,
                                child: TextFormField(
                                  controller: _tagController,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: localizations.get('your_instagram_username'),
                                    labelStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.alternate_email, 
                                      color: const Color(0xFF1980E6),
                                      size: AdaptiveSize.getIconSize(context, baseSize: 20),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.grey),
                                      borderRadius: BorderRadius.all(Radius.circular(AdaptiveSize.w(10))),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFF1980E6)),
                                      borderRadius: BorderRadius.all(Radius.circular(AdaptiveSize.w(10))),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.all(Radius.circular(AdaptiveSize.w(10))),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: AdaptiveSize.w(16),
                                      vertical: AdaptiveSize.h(isSmallScreen ? 12 : 16),
                                    ),
                                    errorStyle: TextStyle(
                                      fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return localizations.get('enter_instagram_username_validation');
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Botones
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: AdaptiveSize.w(24)),
                          child: Column(
                            children: [
                              // Botón para compartir en Instagram Stories
                              ElevatedButton.icon(
                                onPressed: _selectedImagePath == null || _isLoading 
                                    ? null 
                                    : _shareToInstagram,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE1306C), // Color de Instagram
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AdaptiveSize.w(32),
                                    vertical: AdaptiveSize.h(isSmallScreen ? 12 : 16),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AdaptiveSize.w(24)),
                                  ),
                                  minimumSize: Size(double.infinity, AdaptiveSize.h(isSmallScreen ? 48 : 56)),
                                  disabledBackgroundColor: const Color(0xFFE1306C).withOpacity(0.5),
                                ),
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 20),
                                ),
                                label: Text(
                                  localizations.get('share_instagram_stories'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: AdaptiveSize.h(16)),
                              
                              // Botón para compartir en otras apps
                              ElevatedButton.icon(
                                onPressed: _selectedImagePath == null || _isLoading 
                                    ? null 
                                    : _shareImageWithSharePlus,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1980E6),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AdaptiveSize.w(32),
                                    vertical: AdaptiveSize.h(isSmallScreen ? 12 : 16),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AdaptiveSize.w(24)),
                                  ),
                                  minimumSize: Size(double.infinity, AdaptiveSize.h(isSmallScreen ? 48 : 56)),
                                  disabledBackgroundColor: const Color(0xFF1980E6).withOpacity(0.5),
                                ),
                                icon: Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 20),
                                ),
                                label: Text(
                                  localizations.get('share_other_networks'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: AdaptiveSize.h(16)),
                              
                              // Botón para verificar publicación
                              TextButton(
                                onPressed: _isLoading ? null : _verifyInstagramPost,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AdaptiveSize.w(16),
                                    vertical: AdaptiveSize.h(8),
                                  ),
                                ),
                                child: Text(
                                  localizations.get('already_shared'),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: AdaptiveSize.h(24)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Indicador de carga
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: SizedBox(
                    width: AdaptiveSize.w(40),
                    height: AdaptiveSize.h(40),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF1980E6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}