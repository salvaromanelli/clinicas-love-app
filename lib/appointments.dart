import 'package:flutter/material.dart';
import 'services/supabase.dart';
import 'booking_page.dart';
import 'widgets/appointment_card.dart';
import 'i18n/app_localizations.dart'; 
import 'boton_asistente.dart';
import 'utils/adaptive_sizing.dart';

class RecomendacionesPage extends StatefulWidget {
  const RecomendacionesPage({super.key});

  @override
  State<RecomendacionesPage> createState() => _RecomendacionesPageState();
}

class _RecomendacionesPageState extends State<RecomendacionesPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'upcoming', 'past'
  late AppLocalizations localizations;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context);
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Iniciando carga de citas...');
      final appointments = await _supabaseService.getUserAppointments();
      print('Citas obtenidas: ${appointments.length}');
      
      if (appointments.isNotEmpty) {
        print('Primera cita: ${appointments[0]}');
      }
      
      setState(() {
        _appointments = appointments;
        _updateFilteredAppointments(); // Actualiza la caché filtrada
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando citas: $e');
      setState(() {
        _isLoading = false;
        // Añadir un mensaje de error visible al usuario
        _appointments = [];
        _updateFilteredAppointments();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar citas: ${e.toString()}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }
    
  // Método para actualizar _filteredAppointments
  void _updateFilteredAppointments() {
    if (_filterStatus == 'all') {
      _filteredAppointments = List.from(_appointments);
      return;
    }
    
    final now = DateTime.now();
    _filteredAppointments = _appointments.where((appointment) {
      try {
        final appointmentDate = DateTime.parse(appointment['appointment_date']);
        final status = appointment['status']?.toString() ?? '';
        final isCancelled = status == 'Cancelada';
        final isRescheduled = status == 'Reprogramada';
        
        if (_filterStatus == 'upcoming') {
          return appointmentDate.isAfter(now) && !isCancelled && !isRescheduled;
        } else { // past
          return appointmentDate.isBefore(now) || isCancelled || isRescheduled;
        }
      } catch (e) {
        print('Error procesando cita: $e');
        return false; // Excluir esta cita si hay error
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418), // Fondo oscuro para coincidir con el resto de la app
      appBar: AppBar(
        title: Text(
          localizations.get('my_appointments'),
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18.sp : 20.sp, // Incrementado tamaño
          ),
        ),
        backgroundColor: const Color(0xFF1C2126), // Misma barra que otras pantallas
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: AdaptiveSize.getIconSize(context, baseSize: 24),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter chips con estilo adaptado
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8.w : 16.w, 
                  vertical: 12.h,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1C2126),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF0D0F13),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: FilterChip(
                          label: Text(
                            localizations.get('all'), 
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.sp : 15.sp,
                              color: _filterStatus == 'all' ? Colors.white : Colors.white.withOpacity(0.85),
                              fontWeight: _filterStatus == 'all' ? FontWeight.w600 : FontWeight.normal,
                              shadows: _filterStatus == 'all' ? [
                                Shadow(color: Colors.black38, blurRadius: 0.5, offset: Offset(0, 0.5)),
                              ] : null,
                            ),
                          ),
                          selected: _filterStatus == 'all',
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = 'all';
                              _updateFilteredAppointments();
                            });
                          },
                          backgroundColor: const Color(0xFF262A33),
                          selectedColor: const Color(0xFF1980E6).withOpacity(0.9), // Más contrastante
                          checkmarkColor: Colors.white, // Checkmark más visible
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4.w : 6.w, 
                            vertical: isSmallScreen ? 6.h : 8.h, // Más espacio vertical para tocar
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.w),
                            side: _filterStatus == 'all'
                                ? BorderSide(color: const Color(0xFF1980E6), width: 1.5.w) // Borde más grueso
                                : BorderSide.none,
                          ),
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: FilterChip(
                          label: Text(
                            localizations.get('upcoming'), 
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.sp : 15.sp, // Mismo tamaño que "all"
                              color: _filterStatus == 'upcoming' ? Colors.white : Colors.white.withOpacity(0.85), // Mejor contraste
                              fontWeight: _filterStatus == 'upcoming' ? FontWeight.w600 : FontWeight.normal, // Enfatizar selección
                              shadows: _filterStatus == 'upcoming' ? [
                                Shadow(color: Colors.black38, blurRadius: 0.5, offset: Offset(0, 0.5)),
                              ] : null,
                            ),
                          ),
                          selected: _filterStatus == 'upcoming',
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = 'upcoming';
                              _updateFilteredAppointments();
                            });
                          },
                          backgroundColor: const Color(0xFF262A33),
                          selectedColor: const Color(0xFF1980E6).withOpacity(0.9), // Más contrastante
                          checkmarkColor: Colors.white, // Checkmark más visible
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4.w : 6.w,
                            vertical: isSmallScreen ? 6.h : 8.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.w),
                            side: _filterStatus == 'upcoming'
                                ? BorderSide(color: const Color(0xFF1980E6), width: 1.5.w) // Borde más grueso
                                : BorderSide.none,
                          ),
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2.w),
                        child: FilterChip(
                          label: Text(
                            localizations.get('past'), 
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.sp : 15.sp, // Mismo tamaño que los otros
                              color: _filterStatus == 'past' ? Colors.white : Colors.white.withOpacity(0.85), // Mejor contraste
                              fontWeight: _filterStatus == 'past' ? FontWeight.w600 : FontWeight.normal, // Enfatizar selección
                              shadows: _filterStatus == 'past' ? [
                                Shadow(color: Colors.black38, blurRadius: 0.5, offset: Offset(0, 0.5)),
                              ] : null,
                            ),
                          ),
                          selected: _filterStatus == 'past',
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = 'past';
                              _updateFilteredAppointments();
                            });
                          },
                          backgroundColor: const Color(0xFF262A33),
                          selectedColor: const Color(0xFF1980E6).withOpacity(0.9), // Más contrastante
                          checkmarkColor: Colors.white, // Checkmark más visible
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 4.w : 6.w,
                            vertical: isSmallScreen ? 6.h : 8.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.w),
                            side: _filterStatus == 'past'
                                ? BorderSide(color: const Color(0xFF1980E6), width: 1.5.w) // Borde más grueso
                                : BorderSide.none,
                          ),
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Appointments list
              Expanded(
                child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1980E6)),
                    )
                  : _filteredAppointments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: AdaptiveSize.getIconSize(context, baseSize: 64),
                              color: Colors.white30,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              localizations.get('no_appointments'),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16.sp : 18.sp, 
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AppointmentBookingPage(),
                                  ),
                                ).then((value) {
                                  if (value == true) {
                                    _loadAppointments();
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1980E6),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, 
                                  vertical: 12.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.w),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                localizations.get('schedule_appointment'),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _filteredAppointments.length,
                        itemBuilder: (context, index) {
                          return AppointmentCard(
                            appointment: _filteredAppointments[index],
                            onAppointmentUpdated: _loadAppointments,
                            supabaseService: _supabaseService,
                            localizations: localizations,
                            isSmallScreen: isSmallScreen, // Pasar esta bandera a AppointmentCard
                          );
                        },
                      ),
              ),
            ],
          ),
          
          // Botón para agregar citas (abajo a la derecha)
          Positioned(
            bottom: 16.h,
            right: 16.w,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppointmentBookingPage(),
                  ),
                ).then((value) {
                  if (value == true) {
                    _loadAppointments();
                  }
                });
              },
              backgroundColor: const Color(0xFF1980E6),
              foregroundColor: Colors.white,
              child: Icon(
                Icons.add,
                size: AdaptiveSize.getIconSize(context, baseSize: 24),
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.w),
              ),
            ),
          ),
          
          // Botón asistente (abajo a la izquierda)
          Positioned(
            bottom: 16.h,
            left: 16.w,
            child: const AnimatedAssistantButton(),
          ),
        ],
      ),
    );
  }
}