import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'services/youcam_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class YouCamTreatmentSimulator extends StatefulWidget {
  const YouCamTreatmentSimulator({Key? key}) : super(key: key);

  @override
  State<YouCamTreatmentSimulator> createState() => _YouCamTreatmentSimulatorState();
}

class _YouCamTreatmentSimulatorState extends State<YouCamTreatmentSimulator> {
  final ImagePicker _picker = ImagePicker();
  late final YouCamService _youCamService;

@override
void initState() {
  super.initState();
  
  // Inicializar el servicio con la API key del archivo .env
  final apiKey = dotenv.env['YOUCAM_API_KEY'] ?? '';
  _youCamService = YouCamService(apiKey: apiKey);
  
  if (apiKey.isEmpty) {
    debugPrint('⚠️ ADVERTENCIA: No se encontró API key para YouCam');
    // Opcionalmente mostrar un mensaje
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('YouCam API no configurada - usando modo de demostración'),
          backgroundColor: Colors.orange,
        ),
      );
    });
  }
}
  
  // Estado de la imagen
  File? _selectedImage;
  File? _processedImage;
  bool _showSideBySide = false;
  bool _isProcessing = false;
  String _errorMessage = '';
  
  // Opciones de tratamiento
  String _selectedTreatment = 'lips';
  double _intensity = 0.5;
  
  // Mapeo de tratamientos disponibles
  final Map<String, String> _treatmentOptions = {
    'lips': 'Aumento de labios',
    'nose': 'Rinomodelación',
    'botox': 'Botox',
    'fillers': 'Rellenos faciales',
    'skincare': 'Cuidado de la piel',
    'lifting': 'Lifting facial',
    // Nuevos tratamientos de AI Photo Enhance
    'face_enhance': 'IA Realce Facial',
    'face_refine': 'IA Refinamiento Facial',
    'face_shape': 'IA Modelado Facial',
    'eye_enhance': 'IA Realce de Ojos',
    'skin_retouch': 'IA Retoque de Piel',
  };

  
  // Configuraciones específicas para cada tratamiento
  final Map<String, Map<String, dynamic>> _treatmentConfigs = {
    'lips': {
      'method': 'makeup',
      'part': 'lips',
      'intensity': 0.5
    },
    'nose': {
      'method': 'reshape',
      'part': 'nose',
      'intensity': 0.5
    },
    'botox': {
      'method': 'smooth',
      'part': 'forehead',
      'intensity': 0.5
    },
    'fillers': {
      'method': 'contour',
      'part': 'cheeks',
      'intensity': 0.5
    },
    'skincare': {
      'method': 'cleanse',
      'intensity': 0.5
    },
    'lifting': {
      'method': 'lift',
      'intensity': 0.5
    },
    // Nuevas configuraciones para AI Photo Enhance
    'face_enhance': {
      'method': 'enhance',
      'part': 'face',
      'enhanceType': 'natural',
      'intensity': 0.5
    },
    'face_refine': {
      'method': 'enhance',
      'part': 'face',
      'enhanceType': 'refine',
      'intensity': 0.5
    },
    'face_shape': {
      'method': 'enhance',
      'part': 'face',
      'enhanceType': 'shape',
      'intensity': 0.5
    },
    'eye_enhance': {
      'method': 'enhance',
      'part': 'eyes',
      'enhanceType': 'brighten',
      'intensity': 0.5
    },
    'skin_retouch': {
      'method': 'enhance',
      'part': 'skin',
      'enhanceType': 'smooth',
      'intensity': 0.5
    },
  };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1600,
      );
      
      if (pickedFile == null) {
        return;
      }
      
      setState(() {
        _selectedImage = File(pickedFile.path);
        _processedImage = null;
        _showSideBySide = false;
      });
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
    }
  }
  
  Future<void> _applyTreatment() async {
    if (_selectedImage == null) {
      _showError('Selecciona una imagen primero');
      return;
    }
    
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = '';
      });
      
      
      // Preparar los parámetros según el tratamiento seleccionado
      final config = _treatmentConfigs[_selectedTreatment] ?? {};
      config['intensity'] = _intensity; // Actualizar con intensidad actual
      
      // Identificar si es un tratamiento de AI Photo Enhance
      final bool isAIEnhancement = _selectedTreatment.contains('enhance') ||
                                   _selectedTreatment == 'face_refine' ||
                                   _selectedTreatment == 'face_shape' ||
                                   _selectedTreatment == 'skin_retouch';
                                   
      if (isAIEnhancement) {
        debugPrint('Aplicando AI Photo Enhance: $_selectedTreatment');
      }
      
      debugPrint('Aplicando tratamiento: $_selectedTreatment');
      debugPrint('Configuración: $config');
      
      // Usar el método con caché para mejor rendimiento
      final result = await _youCamService.getFromCacheOrApply(
        image: _selectedImage!,
        treatmentType: _selectedTreatment,
        intensity: _intensity,
        params: config,
      );
      
      // Si necesitas metadatos, usa el otro método
      final resultWithMetadata = await _youCamService.applyTreatmentWithMetadata(
        image: _selectedImage!,
        treatmentType: _selectedTreatment,
        intensity: _intensity,
        params: config,
      );
      
      if (resultWithMetadata != null) {
        setState(() {
          _processedImage = resultWithMetadata.processedImage;
          _showSideBySide = true;
          // Si necesitas usar metadata: resultWithMetadata.metadata
        });
      } else if (result != null) {
        // Fallback si el método con metadata falla
        setState(() {
          _processedImage = result;
          _showSideBySide = true;
        });
      } else {
        _showError('No se pudo procesar la imagen');
      }
    } catch (e) {
      _showError('Error al aplicar tratamiento: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _saveToGallery() async {
    if (_processedImage == null) {
      _showError('No hay imagen para guardar');
      return;
    }
    
    try {
      final result = await ImageGallerySaver.saveFile(_processedImage!.path);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen guardada en la galería'))
      );
    } catch (e) {
      _showError('Error al guardar en galería: $e');
    }
  }
  
  Future<void> _shareImage() async {
    if (_processedImage == null) {
      _showError('No hay imagen para compartir');
      return;
    }
    
    try {
      await Share.shareXFiles(
        [XFile(_processedImage!.path)],
        text: 'Mi simulación de ${_treatmentOptions[_selectedTreatment]}',
      );
    } catch (e) {
      _showError('Error al compartir: $e');
    }
  }
  
  void _resetImage() {
    setState(() {
      _processedImage = null;
      _showSideBySide = false;
    });
  }
  
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    
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
      appBar: AppBar(
        title: const Text('Simulador de Tratamientos'),
        backgroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // Sección de selección de tratamiento
          _buildTreatmentSelector(),
          
          // Sección principal - imagen o carga
          Expanded(
            child: _buildImageSection(),
          ),
          
          // Sección de controles
          _buildControlsSection(),
        ],
      ),
    );
  }

  
