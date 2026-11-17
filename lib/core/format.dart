import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _num = NumberFormat('#,##0.00', 'es');

/// Montos se guardan en centavos (int) para evitar errores de redondeo.
String money(int cents, {bool sign = false}) {
  final s = _num.format(cents.abs() / 100);
  final pre = cents < 0 ? '-' : (sign && cents > 0 ? '+' : '');
  return '$pre\$ $s';
}

int? parseMoney(String input) {
  var t = input.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',') && t.contains('.')) {
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else {
    t = t.replaceAll(',', '.');
  }
  final v = double.tryParse(t);
  if (v == null) return null;
  return (v * 100).round();
}

String moneyInput(int cents) {
  final v = cents / 100;
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');
}

final moneyFormatter = TextInputFormatter.withFunction((oldV, newV) {
  return RegExp(r'^\d{0,9}([.,]\d{0,2})?$').hasMatch(newV.text) ? newV : oldV;
});

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
DateTime fromKey(int k) => DateTime(k ~/ 10000, (k ~/ 100) % 100, k % 100);
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String dayLabel(DateTime d) {
  final today = dateOnly(DateTime.now());
  final diff = today.difference(dateOnly(d)).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff == -1) return 'Mañana';
  final sameYear = d.year == today.year;
  return cap(DateFormat(sameYear ? "EEEE d 'de' MMMM" : "EEE d MMM yyyy", 'es').format(d));
}

String shortDate(DateTime d) => DateFormat('dd MMM yyyy', 'es').format(d);
String timeLabel(DateTime d) => DateFormat('HH:mm').format(d);
String monthLabel(int year, int month) => cap(DateFormat('MMMM yyyy', 'es').format(DateTime(year, month)));
