import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../data/app_state.dart';

/// Envía saldo y pendientes al widget de la pantalla de inicio (iOS y Android)
/// y recibe las acciones que el usuario toca en él ("add", "reminders").
class WidgetSync {
  static const _ch = MethodChannel('el_dato/widget');

  /// Última acción pedida desde el widget; la pantalla principal la escucha.
  static final action = ValueNotifier<String?>(null);

  static Timer? _debounce;
  static String? _last;

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  static Future<void> init(AppState s) async {
    if (!_supported) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'action') await takePending();
    });
    s.addListener(() => schedule(s));
    await push(s);
    await takePending();
  }

  /// Revisa si la app se abrió desde el widget (al iniciar o al volver).
  static Future<void> takePending() async {
    if (!_supported) return;
    try {
      _emit(await _ch.invokeMethod<String>('takeAction'));
    } catch (_) {}
  }

  static void _emit(String? a) {
    if (a == null || a.isEmpty) return;
    action.value = null;
    action.value = a;
  }

  static void schedule(AppState s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => push(s));
  }

  static Future<void> push(AppState s) async {
    if (!_supported) return;
    final now = DateTime.now();
    final pending = s.pending;
    final data = jsonEncode({
      'balance': money(s.balance),
      'today': money(s.todaySpent),
      'pendingCount': pending.length,
      'overdueCount': pending.where((r) => r.due.isBefore(now)).length,
      'pending': [
        for (final r in pending.take(3))
          {
            'title': r.title,
            'kind': r.kind,
            'due': r.due.millisecondsSinceEpoch,
            'amount': r.amount == null ? '' : money(r.amount!),
          }
      ],
    });
    if (data == _last) return;
    _last = data;
    try {
      await _ch.invokeMethod('update', data);
    } catch (e) {
      debugPrint('Widget no disponible: $e');
    }
  }
}
