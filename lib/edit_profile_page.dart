import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/profile_model.dart';
import 'services/profile_service.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart';

class EditProfilePage extends StatefulWidget {
  final Profile profile;

  const EditProfilePage({Key? key, required this.profile}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  late AppLocalizations localizations;
  
  final ProfileService _profileService = ProfileService();
  bool _isSaving = false;
  File? _imageFile;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.name ?? '';
    _locationController.text = widget.profile.location ?? '';
    _phoneController.text = widget.profile.phone ?? '';
    _emailController.text = widget.profile.email;
    _avatarUrl = widget.profile.avatarUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {

      final double maxSize = AdaptiveSize.screenWidth < 768 ? 800 : 1200;

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${localizations.get('image_selection_error')}: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Primero subir la imagen si se seleccionó una nueva
      String? newAvatarUrl;
      if (_imageFile != null) {
        newAvatarUrl = await _profileService.uploadAvatar(_imageFile!.path);
      }

      // Crear un perfil actualizado
      final updatedProfile = widget.profile.copyWith(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: newAvatarUrl ?? _avatarUrl,
      );

      // Guardar los cambios
      await _profileService.updateProfile(updatedProfile);

      if (!mounted) return;
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.get('profile_updated_success')),
          backgroundColor: Colors.green,
        ),
      );


      // Volver a la página anterior con el perfil actualizado
      Navigator.pop(context, updatedProfile);
    } catch (e) {
      if (!mounted) return;
      
      // Mostrar mensaje de error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localizations.get('profile_update_error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    AdaptiveSize.initialize(context);
  
    final isSmallScreen = AdaptiveSize.screenWidth < 360;

    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111418),
        foregroundColor: Colors.white,
        title: Text(
          localizations.get('edit_profile'),
          style: TextStyle(fontSize: 18.sp),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: AdaptiveSize.getIconSize(context, baseSize: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar edit section
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: isSmallScreen ? 100.w : 120.w,
                        height: isSmallScreen ? 100.h : 120.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.w,
                          ),
                        ),
                        child: ClipOval(
                          child: _imageFile != null
                            ? Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              )
                            : _avatarUrl != null
                              ? Image.network(
                                  _avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: AdaptiveSize.getIconSize(context, baseSize: 60),
                                      color: Colors.white,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.person,
                                  size: AdaptiveSize.getIconSize(context, baseSize: 60),
                                  color: Colors.white,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                                  backgroundColor: const Color(0xFF1980E6),
                                  radius: 22.w,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.camera_alt,
                                      size: AdaptiveSize.getIconSize(context, baseSize: 20),
                                    ),
                                    color: Colors.white,
                                    onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: const Color(0xFF1C2126),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.w)),
                                ),
                                builder: (BuildContext context) {
                                  // Usar AdaptiveSize dentro del builder también
                                  AdaptiveSize.initialize(context);
                                  final isSmallSheet = AdaptiveSize.screenWidth < 360;
                                  
                                  return SafeArea(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.w),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            localizations.get('select_photo'),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: isSmallSheet ? 16.sp : 18.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 16.h),
                                          ListTile(
                                            leading: Icon(
                                              Icons.photo_library, 
                                              color: Colors.white,
                                              size: AdaptiveSize.getIconSize(context, baseSize: 24),
                                            ),
                                            title: Text(
                                              localizations.get('gallery'), 
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.sp,
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.gallery);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(
                                              Icons.camera_alt, 
                                              color: Colors.white,
                                              size: AdaptiveSize.getIconSize(context, baseSize: 24),
                                            ),
                                            title: Text(
                                              localizations.get('camera'), 
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.sp,
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _pickImage(ImageSource.camera);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                
                // Form fields
                _buildTextField(
                  controller: _nameController,
                  label: localizations.get('full_name'),
                  icon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.get('please_enter_name');
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16.h),
                
                _buildTextField(
                  controller: _locationController,
                  label: localizations.get('location'),
                  icon: Icons.location_on_outlined,
                ),
                SizedBox(height: 16.h),
                
                _buildTextField(
                  controller: _phoneController,
                  label: localizations.get('phone'),
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16.h),
                
                _buildTextField(
                  controller: _emailController,
                  label: localizations.get('email'),
                  icon: Icons.email_outlined,
                  enabled: false,
                ),
                SizedBox(height: 32.h),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1980E6),
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12.h : 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.w),
                      ),
                      disabledBackgroundColor: const Color(0xFF1980E6).withOpacity(0.5),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.w,
                            ),
                          )
                        : Text(
                            localizations.get('save_changes'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14.sp : 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      style: TextStyle(color: Colors.white, fontSize: 16.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
        prefixIcon: Icon(
          icon, 
          color: Colors.grey[400],
          size: AdaptiveSize.getIconSize(context, baseSize: 22),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.w),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.w),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.w),
          borderSide: BorderSide(color: const Color(0xFF1980E6), width: 2.w),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
        filled: true,
        fillColor: const Color(0xFF1C2126),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}