import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/supabase.dart';
import 'models/clinicas.dart';
import 'package:url_launcher/url_launcher.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; // Añadida importación para dimensiones adaptativas

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
  late AppLocalizations localizations;

  @override
  void initState() {
    super.initState();
    _loadClinicas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
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
          _errorMessage = localizations.get('location_permission_required');
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
        throw Exception(localizations.get('could_not_get_location'));
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
            // Inicializar AdaptiveSize para el diálogo
            AdaptiveSize.initialize(context);
            final isSmallScreen = AdaptiveSize.screenWidth < 360;
            
            return AlertDialog(
              title: Text(
                localizations.get('location_services_disabled'),
                style: TextStyle(
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                localizations.get('location_services_needed'),
                style: TextStyle(
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                ),
              ),
              contentPadding: EdgeInsets.all(AdaptiveSize.w(16)),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    localizations.get('cancel'),
                    style: TextStyle(
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(
                    localizations.get('go_to_settings'),
                    style: TextStyle(
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
            SnackBar(
              content: Text(
                localizations.get('location_permission_required'),
                style: TextStyle(fontSize: AdaptiveSize.sp(14)),
              ),
              duration: const Duration(seconds: 3),
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
            // Inicializar AdaptiveSize para el diálogo
            AdaptiveSize.initialize(context);
            final isSmallScreen = AdaptiveSize.screenWidth < 360;
            
            return AlertDialog(
              title: Text(
                localizations.get('location_services_disabled'),
                style: TextStyle(
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                localizations.get('location_services_needed'),
                style: TextStyle(
                  fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                ),
              ),
              contentPadding: EdgeInsets.all(AdaptiveSize.w(16)),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    localizations.get('cancel'),
                    style: TextStyle(
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(
                    localizations.get('go_to_settings'),
                    style: TextStyle(
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize para dimensiones responsivas
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.get('our_clinics'),
          style: TextStyle(
            fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
          ),
        ),
        backgroundColor: const Color(0xFF1980E6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            iconSize: AdaptiveSize.getIconSize(context, baseSize: 24),
            onPressed: _loadClinicas,
            tooltip: localizations.get('refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: AdaptiveSize.w(30), 
                    height: AdaptiveSize.h(30),
                    child: CircularProgressIndicator(
                      strokeWidth: AdaptiveSize.w(2.5),
                    ),
                  ),
                  SizedBox(height: AdaptiveSize.h(16)),
                  Text(
                    localizations.get('searching_nearby_clinics'),
                    style: TextStyle(
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                    ),
                  ),
                ],
              ),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(AdaptiveSize.w(16)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                          ),
                        ),
                        SizedBox(height: AdaptiveSize.h(16)),
                        ElevatedButton(
                          onPressed: _loadClinicas,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: AdaptiveSize.w(16), 
                              vertical: AdaptiveSize.h(8),
                            ),
                          ),
                          child: Text(
                            localizations.get('retry'),
                            style: TextStyle(
                              fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _clinicas.isEmpty
                    ? Center(
                        child: Text(
                          localizations.get('no_clinics_found'),
                          style: TextStyle(
                            fontSize: AdaptiveSize.sp(isSmallScreen ? 16 : 18),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _clinicas.length,
                        itemBuilder: (context, index) {
                          final clinica = _clinicas[index];
                          return Card(
                            margin: EdgeInsets.symmetric(
                              horizontal: AdaptiveSize.w(16), 
                              vertical: AdaptiveSize.h(8),
                            ),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AdaptiveSize.w(8)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Imagen de la clínica
                                ClipRRect(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(AdaptiveSize.w(8)),
                                    topRight: Radius.circular(AdaptiveSize.w(8)),
                                  ),
                                  child: clinica.imagen != null
                                      ? Image.network(
                                          clinica.imagen!,
                                          width: double.infinity,
                                          height: AdaptiveSize.h(150),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            height: AdaptiveSize.h(150),
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.image_not_supported, 
                                              size: AdaptiveSize.getIconSize(context, baseSize: 50),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          height: AdaptiveSize.h(150),
                                          width: double.infinity,
                                          color: Colors.grey[300],
                                          child: Icon(
                                            Icons.local_hospital, 
                                            size: AdaptiveSize.getIconSize(context, baseSize: 50),
                                          ),
                                        ),
                                ),
                                
                                // Información de la clínica
                                Padding(
                                  padding: EdgeInsets.all(AdaptiveSize.w(16)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        clinica.nombre,
                                        style: TextStyle(
                                          fontSize: AdaptiveSize.sp(isSmallScreen ? 16 : 18),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: AdaptiveSize.h(8)),
                                      
                                      // Dirección
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on, 
                                            color: const Color(0xFF1980E6), 
                                            size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                          ),
                                          SizedBox(width: AdaptiveSize.w(4)),
                                          Expanded(
                                            child: Text(
                                              clinica.direccion,
                                              style: TextStyle(
                                                fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: AdaptiveSize.h(4)),
                                      
                                      // Teléfono
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone, 
                                            color: const Color(0xFF1980E6), 
                                            size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                          ),
                                          SizedBox(width: AdaptiveSize.w(4)),
                                          Text(
                                            clinica.telefono,
                                            style: TextStyle(
                                              fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      // Horario (si existe)
                                      if (clinica.horario != null) ...[
                                        SizedBox(height: AdaptiveSize.h(4)),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time, 
                                              color: const Color(0xFF1980E6), 
                                              size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                            ),
                                            SizedBox(width: AdaptiveSize.w(4)),
                                            Expanded(
                                              child: Text(
                                                clinica.horario!,
                                                style: TextStyle(
                                                  fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      
                                      // Rating (si existe)
                                      if (clinica.rating != null) ...[
                                        SizedBox(height: AdaptiveSize.h(4)),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.star, 
                                              color: Colors.amber, 
                                              size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                            ),
                                            SizedBox(width: AdaptiveSize.w(4)),
                                            Text(
                                              '${localizations.get('rating')}: ${clinica.rating!.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      
                                      SizedBox(height: AdaptiveSize.h(8)),
                                      
                                      // Distancia
                                      Text(
                                        '${localizations.get('distance')}: ${clinica.distancia!.toStringAsFixed(1)} km',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1980E6),
                                          fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Botón de navegación
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: AdaptiveSize.w(16), 
                                    bottom: AdaptiveSize.h(16)
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1'
                                              '&destination=${clinica.latitud},${clinica.longitud}'
                                              '&travelmode=driving');
                                          
                                          try {
                                            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    localizations.get('could_not_open_map'),
                                                    style: TextStyle(
                                                      fontSize: AdaptiveSize.sp(14),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${localizations.get('error')}: ${e.toString()}',
                                                  style: TextStyle(
                                                    fontSize: AdaptiveSize.sp(14),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.directions,
                                          size: AdaptiveSize.getIconSize(context, baseSize: 18),
                                        ),
                                        label: Text(
                                          localizations.get('get_directions'),
                                          style: TextStyle(
                                            fontSize: AdaptiveSize.sp(isSmallScreen ? 12 : 14),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1980E6),
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: AdaptiveSize.w(12), 
                                            vertical: AdaptiveSize.h(8),
                                          ),
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