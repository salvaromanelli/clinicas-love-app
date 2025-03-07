import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase.dart';
import '../booking_page.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Function() onAppointmentUpdated;
  final SupabaseService supabaseService;

  const AppointmentCard({
    Key? key,
    required this.appointment,
    required this.onAppointmentUpdated,
    required this.supabaseService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      final treatment = appointment['treatment'];
      final clinic = appointment['clinic'];
      
      // Verificar que los datos clave existan
      if (treatment == null || clinic == null || appointment['appointment_date'] == null) {
        print('Datos faltantes en la cita: ${appointment.toString()}');
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error: Datos de cita incompletos'),
          ),
        );
      }

      final appointmentDate = DateTime.parse(appointment['appointment_date']);
      final isUpcoming = appointmentDate.isAfter(DateTime.now());
      final status = appointment['status']?.toString() ?? '';
      final isCancelled = status == 'Cancelada';
      final isRescheduled = status == 'Reprogramada';
      
      return LayoutBuilder(
        builder: (context, constraints) {
          // Define breakpoints para diferentes tamaños de pantalla
          final isSmallScreen = constraints.maxWidth < 340;
          final isMediumScreen = constraints.maxWidth < 380;
          
          // Ajusta los tamaños de fuente según el tamaño de pantalla
          final titleFontSize = isSmallScreen ? 14.0 : 16.0;
          final subtitleFontSize = isSmallScreen ? 13.0 : 14.0;
          final bodyFontSize = isSmallScreen ? 14.0 : 16.0;
          final smallIconSize = isSmallScreen ? 16.0 : 20.0;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            elevation: 2.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(
                color: isCancelled 
                  ? Colors.red.withOpacity(0.3) 
                  : isRescheduled 
                    ? Colors.amber.withOpacity(0.3)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado con estado de la cita
                  Container(
                    decoration: BoxDecoration(
                      color: isCancelled 
                        ? Colors.red.withOpacity(0.1) 
                        : isRescheduled 
                          ? Colors.amber.withOpacity(0.1)
                          : isUpcoming 
                            ? const Color(0xFF1980E6).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12.0),
                        topRight: Radius.circular(12.0),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Icon(
                          isCancelled 
                            ? Icons.cancel_outlined 
                            : isRescheduled 
                              ? Icons.update_outlined
                              : isUpcoming 
                                ? Icons.event_available
                                : Icons.event_busy,
                          color: isCancelled 
                            ? Colors.red
                            : isRescheduled 
                              ? Colors.amber
                              : isUpcoming 
                                ? const Color(0xFF1980E6)
                                : Colors.grey,
                          size: 24.0,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                treatment['name'],
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: isCancelled 
                                    ? Colors.red
                                    : isRescheduled 
                                      ? Colors.amber.shade800
                                      : isUpcoming 
                                        ? const Color(0xFF1980E6)
                                        : Colors.grey.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                isCancelled 
                                  ? 'Cita Cancelada' 
                                  : isRescheduled 
                                    ? 'Cita Reprogramada'
                                    : isUpcoming 
                                      ? 'Cita Programada'
                                      : 'Cita Pasada',
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: isCancelled 
                                    ? Colors.red.shade700
                                    : isRescheduled 
                                      ? Colors.amber.shade700
                                      : isUpcoming 
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenido de la cita
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fecha y hora
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: smallIconSize,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8.0),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, d MMMM yyyy', 'es').format(appointmentDate),
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    DateFormat('HH:mm').format(appointmentDate),
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16.0),
                        
                        // Clínica
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: smallIconSize,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8.0),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clinic['name'],
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    clinic['address'],
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16.0),
                        
                        // Precio
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.euro_outlined,
                              size: smallIconSize,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              '${treatment['price']}€',
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        
                        // Acciones
                      
                        if (isUpcoming && !isCancelled && !isRescheduled) 
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: LayoutBuilder(
                              builder: (context, btnConstraints) {
                                // Si el ancho es menor a 320px, usa botones más pequeños
                                final bool isNarrow = btnConstraints.maxWidth < 320;
                                
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showCancelConfirmationDialog(context),
                                      icon: Icon(Icons.cancel_outlined, 
                                        color: Colors.red, 
                                        size: isNarrow ? 16 : 20
                                      ),
                                      label: Text('Cancelar', 
                                        style: TextStyle(
                                          fontSize: isNarrow ? 12 : 14,
                                        )
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        padding: isNarrow 
                                          ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0)
                                          : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      ),
                                    ),
                                    SizedBox(width: isNarrow ? 4.0 : 8.0),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AppointmentBookingPage(
                                              initialClinic: clinic,
                                              initialTreatment: treatment,
                                              appointmentToReschedule: appointment,
                                            ),
                                          ),
                                        ).then((value) {
                                          if (value == true) {
                                            onAppointmentUpdated();
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        Icons.edit_calendar, 
                                        color: const Color(0xFF1980E6), 
                                        size: isNarrow ? 16 : 20
                                      ),
                                      label: Text('Reprogramar', 
                                        style: TextStyle(
                                          fontSize: isNarrow ? 12 : 14,
                                        )
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFF1980E6),
                                        padding: isNarrow 
                                          ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0)
                                          : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
                    

    } catch (e) {
      print('Error renderizando tarjeta de cita: $e');
      return Card(
        margin: const EdgeInsets.only(bottom: 16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error al procesar cita: ${e.toString()}'),
        ),
      );
    }
  }
  
  // Método privado para mostrar el diálogo de cancelación
  void _showCancelConfirmationDialog(BuildContext context) async {
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

    if (result && context.mounted) {
      // Usuario confirmó cancelación
      try {
        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancelando cita...')),
        );
        
        await supabaseService.updateAppointmentStatus(appointmentId, 'Cancelada');
        
        // Refrescar la lista
        onAppointmentUpdated();
        
        // Mostrar confirmación si el widget sigue montado
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita cancelada correctamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cancelar la cita: ${e.toString()}')),
          );
        }
      }
    }
  }
}