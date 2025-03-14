import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/services/ml_kit_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class TreatmentSimulationScreen extends StatefulWidget {
  @override
  _TreatmentSimulationScreenState createState() => _TreatmentSimulationScreenState();
}

class _TreatmentSimulationScreenState extends State<TreatmentSimulationScreen> with SingleTickerProviderStateMixin {
  File? _imageFile;
  File? _processedImageFile;
  String _selectedTreatment = 'aumento de labios';
  double _intensity = 0.5;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _showBeforeAfter = false;
  late TabController _tabController;
  bool _showInfoPanel = false;
  
  // Textos descriptivos para cada tratamiento
  Map<String, String> _treatmentDescriptions = {
    'aumento de labios': 'Simula el resultado de un aumento de labios que proporciona mayor volumen y definición utilizando ácido hialurónico.',
    'rinomodelación': 'Visualiza el posible resultado de un procedimiento no quirúrgico para redefinir la forma de la nariz.',
    'rejuvenecimiento': 'Previsualiza el efecto de tratamientos para reducir arrugas y mejorar la textura de la piel.',
    'botox': 'Observa el posible resultado del botox para suavizar líneas de expresión en frente, entrecejo y patas de gallo.',
  };

  final List<String> _availableTreatments = [
    'aumento de labios',
    'rinomodelación',
    'rejuvenecimiento',
    'botox'
  ];

