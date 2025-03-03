import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/clinicas.dart';
import 'services/supabase.dart';

class ClinicasPage extends StatefulWidget {
  const ClinicasPage({super.key});

  @override
  State<ClinicasPage> createState() => _ClinicasPageState();
}

class _ClinicasPageState extends State<ClinicasPage> with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isLoading = true;
  Position? _currentPosition;
  late TabController _tabController;
  Set<Marker> _markers = {};
  Clinic? _nearestClinic;
  bool _locationPermissionDenied = false;
  final SupabaseService _supabaseService = SupabaseService();
  List<Clinic> clinics = [];
  bool _isLoadingClinics = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClinics();
    _getCurrentLocation();
  }
  
  Future<void> _loadClinics() async {
    setState(() {
      _isLoadingClinics = true;
    });
    
    try {
      final clinicsData = await _supabaseService.getClinics();
      setState(() {
        clinics = clinicsData;
        _isLoadingClinics = false;
      });
      
      // Si ya tenemos la posición del usuario, calculamos distancias
      if (_currentPosition != null) {
        _calculateDistances();
      }
    } catch (e) {
      print('Error cargando clínicas: $e');
      setState(() {
        _isLoadingClinics = false;
      });
    }
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar y solicitar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _locationPermissionDenied = true;
        });
        return;
      }

      // Obtener posición actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
      });
      
      // Calcular distancias y encontrar la clínica más cercana
      _calculateDistances();
      
      // Añadir marcadores al mapa
      _addMarkers();
      
      // Centrar el mapa en la ubicación actual
      _centerMap();
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener tu ubicación: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateDistances() {
    if (_currentPosition == null) return;

    for (var clinic in clinics) {
      double distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        clinic.latitude,
        clinic.longitude,
      );
      
      // Convertir a kilómetros
      clinic.distance = distanceInMeters / 1000;
    }

    // Ordenar por distancia
    clinics.sort((a, b) => (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity));
    
    // Establecer la clínica más cercana
    if (clinics.isNotEmpty) {
      setState(() {
        _nearestClinic = clinics.first;
      });
    }
  }

  void _addMarkers() {
    Set<Marker> markers = {};
    
    // Añadir marcador de ubicación actual
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Añadir marcadores para cada clínica
    for (var clinic in clinics) {
      markers.add(
        Marker(
          markerId: MarkerId(clinic.id),
          position: LatLng(clinic.latitude, clinic.longitude),
          infoWindow: InfoWindow(
            title: clinic.name,
            snippet: clinic.distance != null 
                ? 'A ${clinic.distance!.toStringAsFixed(2)} km de ti' 
                : clinic.address,
          ),
          onTap: () {
            setState(() {
              _nearestClinic = clinic;
              _tabController.animateTo(1); // Cambiar a la pestaña de información
            });
          },
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _centerMap() async {
    if (_currentPosition == null || !_mapController.isCompleted) return;

    final GoogleMapController controller = await _mapController.future;
    
    // Si tenemos la clínica más cercana, centramos el mapa para mostrar ambos puntos
    if (_nearestClinic != null) {
      // Calculamos los límites del mapa
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude < _nearestClinic!.latitude 
              ? _currentPosition!.latitude 
              : _nearestClinic!.latitude,
          _currentPosition!.longitude < _nearestClinic!.longitude 
              ? _currentPosition!.longitude 
              : _nearestClinic!.longitude,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > _nearestClinic!.latitude 
              ? _currentPosition!.latitude 
              : _nearestClinic!.latitude,
          _currentPosition!.longitude > _nearestClinic!.longitude 
              ? _currentPosition!.longitude 
              : _nearestClinic!.longitude,
        ),
      );
      
      // Añadimos un padding para que los marcadores no queden pegados al borde
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    } else {
      // Si no hay clínica más cercana, centramos en la posición actual
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 14,
        ),
      ));
    }
  }

  void _launchMaps(double lat, double lng, String name) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  void _launchCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo realizar la llamada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuestras Clínicas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'MAPA', icon: Icon(Icons.map)),
            Tab(text: 'INFORMACIÓN', icon: Icon(Icons.info_outline)),
          ],
          labelColor: Colors.white,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _locationPermissionDenied
          ? _buildLocationPermissionDenied()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMapTab(),
                _buildInfoTab(),
              ],
            ),
    );
  }

  Widget _buildLocationPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'Necesitamos acceso a tu ubicación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Para mostrarte la clínica más cercana, necesitamos acceso a tu ubicación. Por favor, activa los permisos de ubicación en la configuración de tu dispositivo.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await openAppSettings();
              },
              child: const Text('Abrir configuración'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _locationPermissionDenied = false;
                });
              },
              child: const Text('Continuar sin ubicación'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(-16.489689, -68.119293), // La Paz, Bolivia (o tu ubicación por defecto)
            zoom: 13,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            _mapController.complete(controller);
            _centerMap();
          },
        ),
        if (_nearestClinic != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Clínica más cercana',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _nearestClinic!.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_nearestClinic!.distance != null)
                      Text(
                        'A ${_nearestClinic!.distance!.toStringAsFixed(2)} km de tu ubicación',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _tabController.animateTo(1),
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Detalles'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _launchMaps(
                            _nearestClinic!.latitude, 
                            _nearestClinic!.longitude,
                            _nearestClinic!.name,
                          ),
                          icon: const Icon(Icons.directions),
                          label: const Text('Cómo llegar'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sección de clínica más cercana
        if (_nearestClinic != null) ...[
          _buildClinicCard(
            _nearestClinic!,
            isNearest: true,
          ),
          const SizedBox(height: 24),
          const Text(
            'Todas nuestras clínicas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Lista de todas las clínicas
        ...clinics.map((clinic) {
          // Si es la clínica más cercana y ya la mostramos arriba, no la mostramos de nuevo
          if (_nearestClinic != null && clinic.id == _nearestClinic!.id) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              _buildClinicCard(clinic),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildClinicCard(Clinic clinic, {bool isNearest = false}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNearest 
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2) 
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen de la clínica
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              clinic.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          
          // Etiqueta de "Más cercana" si corresponde
          if (isNearest)
            Container(
              color: Theme.of(context).colorScheme.primary,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'CLÍNICA MÁS CERCANA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
          // Información de la clínica
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clinic.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Calificación
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < clinic.rating.floor() 
                            ? Icons.star 
                            : index < clinic.rating 
                                ? Icons.star_half
                                : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      clinic.rating.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Dirección
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clinic.address,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Distancia
                if (clinic.distance != null)
                  Row(
                    children: [
                      const Icon(Icons.directions_walk, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'A ${clinic.distance!.toStringAsFixed(2)} km de tu ubicación',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                
                // Horario
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clinic.schedule,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Servicios
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.medical_services_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: clinic.services.map((service) {
                          return Chip(
                            label: Text(
                              service,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.grey[200],
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchCall(clinic.phoneNumber),
                        icon: const Icon(Icons.call),
                        label: const Text('Llamar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _launchMaps(
                          clinic.latitude,
                          clinic.longitude,
                          clinic.name,
                        ),
                        icon: const Icon(Icons.directions),
                        label: const Text('Cómo llegar'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}