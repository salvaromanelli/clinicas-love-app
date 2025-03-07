import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/supabase.dart';

class TreatmentSimulationPage extends StatefulWidget {
  const TreatmentSimulationPage({super.key});

  @override
  State<TreatmentSimulationPage> createState() => _TreatmentSimulationPageState();
}

class _TreatmentSimulationPageState extends State<TreatmentSimulationPage> {
  File? _imageFile;
  String? _resultImageUrl;
  bool _isLoading = false;
  String _selectedTreatment = 'Aumento de Labios'; // Tratamiento seleccionado
  double _intensityLevel = 0.5; // Nivel de intensidad del tratamiento (0.0 a 1.0)
    final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _treatments = [];
  String _selectedTreatmentId = '';
  
  @override
  void initState() {
    super.initState();
    _loadTreatments();
  }
  
  Future<void> _loadTreatments() async {
    try {
      final treatments = await _supabaseService.getTreatments();
      setState(() {
        _treatments = treatments;
        if (_treatments.isNotEmpty) {
          _selectedTreatmentId = _treatments.first['id'];
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar tratamientos: $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80, // Calidad de la imagen (0-100)
      maxWidth: 1200,   // Ancho máximo para reducir tamaño del archivo
      maxHeight: 1200,  // Alto máximo para reducir tamaño del archivo
    );
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _resultImageUrl = null; // Reset del resultado cuando se selecciona una nueva imagen
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al seleccionar imagen: $e')),
    );
  }
}
  
  final List<String> _treatmentOptions = [
    'Aumento de Labios',
    'Rinomodelación',
    'Masculinización Facial',
    'Lifting Facial',
    'Botox',
    'Eliminacion de Ojeras',
  ];

  Future<void> _processImage() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una imagen primero')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simular procesamiento de IA para generar la imagen "después"
      // En una implementación real, aquí conectarías con un servicio de IA
      await Future.delayed(const Duration(seconds: 2));
      
      // Por ahora, usaremos la misma imagen como "después" para simular
      final File afterImageFile = _imageFile!;
      
      // Guardar simulación en Supabase
      final simulationId = await _supabaseService.saveSimulationResult(
        treatmentId: _selectedTreatmentId,
        beforeImage: _imageFile!,
        afterImage: afterImageFile,
      );
      
      // Obtener URL de la imagen procesada
      final simulations = await _supabaseService.getUserSimulations();
      final thisSimulation = simulations.firstWhere((s) => s['id'] == simulationId);
      
      setState(() {
        _resultImageUrl = thisSimulation['after_image_url'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en el procesamiento: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  
  String _getSimulatedResultUrl() {
    // En una implementación real, esto vendría de tu API de IA
    // Aquí simplemente devolvemos URLs según el tratamiento seleccionado
    switch (_selectedTreatment) {
      case 'Aumento de Labios':
        return 'https://example.com/simulated_lip_augmentation.jpg';
      case 'Rinomodelación':
        return 'https://example.com/simulated_rhinomodeling.jpg';
      case 'Masculinización Facial':
        return 'https://example.com/simulated_masculinization.jpg';
      case 'Lifting Facial':
        return 'https://example.com/simulated_facelift.jpg';
      case 'Botox':
        return 'https://example.com/simulated_botox.jpg';
      case 'Eliminacion de Ojeras':
        return 'https://example.com/simulated_dark_circles_removal.jpg';
      default:
        return 'https://example.com/simulated_default.jpg';
    }
  }

  @override
  
  Widget _buildImageButton({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
  bool isFullWidth = false,
}) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18), // Tamaño de icono más pequeño
    label: Text(
      label,
      style: const TextStyle(fontSize: 13), // Texto más pequeño
    ),
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF1980E6),
      padding: const EdgeInsets.symmetric(
        horizontal: 12, 
        vertical: 8,
      ),
      minimumSize: isFullWidth ? const Size(double.infinity, 40) : null,
    ),
  );
}
  
  
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Tratamientos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Introducción al simulador
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_fix_high,
                          size: 48,
                          color: Color(0xFF1980E6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Simulador de Tratamientos con IA',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sube una foto tuya y visualiza cómo quedarías después del tratamiento deseado.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Selector de tratamiento
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Selecciona el tratamiento',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          value: _selectedTreatment,
                          items: _treatmentOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedTreatment = newValue!;
                              _resultImageUrl = null; // Limpiar resultado al cambiar tratamiento
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Intensidad del tratamiento',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Slider(
                          value: _intensityLevel,
                          onChanged: (newValue) {
                            setState(() {
                              _intensityLevel = newValue;
                              _resultImageUrl = null; // Limpiar resultado al cambiar intensidad
                            });
                          },
                          divisions: 10,
                          label: '${(_intensityLevel * 100).round()}%',
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Subida de imagen
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2. Sube tu foto',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Determinar si hay suficiente espacio para botones horizontales
                            final isNarrow = constraints.maxWidth < 340;
                            
                            // Si el espacio es reducido, usar columna; de lo contrario, usar fila
                            return isNarrow
                              ? Column(
                                  children: [
                                    _buildImageButton(
                                      icon: Icons.camera_alt,
                                      label: 'Tomar foto',
                                      onPressed: () => _pickImage(ImageSource.camera),
                                      isFullWidth: true,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildImageButton(
                                      icon: Icons.photo_library,
                                      label: 'Galería',
                                      onPressed: () => _pickImage(ImageSource.gallery),
                                      isFullWidth: true,
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildImageButton(
                                      icon: Icons.camera_alt,
                                      label: 'Tomar foto',
                                      onPressed: () => _pickImage(ImageSource.camera),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildImageButton(
                                      icon: Icons.photo_library,
                                      label: 'Galería',
                                      onPressed: () => _pickImage(ImageSource.gallery),
                                    ),
                                  ],
                                );
                          },
                        ),
                        
                        if (_imageFile != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _imageFile!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Botón de procesamiento
                ElevatedButton(
                  onPressed: _isLoading ? null : _processImage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF1980E6),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Procesando imagen...'),
                          ],
                        )
                      : const Text('Ver resultado'),
                ),
                
                const SizedBox(height: 24),
                
                // Resultado
                if (_resultImageUrl != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Resultado simulado',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          
                          // Comparación antes/después
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                // Título de la comparación
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(11),
                                    ),
                                  ),
                                  child: Text(
                                    'Simulación de $_selectedTreatment',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                
                                // Imágenes de comparación
                                IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Antes
                                      Expanded(
                                        child: Column(
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text(
                                                'Antes',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.file(
                                                  _imageFile!,
                                                  height: 150,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Divisor vertical
                                      Container(
                                        width: 1,
                                        color: Colors.grey.shade300,
                                      ),
                                      
                                      // Después
                                      Expanded(
                                        child: Column(
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Text(
                                                'Después',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: CachedNetworkImage(
                                                  imageUrl: _resultImageUrl!,
                                                  height: 150,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                  ),
                                                  errorWidget: (context, url, error) => Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Center(
                                                      child: Icon(Icons.error),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          const Text(
                            'NOTA: Este es un resultado simulado generado por IA. El resultado real puede variar. Consulta con nuestros especialistas para más información.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          ElevatedButton.icon(
                            onPressed: () {
                              // Aquí se implementaría la lógica para agendar consulta
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('¡Reserva de consulta iniciada!')),
                              );
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: const Text('Agendar consulta de evaluación'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.green,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          OutlinedButton.icon(
                            onPressed: () {
                              // Compartir resultado (implementar con un paquete de compartir)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Compartir resultado')),
                              );
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Compartir resultado'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}