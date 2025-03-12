import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'services/hugging_face.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/supabase.dart';

class TreatmentSimulationPage extends StatefulWidget {
  const TreatmentSimulationPage({super.key});

  @override
  State<TreatmentSimulationPage> createState() => _TreatmentSimulationPageState();
}

class _TreatmentSimulationPageState extends State<TreatmentSimulationPage> {
  final HuggingFaceService _huggingFaceService = HuggingFaceService();
  final SupabaseService _supabaseService = SupabaseService();
  File? _imageFile;
  String? _resultImageUrl;
  bool _isLoading = false;
  bool _hasResult = false;
  String _selectedTreatment = 'Aumento de Labios'; // Tratamiento seleccionado
  double _intensityLevel = 0.5; // Nivel de intensidad del tratamiento (0.0 a 1.0)
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
          _hasResult = false;
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
      // 1. Preparar prompt según el tratamiento seleccionado
      String prompt = _getPromptForTreatment();
      
      // 2. Mostrar mensaje de procesamiento
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Procesando imagen con IA, por favor espera...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // 3. Procesar imagen con Hugging Face
      final File processedImage = await _huggingFaceService.processImageWithRetry(
        inputImage: _imageFile!,
        prompt: prompt,
        strength: _intensityLevel,
      );
      
      // 4. Guardar simulación en Supabase
      final simulationId = await _supabaseService.saveSimulationResult(
        treatmentId: _selectedTreatmentId,
        beforeImage: _imageFile!,
        afterImage: processedImage,
      );
      
      // 5. Obtener URL de la imagen procesada
      final simulations = await _supabaseService.getUserSimulations();
      final thisSimulation = simulations.firstWhere((s) => s['id'] == simulationId);
      
