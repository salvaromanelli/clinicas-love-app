import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:rxdart/rxdart.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  final BehaviorSubject<String?> onNotificationClick = BehaviorSubject();
  
  // Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    tz.initializeTimeZones();
    
    // Configuración para Android
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    final DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    // Configuración general
    final InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );
    
    // Inicializar el plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
    
    // Solicitar permisos en iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      
      await requestAndCheckPermissions();
      await showTestNotification();
      
    }

    

  Future<void> showTestNotification() async {
  print('Mostrando notificación de prueba...');
  
  final now = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
  
  await _scheduleNotification(
    id: 999999,
    title: 'Prueba de Notificaciones',
    body: 'Si ves esta notificación, el sistema está funcionando correctamente.',
    scheduledTime: now,
    payload: 'test_notification',
  );
  
  print('Notificación de prueba programada para: $now');
}
  
  // Para iOS < 10
  void onDidReceiveLocalNotification(int id, String? title, String? body, String? payload) {
    print('Notification received: $id, $title, $body, $payload');
  }
  
  // Cuando el usuario interactúa con la notificación
  void onDidReceiveNotificationResponse(NotificationResponse details) {
    if (details.payload != null) {
      onNotificationClick.add(details.payload);
    }
  }
  
  // Programar notificación para cita
// Reemplaza la sección problemática (línea ~149-161) por lo siguiente:

  Future<void> scheduleAppointmentNotifications(
    String appointmentId,
    String treatmentName,
    String clinicName,
    DateTime appointmentDate,
  ) async {
    // Cancelar notificaciones anteriores para esta cita (en caso de reprogramación)
    await cancelAppointmentNotifications(appointmentId);

    // Añade logs detallados para depuración
    print('==== PROGRAMACIÓN DE NOTIFICACIONES ====');
    print('ID de cita: $appointmentId');
    print('Tratamiento: $treatmentName');
    print('Clínica: $clinicName');
    print('Fecha cita: $appointmentDate');
    print('Hora actual: ${DateTime.now()}');
    
    // 1. Notificación 2 días antes
    final twoDaysBefore = tz.TZDateTime.from(
      appointmentDate.subtract(const Duration(days: 2)),
      tz.local,
    );
    
    // Solo programar si es en el futuro
    if (twoDaysBefore.isAfter(tz.TZDateTime.now(tz.local))) {
      await _scheduleNotification(
        id: int.parse(appointmentId.substring(0, 8), radix: 16) % 100000 * 10 + 1,
        title: 'Recordatorio de cita en 2 días',
        body: '📅 Recuerda: tienes cita para $treatmentName en $clinicName el ${_formatDate(appointmentDate)}',
        scheduledTime: twoDaysBefore,
        payload: 'appointment_$appointmentId',
      );
    }
    
    // 2. Notificación el mismo día (3 horas antes)
    final sameDay = tz.TZDateTime.from(
      appointmentDate.subtract(const Duration(hours: 3)),
      tz.local,
    );
    
    // Solo programar si es en el futuro
    if (sameDay.isAfter(tz.TZDateTime.now(tz.local))) {
      await _scheduleNotification(
        id: int.parse(appointmentId.substring(0, 8), radix: 16) % 100000 * 10 + 2,
        title: 'Tu cita es hoy',
        body: '⏰ Hoy tienes cita para $treatmentName en $clinicName a las ${_formatTime(appointmentDate)}',
        scheduledTime: sameDay,
        payload: 'appointment_$appointmentId',
      );
    }

    // 3. Notificación inmediata para citas próximas (programadas para pronto)
    final timeUntilAppointment = appointmentDate.difference(DateTime.now());
    print('Tiempo hasta la cita: ${timeUntilAppointment.inMinutes} minutos');
    
    // Si la cita es en menos de 3 horas, envía una notificación inmediata
    if (timeUntilAppointment.inHours < 3 && timeUntilAppointment.inMinutes > 0) {
      print('La cita es próxima, programando notificación inmediata');
      
      // Programar para 15 segundos después
      final immediateTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
      
      await _scheduleNotification(
        id: int.parse(appointmentId.substring(0, 8), radix: 16) % 100000 * 10 + 3,
        title: '¡Cita programada para hoy!',
        body: '📅 Tu cita para $treatmentName en $clinicName es en ${_formatTimeRemaining(appointmentDate)}',
        scheduledTime: immediateTime,
        payload: 'appointment_$appointmentId',
      );
      
      print('Notificación inmediata programada para: $immediateTime');
    }

      // 4. SIEMPRE enviar una notificación de confirmación
  print('Enviando notificación de confirmación inmediata');
  final confirmationTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      
  await _scheduleNotification(
    id: int.parse(appointmentId.substring(0, 8), radix: 16) % 100000 * 10 + 4,
    title: 'Cita registrada correctamente',
    body: '✅ Tu cita para $treatmentName ha sido programada para el ${_formatDate(appointmentDate)} a las ${_formatTime(appointmentDate)}',
    scheduledTime: confirmationTime,
    payload: 'appointment_confirmation_$appointmentId',
  );
  
  print('Notificación de confirmación programada para: $confirmationTime');
  }
  
  String _formatTimeRemaining(DateTime appointmentTime) {
    final now = DateTime.now();
    final difference = appointmentTime.difference(now);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutos';
    } else {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return '$hours hora${hours > 1 ? 's' : ''}${minutes > 0 ? ' y $minutes minutos' : ''}';
    }
  }

  // Programar una notificación individual
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String payload,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_channel',
          'Recordatorios de citas',
          channelDescription: 'Notificaciones para recordar citas programadas',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    
    print('Notificación programada para ${scheduledTime.toString()}');
  }
  
  // Cancelar notificaciones para una cita específica
  Future<void> cancelAppointmentNotifications(String appointmentId) async {
    final baseId = int.parse(appointmentId.substring(0, 8), radix: 16) % 100000 * 10;
    
    // Cancelar ambas notificaciones relacionadas con esta cita
    await flutterLocalNotificationsPlugin.cancel(baseId + 1);
    await flutterLocalNotificationsPlugin.cancel(baseId + 2);
    
    print('Notificaciones para cita $appointmentId canceladas');
  }
  
  // Formatear fecha
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // Formatear hora
  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> requestAndCheckPermissions() async {
  if (Platform.isIOS) {
    print('Solicitando permisos en iOS');
    final bool? result = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    print('Resultado de solicitud de permisos en iOS: $result');
    return result ?? false;
  } else {
    return true;
  }
}
}


