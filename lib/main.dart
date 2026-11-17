import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/db.dart';
import 'screens/shell.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final dbFuture = AppDb.open();
  await initializeDateFormatting('es');
  // Las notificaciones nunca deben impedir que la app abra.
  try {
    await Notifier.init();
  } catch (e) {
    debugPrint('Notificaciones no disponibles: $e');
  }
  try {
    final state = AppState(await dbFuture);
    await state.load();
    runApp(ElDatoApp(state: state));
  } catch (e) {
    // Nunca dejar una pantalla negra: mostrar el error.
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('El Dato no pudo iniciar:\n$e', style: const TextStyle(color: AppColors.text)),
          ),
        ),
      ),
    ));
  }
}

class ElDatoApp extends StatelessWidget {
  const ElDatoApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'El Dato',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Shell(),
      ),
    );
  }
}