  // Posición para el comparador visual
  double _comparePosition = 0.5;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDemoImage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Carga una imagen de demostración
  Future<void> _loadDemoImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/demo_face.jpg');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/demo_face.jpg');
      await file.writeAsBytes(data.buffer.asUint8List());
      
      setState(() {
        _imageFile = file;
      });
    } catch (e) {
      print('Error cargando imagen demo: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Simulador de Tratamientos'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              setState(() {
                _showInfoPanel = !_showInfoPanel;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.photo_camera), text: 'Simular'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSimulationTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: _imageFile != null && !_isProcessing ? FloatingActionButton(
        onPressed: () => _processImage(),
        child: Icon(Icons.auto_awesome),
        tooltip: 'Simular Tratamiento',
      ) : null,
    );
  }
  
  Widget _buildSimulationTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showInfoPanel) _buildInfoPanel(),
          
          // Selector de imagen mejorado
          _buildImageSelector(),
          
          if (_imageFile != null) ...[
            // Panel de controles
            _buildControlPanel(),
            
            SizedBox(height: 20),
            
            // Resultado del procesamiento con modo comparativo
            if (_processedImageFile != null) _buildResultView(),
            
            // Indicador de progreso
            if (_isProcessing) 
              Container(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 15),
                    Text('Procesando imagen...\nEsto puede tardar unos segundos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            
            // Mensaje de error
            if (_errorMessage != null)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 36),
                    SizedBox(height: 8),
                    Text(_errorMessage!,
                      style: TextStyle(color: Colors.red[900]),
                      textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('¿Cómo funciona?', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showInfoPanel = false;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('1. Selecciona o toma una foto frontal de tu rostro'),
          Text('2. Elige el tratamiento que deseas simular'),
          Text('3. Ajusta la intensidad del efecto'),
          Text('4. Presiona el botón para generar la simulación'),
          SizedBox(height: 8),
          Text('Nota: Los resultados son aproximados y pueden variar de los resultados reales del tratamiento.',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildImageSelector() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Foto para Simulación', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            
            if (_imageFile == null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 64, color: Colors.grey[600]),
                      SizedBox(height: 10),
                      Text('Selecciona una fotografía',
                        style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _imageFile!,
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _imageFile = null;
                            _processedImageFile = null;
                            _errorMessage = null;
                          });
                        },
                        tooltip: 'Cambiar imagen',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.camera_alt),
                    label: Text('Cámara'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _getImage(ImageSource.camera),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.photo_library),
                    label: Text('Galería'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _getImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opciones de Tratamiento', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            
            SizedBox(height: 16),
            
            // Selector de tratamiento con íconos
            _buildTreatmentButtons(),
            
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            
            // Descripción del tratamiento
            Text(_treatmentDescriptions[_selectedTreatment] ?? '',
                style: TextStyle(fontStyle: FontStyle.italic)),
            
            SizedBox(height: 20),
            
            // Control de intensidad
            Text('Intensidad del efecto', 
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            
            Row(
              children: [
                Icon(Icons.opacity_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _intensity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    label: _intensity.toStringAsFixed(1),
                    onChanged: (value) {
                      setState(() {
                        _intensity = value;
                        _processedImageFile = null;
                      });
                    },
                  ),
                ),
                Icon(Icons.opacity, size: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentButtons() {
    return Container(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTreatmentButton('aumento de labios', Icons.face, Colors.pink[100]!),
          _buildTreatmentButton('rinomodelación', Icons.face_retouching_natural, Colors.blue[100]!),
          _buildTreatmentButton('rejuvenecimiento', Icons.face_retouching_natural, Colors.green[100]!),
          _buildTreatmentButton('botox', Icons.healing, Colors.purple[100]!),
        ],
      ),
    );
  }

  Widget _buildTreatmentButton(String treatment, IconData icon, Color bgColor) {
    final isSelected = _selectedTreatment == treatment;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTreatment = treatment;
          _processedImageFile = null;
        });
      },
      child: Container(
        width: 100,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 32,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
            ),
            SizedBox(height: 8),
            Text(
              treatment.split(' ').map((word) => word[0].toUpperCase() + word.substring(1)).join('\n'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultView() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Resultado de la Simulación', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Switch(
                  value: _showBeforeAfter,
                  onChanged: (value) {
                    setState(() {
                      _showBeforeAfter = value;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_showBeforeAfter ? 'Antes/Después' : 'Resultado'),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Vista antes/después o resultado
            _showBeforeAfter ? _buildBeforeAfterView() : _buildSimpleResultView(),
            
            SizedBox(height: 16),
            
            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.share),
                    label: Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _shareResult,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save_alt),
                    label: Text('Guardar'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _saveResult,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Botones adicionales
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: Icon(Icons.calendar_today),
                  label: Text('Agendar Cita'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/book-appointment');
                  },
                ),
                OutlinedButton.icon(
                  icon: Icon(Icons.info_outline),
                  label: Text('Más Info'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    _showTreatmentInfo(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeAfterView() {
    return Container(
      height: 350,
      child: Stack(
        children: [
          // Original Image (Before)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Processed Image with slider (After)
          Positioned.fill(
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: _comparePosition,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _processedImageFile!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          
          // Slider handle
          Positioned(
            top: 0,
            bottom: 0,
            left: MediaQuery.of(context).size.width * _comparePosition * 0.7, // Ajuste para el padding
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _comparePosition = (_comparePosition + details.delta.dx / 250).clamp(0.0, 1.0);
                });
              },
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  border: Border.symmetric(
                    vertical: BorderSide(width: 4, color: Theme.of(context).primaryColor),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_back, color: Theme.of(context).primaryColor),
                    SizedBox(height: 8),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text('ANTES',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                      ),
                    ),
                    SizedBox(height: 20),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text('DESPUÉS',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                      ),
                    ),
                    SizedBox(height: 8),
                    Icon(Icons.arrow_forward, color: Theme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleResultView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        _processedImageFile!,
        height: 350,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
  
  Widget _buildHistoryTab() {
    // Aquí implementaríamos el historial de simulaciones
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Tu historial de simulaciones aparecerá aquí',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _showTreatmentInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_selectedTreatment.toUpperCase()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_treatmentDescriptions[_selectedTreatment] ?? ''),
            SizedBox(height: 16),
            Text('Detalles del procedimiento:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Duración aproximada: 30-45 minutos'),
            Text('• Recuperación: Mínima'),
            Text('• Resultados visibles: Inmediatos'),
            Text('• Duración del efecto: 6-12 meses'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cerrar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text('Agendar Consulta'),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/book-appointment');
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedImage = await ImagePicker().pickImage(source: source);
      
      if (pickedImage != null) {
        setState(() {
          _imageFile = File(pickedImage.path);
          _processedImageFile = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al seleccionar la imagen: $e';
      });
      print('Error al seleccionar imagen: $e');
    }
  }
  
  Future<void> _processImage() async {
    if (_imageFile == null) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    try {
      // Validar que la imagen existe y tiene contenido
      if (!await _imageFile!.exists()) {
        throw Exception('El archivo de imagen no existe');
      }
      
      final fileSize = await _imageFile!.length();
      if (fileSize == 0) {
        throw Exception('El archivo de imagen está vacío');
      }
      
      print('Procesando imagen: ${_imageFile!.path}');
      print('Tamaño del archivo: ${fileSize} bytes');
      
      final mlKitService = Provider.of<MLKitService>(context, listen: false);
      
      // Agregar depuración adicional
      final debugImage = await mlKitService.debugFaceDetection(_imageFile!);
      
      // Guardar imagen de depuración (opcional)
      final debugResult = await ImageGallerySaver.saveFile(debugImage.path);
      print('Imagen de depuración guardada: $debugResult');
      
      // Continuar con la simulación
      final processedFile = await mlKitService.simulateTreatment(
        imageFile: _imageFile!,
        treatmentType: _selectedTreatment,
        intensity: _intensity,
      );
      
      setState(() {
        _processedImageFile = processedFile;
        _isProcessing = false;
        _showBeforeAfter = true;  // Mostrar comparación automáticamente
      });
    } catch (e) {
      print('Error detallado en la simulación: $e');
      
      setState(() {
        _errorMessage = 'Error en la simulación: $e';
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _shareResult() async {
    if (_processedImageFile == null) return;
    
    try {
      await Share.shareXFiles([XFile(_processedImageFile!.path)],
        subject: 'Mi simulación de ${ _selectedTreatment}',
        text: 'Mira el resultado de mi simulación de $_selectedTreatment en Clínica Virtual');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }
    
  Future<void> _saveResult() async {
    if (_processedImageFile == null) return;
    
    try {
      final Uint8List bytes = await _processedImageFile!.readAsBytes();
      
      // Añadir información de depuración
      print('Guardando imagen con tamaño: ${bytes.length} bytes');
      
      final result = await ImageGallerySaver.saveImage(
        bytes,
        quality: 95,
        name: "simulacion_${_selectedTreatment.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}"
      );
      
      print('Resultado del guardado: $result');
      
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imagen guardada en la galería'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar la imagen: ${result['errorMessage'] ?? 'Error desconocido'}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error detallado al guardar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}