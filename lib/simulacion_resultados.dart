import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'providers/youcam_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Añadir esta importación
import 'package:path_provider/path_provider.dart'; // Añadir esta importación
import 'package:path/path.dart' as path; 

class SimulacionResultadosPage extends StatefulWidget {
  const SimulacionResultadosPage({Key? key}) : super(key: key);

  @override
  State<SimulacionResultadosPage> createState() => _SimulacionResultadosPageState();
}

class _SimulacionResultadosPageState extends State<SimulacionResultadosPage> {
  File? _selectedImage;
  File? _resultImage;
  String _selectedTreatment = 'lips';
  double _intensity = 0.5;
  final ImagePicker _picker = ImagePicker();

  final Map<String, String> _treatmentTypes = {
    'lips': 'Aumento de labios',
    'nose': 'Rinomodelación',
    'botox': 'Botox',
    'fillers': 'Rellenos faciales',
    'skincare': 'Tratamiento de piel',
    'lifting': 'Lifting facial'
  };

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxHeight: 1200, // Limitar altura para optimizar
        maxWidth: 1200,  // Limitar ancho para optimizar
      );
      
      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Verificar si es una imagen HEIC (formato común en iPhone)
        final extension = path.extension(pickedFile.path).toLowerCase();
        if (extension == '.heic' || extension == '.heif') {
          // Convertir HEIC a JPEG
          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          try {
            // Convertir y comprimir la imagen
            final result = await FlutterImageCompress.compressAndGetFile(
              imageFile.path,
              targetPath,
              quality: 90,
              format: CompressFormat.jpeg,
            );
            
            if (result != null) {
              imageFile = File(result.path);
              debugPrint('Imagen HEIC convertida exitosamente a JPEG');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No se pudo convertir la imagen. Intenta con otra.')),
              );
              return;
            }
          } catch (e) {
            debugPrint('Error al convertir imagen HEIC: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al procesar la imagen: $e')),
            );
            return;
          }
        }
        
        // Siempre optimizar la imagen para mejorar compatibilidad
        try {
          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          final result = await FlutterImageCompress.compressAndGetFile(
            imageFile.path,
            targetPath,
            quality: 85,
            format: CompressFormat.jpeg,
          );
          
          if (result != null) {
            imageFile = File(result.path);
            debugPrint('Imagen optimizada: ${await imageFile.length()} bytes');
          }
        } catch (e) {
          debugPrint('Error al optimizar imagen: $e');
          // Continuar con la imagen original si falla la optimización
        }

        setState(() {
          _selectedImage = imageFile;
          _resultImage = null;
        });

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen seleccionada correctamente')),
        );
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<File> _optimizeImageForApi(File imageFile) async {
    // Verificar el tamaño del archivo
    final fileSize = await imageFile.length();
    
    // Si la imagen es demasiado grande, comprimirla
    if (fileSize > 2 * 1024 * 1024) { // 2MB
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_optimized.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: 80,
        minWidth: 1080, // Ancho mínimo adecuado para reconocimiento facial
        minHeight: 1080, // Alto mínimo adecuado para reconocimiento facial
        format: CompressFormat.jpeg,
      );
      
      return result != null ? File(result.path) : imageFile;
    }
    
    return imageFile;
  }

  Future<void> _processTreatment() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una imagen primero')),
      );
      return;
    }

    // Mostrar un indicador de progreso
    final loadingDialog = _showLoadingDialog(context, 'Procesando imagen...');

    try {
      final youCamProvider = Provider.of<YouCamProvider>(context, listen: false);
      
      // Procesar la imagen con el tratamiento seleccionado
      final result = await youCamProvider.simulateTreatment(
        imageFile: _selectedImage!,
        treatmentType: _selectedTreatment,
        intensity: _intensity,
      );

      // Cerrar diálogo de carga
      Navigator.of(context, rootNavigator: true).pop();

      if (result != null) {
        setState(() {
          _resultImage = result;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo aplicar el tratamiento. Por favor intenta de nuevo.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de carga si hay error
      Navigator.of(context, rootNavigator: true).pop();
      
      debugPrint('Error en procesamiento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Método auxiliar para mostrar el diálogo de carga
  Dialog _showLoadingDialog(BuildContext context, String message) {
    final dialog = Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => dialog,
    );

    return dialog;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulación de Tratamientos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Consumer<YouCamProvider>(
        builder: (context, youCamProvider, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mensaje de error si existe
                  if (youCamProvider.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              youCamProvider.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => youCamProvider.clearError(),
                          ),
                        ],
                      ),
                    ),
                  
                  // Sección de selección de imagen
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paso 1: Selecciona una foto',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Cámara'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galería'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_selectedImage != null)
                            Center(
                              child: Container(
                                height: 200,
                                width: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sección de configuración de tratamiento
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paso 2: Configura el tratamiento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Tipo de tratamiento
                          const Text('Tipo de tratamiento:'),
                          DropdownButtonFormField<String>(
                            value: _selectedTreatment,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: _treatmentTypes.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedTreatment = value!;
                              });
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Intensidad del tratamiento
                          Text('Intensidad: ${(_intensity * 100).toInt()}%'),
                          Slider(
                            value: _intensity,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            label: '${(_intensity * 100).toInt()}%',
                            onChanged: (value) {
                              setState(() {
                                _intensity = value;
                              });
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Botón para procesar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _selectedImage != null && !youCamProvider.isProcessing
                                  ? _processTreatment
                                  : null,
                              child: youCamProvider.isProcessing
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Procesando...'),
                                      ],
                                    )
                                  : const Text('Simular Tratamiento'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sección de resultados
                  if (_resultImage != null)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resultado:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    const Text('Original'),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 150,
                                      width: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Text('Con tratamiento'),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 150,
                                      width: 150,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Image.file(
                                        _resultImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  // Implementar lógica para compartir el resultado
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Compartiendo resultado...')),
                                  );
                                },
                                icon: const Icon(Icons.share),
                                label: const Text('Compartir resultado'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}