      setState(() {
        _resultImageUrl = thisSimulation['after_image_url'];
        _hasResult = true;
        print('URL de resultado actualizada: $_resultImageUrl');
      });
      
    } catch (e) {
      print('Error: $e');
      
      // Manejo especial para errores de carga del modelo
      if (e.toString().contains('está cargando')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El modelo de IA está cargando, por favor intenta nuevamente en unos segundos'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el procesamiento: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Método para generar los prompts específicos según el tratamiento seleccionado
  String _getPromptForTreatment() {
    String intensityText = _intensityLevel < 0.3 ? 'muy sutil' 
                        : _intensityLevel < 0.6 ? 'sutil'
                        : _intensityLevel < 0.8 ? 'moderado'
                        : 'notable';
                      
    // Base del prompt para todos los tratamientos
    String basePrompt = 'Fotografía realista, CONSERVAR EXACTAMENTE LA MISMA IDENTIDAD, mismo peinado, mismo tono de piel, mismos ojos, misma iluminación,';
    
    // Prompt específico según tratamiento seleccionado
    switch (_selectedTreatment) {
      case 'Aumento de Labios':
        return '$basePrompt modificar ÚNICAMENTE los labios: ${intensityText}mente más voluminosos y definidos. Conservar EXACTAMENTE todos los demás rasgos faciales sin cambios. No cambiar color de piel, no cambiar peinado, no cambiar ojos.';
        
      case 'Rinomodelación':
        return '$basePrompt la misma persona con cambio $intensityText sólo en su nariz: más refinada, simétrica y proporcional. Mantener todas las demás características faciales idénticas. Resultado natural, profesional, realista.';
      
      case 'Masculinización Facial':
        return '$basePrompt la misma persona con cambios $intensityText de masculinización: mandíbula más angular y definida, mentón marcado, líneas faciales más fuertes. Mantener identidad reconocible. Resultado natural, profesional, realista.';
      
      case 'Lifting Facial':
        return '$basePrompt la misma persona con efecto $intensityText de lifting facial: piel más tersa, eliminación de flacidez, contorno facial más definido. Mantener todas las demás características faciales. Resultado natural, rejuvenecido, profesional, realista.';
      
      case 'Botox':
        return '$basePrompt la misma persona con efecto $intensityText de aplicación de botox: arrugas de expresión y líneas faciales reducidas, especialmente en frente y entrecejo, aspecto rejuvenecido. Mantener expresividad natural. Resultado profesional, realista.';
      
      case 'Eliminacion de Ojeras':
        return '$basePrompt la misma persona con eliminación $intensityText de ojeras y bolsas bajo los ojos, área infraorbital más tersa y luminosa, aspecto descansado. Mantener todas las demás características faciales. Resultado natural, profesional, realista.';
      
      default:
        return '$basePrompt la misma persona con mejora estética facial $intensityText general, aspecto más refinado pero manteniendo identidad y naturalidad. Resultado profesional, realista.';
    }
  }

  // Método para optimizar tamaño de imagen
  Future<File> _optimizeImageSize(File imageFile) async {
    try {
      // Implementación usando package:image
      // ...
      return imageFile; // Por ahora devolvemos la misma
    } catch (e) {
      print('Error optimizando imagen: $e');
      return imageFile;
    }
  } 

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

  // Método para mostrar la imagen de resultado correctamente (local o remota)
  Widget _buildResultImage() {
    if (_resultImageUrl == null) {
      return Container(
        height: 150, width: double.infinity,
        color: Colors.grey.shade200,
        child: const Center(child: Text('No hay resultado')),
      );
    }
    
    // Determinar si es una URL local o remota
    final bool isLocalFile = _resultImageUrl!.startsWith('file://');
    print('Tipo de URL: ${isLocalFile ? "Local" : "Remota"}: $_resultImageUrl');
    
    if (isLocalFile) {
      // Para archivos locales, eliminar el prefijo 'file://' y usar Image.file
      final String localPath = _resultImageUrl!.replaceFirst('file://', '');
      print('Mostrando imagen local desde: $localPath');
      
      // Verificar que el archivo existe antes de mostrarlo
      final file = File(localPath);
      if (!file.existsSync()) {
        print('¡ADVERTENCIA! El archivo no existe en la ruta: $localPath');
        
        // Intentar con ruta alternativa sin "file://"
        final alternativeFile = File(_resultImageUrl!);
        if (alternativeFile.existsSync()) {
          print('El archivo existe usando la URL completa');
          return Image.file(
            alternativeFile,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        }
        
        return Container(
          color: Colors.grey.shade200,
          height: 150,
          width: double.infinity,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(height: 8),
                Text('Archivo no encontrado', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      }
      
      print('El archivo existe y su tamaño es: ${file.lengthSync()} bytes');
      
      return Image.file(
        file,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error al cargar imagen local: $error');
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Error al cargar imagen', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Para URLs remotas, usar CachedNetworkImage
      return CachedNetworkImage(
        imageUrl: _resultImageUrl!,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          print('Error cargando imagen remota: $error');
          return Container(
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.error)),
          );
        },
      );
    }
  }

  @override
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
                              _hasResult = false;
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
                              _hasResult = false;
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

                        const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            'Para mejores resultados:\n'
                            '• Usa una foto con buena iluminación\n'
                            '• Mantén una posición frontal\n'
                            '• Expresión neutral\n'
                            '• Fondo claro',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
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
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                                // Animación más lenta para dar la sensación de procesamiento IA
                                value: null, 
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text('Procesando con IA...'),
                          ],
                        )
                      : const Text('Ver resultado'),
                ),
                
                const SizedBox(height: 24),
                
                // Resultado
                if (_hasResult && _resultImageUrl != null)
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
                                                child: _buildResultImage(),
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
                          
                          
                          const AlertDialog(
                            title: Text('Nota Importante'),
                            content: Text(
                              'Esta simulación utiliza IA generativa y ofrece una aproximación estética. '
                              'Los cambios reales variarán y siempre serán más sutiles y naturales. '
                              'Consulta con un especialista para conocer los resultados reales.',
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