import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/supabase.dart';
import 'booking_page.dart';
import 'widgets/appointment_card.dart';

class RecomendacionesPage extends StatefulWidget {
  const RecomendacionesPage({super.key});

  @override
  State<RecomendacionesPage> createState() => _RecomendacionesPageState();
}

class _RecomendacionesPageState extends State<RecomendacionesPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _filteredAppointments = []; // Añade esta línea
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'upcoming', 'past'

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

// Modifica el método _loadAppointments para añadir manejo de errores y logs

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
        SnackBar(content: Text('Error al cargar citas: ${e.toString()}')),
      );
    }
  }
}
  
  // Nuevo método para actualizar _filteredAppointments
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

  Future<void> _showCancelConfirmationDialog(Map<String, dynamic> appointment) async {
    final String appointmentId = appointment['id'];
    final bool result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: const Text('¿Está seguro de que desea cancelar esta cita? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    ) ?? false;

    if (result && mounted) {
      // Usuario confirmó cancelación
      try {
        setState(() {
          _isLoading = true; // Mostrar indicador de carga
        });
        
        await _supabaseService.updateAppointmentStatus(appointmentId, 'Cancelada');
        
        // Refrescar la lista
        await _loadAppointments();
        
        // Mostrar confirmación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita cancelada correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cancelar la cita: ${e.toString()}')),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Citas', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF1980E6),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter chips
          LayoutBuilder(
            builder: (context, constraints) {
              // Determinar si es una pantalla pequeña
              final isSmallScreen = constraints.maxWidth < 340;
              final chipPadding = isSmallScreen ? 
                const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0) : 
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0);
                
              final labelStyle = TextStyle(
                fontSize: isSmallScreen ? 12.0 : 14.0,
              );
              
              return Padding(
                padding: chipPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: FilterChip(
                          label: Text('Todas', style: labelStyle),
                          selected: _filterStatus == 'all',
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = 'all';
                              _updateFilteredAppointments(); // Actualiza la lista filtrada
                            });
                          },
                          selectedColor: const Color(0xFF1980E6).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF1980E6),
                          padding: isSmallScreen ? const EdgeInsets.symmetric(horizontal: 2.0) : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: FilterChip(
                          label: Text('Próximas', style: labelStyle),
                          selected: _filterStatus == 'upcoming',
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = 'upcoming';
                              _updateFilteredAppointments(); // Actualiza la lista filtrada
                            });
                          },
                          selectedColor: const Color(0xFF1980E6).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF1980E6),
                          padding: isSmallScreen ? const EdgeInsets.symmetric(horizontal: 2.0) : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: FilterChip(
                          label: Text('Anteriores', style: labelStyle),
                          selected: _filterStatus == 'past',
                          onSelected: (selected) {
                            setState(() {
                              _filterStatus = 'past';
                              _updateFilteredAppointments(); // Actualiza la lista filtrada
                            });
                          },
                          selectedColor: const Color(0xFF1980E6).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF1980E6),
                          padding: isSmallScreen ? const EdgeInsets.symmetric(horizontal: 2.0) : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
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
                        const Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No tiene citas programadas',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
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
                          ),
                          child: const Text('Programar una cita'),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _filteredAppointments.length,
                    itemBuilder: (context, index) {
                      return AppointmentCard(
                        appointment: _filteredAppointments[index],
                        onAppointmentUpdated: _loadAppointments,
                        supabaseService: _supabaseService,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add),
      ),
    );
  }
}
              
           