import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase.dart';
import '../booking_page.dart';
import '../i18n/app_localizations.dart';
import '../utils/adaptive_sizing.dart'; 

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final Function() onAppointmentUpdated;
  final SupabaseService supabaseService;
  final AppLocalizations localizations;
  final bool isSmallScreen;

  const AppointmentCard({
    Key? key,
    required this.appointment,
    required this.onAppointmentUpdated,
    required this.supabaseService,
    required this.localizations,
    this.isSmallScreen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    try {
      final treatment = appointment['treatment'];
      final clinic = appointment['clinic'];
      
      // Verificar que los datos clave existan
      if (treatment == null || clinic == null || appointment['appointment_date'] == null) {
        print('Datos faltantes en la cita: ${appointment.toString()}');
        return Card(
          color: const Color(0xFF1C2126), // Fondo oscuro para error
          margin: EdgeInsets.only(bottom: 12.h),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'Error: Datos de cita incompletos', 
              style: TextStyle(fontSize: 14.sp, color: Colors.white70)
            ),
          ),
        );
      }

      final appointmentDate = DateTime.parse(appointment['appointment_date']);
      final isUpcoming = appointmentDate.isAfter(DateTime.now());
      final status = appointment['status']?.toString() ?? '';
      final isCancelled = status == 'Cancelada';
      final isRescheduled = status == 'Reprogramada';
      
      // Usar isSmallScreen pasado desde el padre
      final titleFontSize = isSmallScreen ? 14.sp : 16.sp;
      final subtitleFontSize = isSmallScreen ? 13.sp : 14.sp;
      final bodyFontSize = isSmallScreen ? 14.sp : 16.sp;
      
      return Card(
        margin: EdgeInsets.only(bottom: 16.h),
        color: const Color(0xFF1C2126), // CAMBIO: Fondo oscuro para tarjetas
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.w),
          side: BorderSide(
            color: isCancelled 
              ? Colors.red.withOpacity(0.4) 
              : isRescheduled 
                ? Colors.amber.withOpacity(0.4)
                : Colors.transparent,
            width: 1.5.w,
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
                    ? Colors.red.withOpacity(0.15) 
                    : isRescheduled 
                      ? Colors.amber.withOpacity(0.15)
                      : isUpcoming 
                        ? const Color(0xFF1980E6).withOpacity(0.15)
                        : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.w),
                    topRight: Radius.circular(12.w),
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                        ? Colors.red.shade300
                        : isRescheduled 
                          ? Colors.amber.shade300
                          : isUpcoming 
                            ? const Color(0xFF1980E6)
                            : Colors.grey.shade400,
                      size: AdaptiveSize.getIconSize(context, baseSize: 24),
                    ),
                    SizedBox(width: 12.w),
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
                                ? Colors.red.shade300
                                : isRescheduled 
                                  ? Colors.amber.shade300
                                  : isUpcoming 
                                    ? Colors.white
                                    : Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            isCancelled 
                              ? localizations.get('cancelled_appointment') 
                              : isRescheduled 
                                ? localizations.get('rescheduled_appointment')
                                : isUpcoming 
                                  ? localizations.get('scheduled_appointment')
                                  : localizations.get('past_appointment'),
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: isCancelled 
                                ? Colors.red.shade200
                                : isRescheduled 
                                  ? Colors.amber.shade200
                                  : isUpcoming 
                                    ? Colors.white70
                                    : Colors.grey.shade500,
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
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fecha y hora
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 16 : 20),
                          color: Colors.white70,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, d MMMM yyyy', Localizations.localeOf(context).languageCode).format(appointmentDate),
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                DateFormat('HH:mm').format(appointmentDate),
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // Clínica
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 16 : 20),
                          color: Colors.white70,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinic['name'],
                                style: TextStyle(
                                  fontSize: bodyFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                clinic['address'],
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16.h),
                    
                    // Precio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.euro_outlined,
                          size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 16 : 20),
                          color: Colors.white70,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${treatment['price']}€',
                          style: TextStyle(
                            fontSize: bodyFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    // Acciones
                    if (isUpcoming && !isCancelled && !isRescheduled) 
                      Padding(
                        padding: EdgeInsets.only(top: 24.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showCancelConfirmationDialog(context),
                              icon: Icon(
                                Icons.cancel_outlined, 
                                color: Colors.red.shade300, 
                                size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 16 : 20),
                              ),
                              label: Text(
                                localizations.get('cancel'), 
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                                  color: Colors.red.shade300,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.1),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 6.w : 12.w, 
                                  vertical: isSmallScreen ? 4.h : 8.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.w),
                                ),
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 4.w : 8.w),
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
                                size: AdaptiveSize.getIconSize(context, baseSize: isSmallScreen ? 16 : 20),
                              ),
                              label: Text(
                                localizations.get('reschedule'), 
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                                  color: const Color(0xFF1980E6),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF1980E6).withOpacity(0.1),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 6.w : 12.w, 
                                  vertical: isSmallScreen ? 4.h : 8.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.w),
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
      );
    } catch (e) {
      print('Error renderizando tarjeta de cita: $e');
      return Card(
        color: const Color(0xFF1C2126), // Fondo oscuro para tarjetas de error
        margin: EdgeInsets.only(bottom: 16.h),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'Error al procesar cita: ${e.toString()}',
            style: TextStyle(fontSize: 14.sp, color: Colors.white70),
          ),
        ),
      );
    }
  }
  
  // Método privado para mostrar el diálogo de cancelación
  void _showCancelConfirmationDialog(BuildContext context) async {
    // Inicializar AdaptiveSize para el diálogo
    AdaptiveSize.initialize(context);
    
    final String appointmentId = appointment['id'];
    final bool result = await showDialog(
      context: context,
      builder: (context) {
        // Reinicializar AdaptiveSize en el builder del diálogo
        AdaptiveSize.initialize(context);
        
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2126), // Fondo oscuro
          title: Text(
            localizations.get('cancel_appointment'),
            style: TextStyle(
              fontSize: isSmallScreen ? 16.sp : 18.sp,
              color: Colors.white,
            ),
          ),
          content: Text(
            localizations.get('cancel_confirmation'),
            style: TextStyle(
              fontSize: isSmallScreen ? 14.sp : 16.sp,
              color: Colors.white70,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.w),
          ),
          contentPadding: EdgeInsets.all(16.w),
          actionsPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                localizations.get('keep_appointment'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                localizations.get('yes_cancel'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 12.sp : 14.sp,
                  color: Colors.red.shade300,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;

    if (result && context.mounted) {
      // Usuario confirmó cancelación
      try {
        // Mostrar indicador de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.get('cancelling_appointment'),
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: const Color(0xFF1C2126),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          ),
        );
        
        // Actualizar el estado de la cita en Supabase
        await supabaseService.updateAppointmentStatus(appointmentId, 'Cancelada');
        
        // Actualizar la lista de citas
        onAppointmentUpdated();
        
        // Mostrar mensaje de éxito
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.get('appointment_cancelled_success'),
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: const Color(0xFF1C2126),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
          );
        }
      } catch (e) {
        // Mostrar mensaje de error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.get('cancel_error')}: ${e.toString()}',
                style: TextStyle(fontSize: 14.sp),
              ),
              backgroundColor: Colors.red.shade800,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
          );
        }
      }
    }
  }
}