import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/supabase.dart';
import 'models/clinicas.dart';
import 'package:url_launcher/url_launcher.dart';

class ClinicasPage extends StatefulWidget {
  const ClinicasPage({super.key});

  @override
  State<ClinicasPage> createState() => _ClinicasPageState();
}

class _ClinicasPageState extends State<ClinicasPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Clinica> _clinicas = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadClinicas();
  }

  Future<void> _loadClinicas() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Verificar y solicitar permisos de ubicación
      final permission = await _checkLocationPermission();
      if (!permission) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Se requieren permisos de ubicación para mostrar las clínicas cercanas';
          _isLoading = false;
        });
        return;
      }

      // Obtener la ubicación actual con un timeout
      print("Obteniendo ubicación actual...");
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).catchError((error) {
        print("Error obteniendo ubicación: $error");
        throw Exception('No se pudo obtener la ubicación actual');
      });
      
      print("Posición actual obtenida: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}");

      // Obtener las clínicas desde Supabase
      final clinicas = await SupabaseService().getClinicas();
      print("Clínicas obtenidas desde Supabase: ${clinicas.length}");

      if (clinicas.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Calcular distancia para cada clínica
      print("Calculando distancias para ${clinicas.length} clínicas...");
      for (var clinica in clinicas) {
        print("Datos de clínica: ${clinica.nombre} (${clinica.latitud}, ${clinica.longitud})");
        
        try {
          // Utilizamos la fórmula de Haversine para calcular la distancia
          double distanciaEnKm = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            clinica.latitud,
            clinica.longitud,
          ) / 1000; // Convertir metros a kilómetros
          
          clinica.distancia = distanciaEnKm;
          print("Distancia calculada para ${clinica.nombre}: ${distanciaEnKm.toStringAsFixed(2)} km");
        } catch (e) {
          print("Error calculando distancia para ${clinica.nombre}: $e");
          clinica.distancia = 9999.0; // Valor alto para que aparezca al final
        }
      }

      // Ordenar por distancia (más cercanas primero)
      print("Ordenando clínicas por distancia...");
      clinicas.sort((a, b) {
        final distA = a.distancia ?? 9999.0;
        final distB = b.distancia ?? 9999.0;
        return distA.compareTo(distB);
      });

      print("Clínicas ordenadas por distancia:");
      for (var clinica in clinicas) {
        print("${clinica.nombre}: ${clinica.distancia?.toStringAsFixed(2)} km");
      }

      setState(() {
        _clinicas = clinicas;
        _isLoading = false;
      });
    } catch (e) {
      print("Error general en _loadClinicas: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error al cargar clínicas: ${e.toString()}';
      });
    }
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Los servicios de ubicación no están habilitados
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Servicios de ubicación desactivados'),
              content: const Text(
                'Esta aplicación necesita acceso a los servicios de ubicación para mostrar las clínicas más cercanas. '
                'Por favor, active los servicios de ubicación en la configuración de su dispositivo.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Ir a Configuración'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Geolocator.openLocationSettings();
                  },
                ),
              ],
            );
          },
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Solicita permiso explícitamente
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // El usuario denegó el permiso
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se requieren permisos de ubicación para mostrar las clínicas cercanas'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // El usuario ha denegado permanentemente el permiso
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Permisos de ubicación denegados'),
              content: const Text(
                'Ha denegado permanentemente el permiso de ubicación. '
                'Para usar esta función, debe habilitar el permiso en la configuración de la aplicación.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Abrir Configuración'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await openAppSettings();
                  },
                ),
              ],
            );
          },
        );
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuestras Clínicas'),
        backgroundColor: const Color(0xFF1980E6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClinicas,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buscando clínicas cercanas...'),
                ],
              ),
            )
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadClinicas,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _clinicas.isEmpty
                  ? const Center(child: Text('No se encontraron clínicas disponibles'))
                  : ListView.builder(
                      itemCount: _clinicas.length,
                      itemBuilder: (context, index) {
                        final clinica = _clinicas[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              clinica.imagen != null
                                  ? Image.network(
                                      clinica.imagen!,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        height: 150,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.image_not_supported, size: 50),
                                      ),
                                    )
                                  : Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.local_hospital, size: 50),
                                    ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clinica.nombre,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, color: Color(0xFF1980E6), size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(clinica.direccion)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, color: Color(0xFF1980E6), size: 16),
                                        const SizedBox(width: 4),
                                        Text(clinica.telefono),
                                      ],
                                    ),
                                    if (clinica.horario != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, color: Color(0xFF1980E6), size: 16),
                                          const SizedBox(width: 4),
                                          Text(clinica.horario!),
                                        ],
                                      ),
                                    ],
                                    if (clinica.rating != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Valoración: ${clinica.rating!.toStringAsFixed(1)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      'Distancia: ${clinica.distancia!.toStringAsFixed(1)} km',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1980E6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16.0, bottom: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        // Actualizado para usar launchUrl en lugar de launch (deprecado)
                                        final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1'
                                            '&destination=${clinica.latitud},${clinica.longitud}'
                                            '&travelmode=driving');
                                        
                                        try {
                                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('No se pudo abrir el mapa')),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: ${e.toString()}')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.directions),
                                      label: const Text('Cómo llegar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1980E6),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}