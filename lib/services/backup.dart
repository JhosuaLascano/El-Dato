import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';

class Backup {
  static String _fileName() => 'el_dato_respaldo_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json';

  static Future<Uint8List> _bytes(AppState s) async =>
      Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(await s.exportData())));

  /// Guarda el respaldo donde el usuario elija (Descargas, Drive, etc.).
  static Future<bool> saveToDevice(AppState s) async {
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Guardar respaldo',
      fileName: _fileName(),
      bytes: await _bytes(s),
      mimeType: 'application/json',
    );
    return uri != null;
  }

  /// Comparte el respaldo (WhatsApp, Gmail, Drive...).
  static Future<void> share(AppState s) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${_fileName()}');
    await f.writeAsBytes(await _bytes(s));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/json')],
      subject: 'Respaldo de El Dato',
      text: 'Respaldo de El Dato',
    ));
  }

  /// Devuelve los datos leídos o null si el usuario canceló.
  static Future<Map<String, dynamic>?> pick() async {
    final res = await FilePicker.pickFiles(type: FileType.any, dialogTitle: 'Elegir respaldo de El Dato');
    if (res.isEmpty) return null;
    final bytes = await res.first.readAsBytes();
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) throw const FormatException('Archivo inválido');
    return data;
  }
}