Widget _buildTreatmentSelector() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Selector de categoría
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryButton('Tratamientos Clínicos', 
                  ['lips', 'nose', 'botox', 'fillers', 'skincare', 'lifting']),
                const SizedBox(width: 8),
                _buildCategoryButton('AI Face Enhancement',
                  ['face_enhance', 'face_refine', 'face_shape', 'eye_enhance', 'skin_retouch']),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Dropdown de tratamientos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              dropdownColor: Colors.grey[900],
              decoration: const InputDecoration(
                labelText: 'Tipo de tratamiento',
                labelStyle: TextStyle(color: Colors.white),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              value: _selectedTreatment,
              items: _treatmentOptions.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedTreatment = value;
                    _processedImage = null;
                    _showSideBySide = false;
                  });
                }
              },
            ),
          ),
          
          // Slider de intensidad
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Text('Intensidad:', style: TextStyle(color: Colors.white)),
                Expanded(
                  child: Slider(
                    value: _intensity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: (_intensity * 100).toInt().toString() + '%',
                    onChanged: (value) {
                      setState(() {
                        _intensity = value;
                      });
                    },
                  ),
                ),
                Text('${(_intensity * 100).toInt()}%', 
                     style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageSection() {
    if (_isProcessing) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Procesando imagen...', 
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _errorMessage,
            style: TextStyle(color: Colors.red[300]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    if (_selectedImage == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_a_photo,
                size: 80,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto'),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Abrir galería'),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_showSideBySide && _processedImage != null) {
      // Mostrar comparación lado a lado
      return _buildSideBySideView();
    }
    
    // Mostrar solo la imagen seleccionada
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
  
  Widget _buildSideBySideView() {
    return Row(
      children: [
        // Imagen original
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _selectedImage!,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: const Text(
                      'Original',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Divisor
        Container(width: 2, color: Colors.white),
        
        // Imagen procesada
        Expanded(
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _processedImage!,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(
                      _treatmentOptions[_selectedTreatment] ?? 'Procesada',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // Añadir indicador de intensidad
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(
                      'Intensidad: ${(_intensity * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Añadir este nuevo método a la clase _YouCamTreatmentSimulatorState
Widget _buildCategoryButton(String title, List<String> treatments) {
  final bool isSelected = treatments.contains(_selectedTreatment);
  
  return OutlinedButton(
    onPressed: () {
      // Mostrar bottom sheet con opciones de tratamiento
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        builder: (context) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.grey),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: treatments.length,
                    itemBuilder: (context, index) {
                      final treatment = treatments[index];
                      return ListTile(
                        title: Text(
                          _treatmentOptions[treatment] ?? treatment,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: treatment == _selectedTreatment
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                        onTap: () {
                          setState(() {
                            _selectedTreatment = treatment;
                            _processedImage = null;
                            _showSideBySide = false;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
    style: OutlinedButton.styleFrom(
      backgroundColor: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.grey,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    child: Text(
      title,
      style: TextStyle(
        color: isSelected ? Colors.blue : Colors.white,
      ),
    ),
  );
}
  
  Widget _buildControlsSection() {
    if (_selectedImage == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mostrar resultados o botón para aplicar
          if (_processedImage != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón de guardar
                IconButton(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  tooltip: 'Guardar en galería',
                ),
                
                // Botón de compartir
                IconButton(
                  onPressed: _shareImage,
                  icon: const Icon(Icons.share, color: Colors.white),
                  tooltip: 'Compartir imagen',
                ),
                
                // Botón de reiniciar
                IconButton(
                  onPressed: _resetImage,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Reiniciar',
                ),
                
                // Botón para cambiar imagen
                IconButton(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  tooltip: 'Cambiar imagen',
                ),
              ],
            )
          else
            Column(
              children: [
                // Botón para aplicar el tratamiento
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text('Aplicar ${_treatmentOptions[_selectedTreatment] ?? "tratamiento"}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _isProcessing ? null : _applyTreatment,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Botón para cambiar imagen
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library, color: Colors.white70),
                      label: const Text('Otra imagen', style: TextStyle(color: Colors.white70)),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                    // Botón para tomar otra foto
                    TextButton.icon(
                      icon: const Icon(Icons.camera_alt, color: Colors.white70),
                      label: const Text('Otra foto', style: TextStyle(color: Colors.white70)),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}