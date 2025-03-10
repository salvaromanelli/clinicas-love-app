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

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  // Método para mostrar opciones de imagen (cámara o galería)
  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF293038),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                '¿Cómo quieres compartir tu experiencia?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1980E6)),
              title: const Text('Tomar una foto ahora', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1980E6)),
              title: const Text('Seleccionar de la galería', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            const SizedBox(height: 16),
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
      _showErrorSnackBar('Error al tomar la foto: $e');
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
      _showErrorSnackBar('Error al seleccionar imagen: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para compartir en Instagram usando share_plus
  Future<void> _shareToInstagram() async {
    if (_selectedImagePath == null) {
      _showErrorSnackBar('Por favor selecciona o toma una imagen primero');
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
        subject: 'Mi experiencia en Clínicas Love',
        text: '¡Mi experiencia en Clínicas Love! @clinicaslove #clinicaslove #tratamientoestetico',
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF293038),
        title: const Text(
          '¿Compartiste en Instagram?', 
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Confirmás que compartiste la imagen en Instagram?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'No',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateDiscountCode();
              _saveDiscountToSupabase();
              _showSuccessDialog();
            },
            child: const Text(
              'Sí, lo compartí',
              style: TextStyle(color: Color(0xFF1980E6)),
            ),
          ),
        ],
      ),
    );
  }

  // Método para compartir con Share_plus en otras redes sociales
  Future<void> _shareImageWithSharePlus() async {
    if (_selectedImagePath == null) {
      _showErrorSnackBar('Por favor selecciona o toma una imagen primero');
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
        subject: 'Mi experiencia en Clínicas Love',
        text: '¡Mi experiencia en Clínicas Love! @clinicaslove #clinicaslove #tratamientoestetico',
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
      _showErrorSnackBar('Por favor ingresa tu nombre de usuario de Instagram');
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
        _showErrorSnackBar('Debes iniciar sesión para guardar el descuento');
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF293038),
        title: const Text(
          '¡Gracias por compartir!', 
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Has ganado un 10% de descuento en tu próximo tratamiento.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1980E6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _discountCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _discountCode));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código de descuento copiado'),
                          backgroundColor: Color(0xFF1980E6),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'El descuento ha sido guardado en tu perfil y es válido por 90 días.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Aceptar',
              style: TextStyle(color: Color(0xFF1980E6)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
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
                            height: 80.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48.0),
                  ],
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Comparte tu Experiencia',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        
                        // Imagen seleccionada o mensaje para seleccionar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: GestureDetector(
                            onTap: _showImageSourceOptions, // Nuevo método para mostrar opciones
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: _selectedImagePath != null
                                  ? Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Image.file(
                                          File(_selectedImagePath!),
                                          width: double.infinity,
                                          height: 300,
                                          fit: BoxFit.cover,
                                        ),
                                        // Botón para cambiar imagen
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1980E6),
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.white),
                                              onPressed: _showImageSourceOptions,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 300,
                                      color: const Color(0xFF293038),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            color: Color(0xFF1980E6),
                                            size: 64,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Toca para tomar o seleccionar una imagen',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16.0,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Muestra tu experiencia en Clínicas Love',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14.0,
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
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'Comparte y obtén 10% de descuento',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24.0,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12.0),
                              Text(
                                'Toma una foto después de tu tratamiento o selecciona una de tu galería, compártela en Instagram Stories y recibe un 10% de descuento en tu próximo tratamiento.',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24.0),
                              
                              // Formulario para ingresar usuario de Instagram
                              Form(
                                key: _formKey,
                                child: TextFormField(
                                  controller: _tagController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Tu usuario de Instagram',
                                    labelStyle: TextStyle(color: Colors.grey),
                                    prefixIcon: Icon(Icons.alternate_email, color: Color(0xFF1980E6)),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.grey),
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Color(0xFF1980E6)),
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.red),
                                      borderRadius: BorderRadius.all(Radius.circular(10)),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Por favor ingresa tu usuario de Instagram';
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
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              // Botón para compartir en Instagram Stories
                              ElevatedButton.icon(
                                onPressed: _selectedImagePath == null || _isLoading 
                                    ? null 
                                    : _shareToInstagram,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE1306C), // Color de Instagram
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                    vertical: 16.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24.0),
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  disabledBackgroundColor: const Color(0xFFE1306C).withOpacity(0.5),
                                ),
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Compartir en Instagram Stories',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Botón para compartir en otras apps
                              ElevatedButton.icon(
                                onPressed: _selectedImagePath == null || _isLoading 
                                    ? null 
                                    : _shareImageWithSharePlus,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1980E6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32.0,
                                    vertical: 16.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24.0),
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  disabledBackgroundColor: const Color(0xFF1980E6).withOpacity(0.5),
                                ),
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Compartir en otras redes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Botón para verificar publicación
                              TextButton(
                                onPressed: _isLoading ? null : _verifyInstagramPost,
                                child: const Text(
                                  'Ya compartí, verificar mi post',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16.0,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
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
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF1980E6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}