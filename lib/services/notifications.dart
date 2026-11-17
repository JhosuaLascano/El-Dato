import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';

class Notifier {
  static final _p = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Guayaquil'));
    }
    await _p.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_owl'),
        // En iOS el permiso se pide al crear el primer recordatorio, no al abrir la app.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      'reminders',
      'Recordatorios',
      description: 'Pagos, tareas y compras de El Dato',
      importance: Importance.high,
      ledColor: AppColors.gold,
      enableLights: true,
    ));
    _ready = true;
  }

  static Future<void> requestPermissions() async {
    if (!_ready) return;
    await _android?.requestNotificationsPermission();
    await _ios?.requestPermissions(alert: true, badge: true, sound: true);
    if (await _android?.canScheduleExactNotifications() == false) {
      await _android?.requestExactAlarmsPermission();
    }
  }

  static NotificationDetails _details(String body, String title) => NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Recordatorios',
          channelDescription: 'Pagos, tareas y compras de El Dato',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_owl',
          color: AppColors.gold,
          largeIcon: const DrawableResourceAndroidBitmap('ic_notif_large'),
          // (ic_notif_large e ic_stat_owl se protegen en res/raw/keep.xml)
          ledColor: AppColors.gold,
          ledOnMs: 800,
          ledOffMs: 1200,
          enableLights: true,
          category: AndroidNotificationCategory.reminder,
          subText: 'El Dato',
          styleInformation: BigTextStyleInformation(body, contentTitle: title),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          subtitle: 'El Dato',
          interruptionLevel: InterruptionLevel.active,
        ),
      );

  static String _title(Reminder r) => r.title;

  static String _body(Reminder r) {
    final parts = <String>[ReminderKind.labels[r.kind] ?? 'Recordatorio'];
    if (r.amount != null) parts.add(money(r.amount!));
    if (r.note.isNotEmpty) parts.add(r.note);
    return parts.join(' · ');
  }

  static Future<void> schedule(Reminder r) async {
    try {
      await _schedule(r);
    } catch (e) {
      debugPrint('No se pudo programar el recordatorio: $e');
    }
  }

  static Future<void> _schedule(Reminder r) async {
    if (!_ready || r.id == null) return;
    await _p.cancel(id: r.id!);
    if (r.done) return;

    var when = r.due;
    final now = DateTime.now();
    if (r.repeat == Repeat.none) {
      if (!when.isAfter(now)) return;
    } else {
      while (!when.isAfter(now)) {
        when = Repeat.next(when, r.repeat);
      }
    }

    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final title = _title(r);
    final body = _body(r);
    await _p.zonedSchedule(
      id: r.id!,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details(body, title),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: switch (r.repeat) {
        Repeat.daily => DateTimeComponents.time,
        Repeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        Repeat.monthly => DateTimeComponents.dayOfMonthAndTime,
        _ => null,
      },
    );
  }

  static Future<void> cancel(int id) async {
    if (_ready) await _p.cancel(id: id);
  }

  static Future<void> cancelAll() async {
    if (_ready) await _p.cancelAll();
  }

  static Future<void> test() async {
    if (!_ready) return;
    const title = 'El Dato';
    const body = 'Así se verán tus recordatorios de pagos, tareas y compras.';
    await _p.show(id: 999999, title: title, body: body, notificationDetails: _details(body, title));
  }
}
