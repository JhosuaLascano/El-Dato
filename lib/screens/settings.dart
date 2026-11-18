import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../services/backup.dart';
import '../services/notifications.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Center(child: Owl(size: 110)),
          const SizedBox(height: 8),
          const Center(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'EL ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              TextSpan(text: 'DATO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppColors.gold)),
            ])),
          ),
          const Center(child: Text('Tus gastos, en buenas alas.', style: TextStyle(color: AppColors.muted))),
          const SizedBox(height: 20),
          const SectionTitle('Saldo', icon: Icons.account_balance_wallet_rounded),
          _tile(
            icon: Icons.tune_rounded,
            title: 'Ajustar saldo',
            subtitle: 'Saldo actual: ${money(s.balance)}. Corrígelo si no coincide con tu billetera.',
            onTap: () => _adjust(context, s),
          ),
          const SizedBox(height: 14),
          const SectionTitle('Respaldo de datos', icon: Icons.backup_rounded),
          const Panel(
            color: Color(0xFF1C1A10),
            child: Text(
              'Tus datos se guardan en el teléfono y se mantienen al instalar actualizaciones de El Dato. '
              'Solo se pierden si desinstalas la app o cambias de teléfono, por eso conviene exportar un respaldo cada cierto tiempo '
              '(guárdalo en Drive o envíatelo por WhatsApp).',
              style: TextStyle(color: Color(0xFFD9CFB4), height: 1.4, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            icon: Icons.save_alt_rounded,
            title: 'Guardar respaldo en el teléfono',
            subtitle: 'Elige la carpeta (ej. Descargas)',
            onTap: () async {
              try {
                final ok = await Backup.saveToDevice(s);
                if (context.mounted && ok) toast(context, 'Respaldo guardado');
              } catch (e) {
                if (context.mounted) toast(context, 'No se pudo guardar: $e');
              }
            },
          ),
          _tile(
            icon: Icons.share_rounded,
            title: 'Compartir respaldo',
            subtitle: 'Enviar a Drive, WhatsApp, correo…',
            onTap: () async {
              try {
                await Backup.share(s);
              } catch (e) {
                if (context.mounted) toast(context, 'No se pudo compartir: $e');
              }
            },
          ),
          _tile(
            icon: Icons.upload_file_rounded,
            title: 'Importar respaldo',
            subtitle: 'Restaura todos tus datos desde un archivo .json',
            onTap: () => _import(context, s),
          ),
          const SizedBox(height: 14),
          const SectionTitle('Notificaciones', icon: Icons.notifications_rounded),
          _tile(
            icon: Icons.notifications_active_rounded,
            title: 'Permitir notificaciones',
            subtitle: 'Necesario para avisarte de pagos, tareas y compras',
            onTap: () async {
              await Notifier.requestPermissions();
              await s.rescheduleAll();
              if (context.mounted) toast(context, 'Listo. Recordatorios programados.');
            },
          ),
          _tile(
            icon: Icons.campaign_rounded,
            title: 'Probar notificación',
            subtitle: 'Mira cómo se ve un aviso de El Dato',
            onTap: () async {
              await Notifier.requestPermissions();
              await Notifier.test();
            },
          ),
          const SizedBox(height: 24),
          const Center(child: Text('El Dato · v1.2.0 · por LA DATA', style: TextStyle(color: AppColors.muted, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _tile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        radius: 20,
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }

  Future<void> _adjust(BuildContext context, AppState s) async {
    final c = TextEditingController(text: moneyInput(s.balance.abs()));
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cuánto tienes ahora?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Se registrará un ajuste para que tu saldo quede en este monto.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [moneyFormatter],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold),
            decoration: const InputDecoration(prefixText: '\$ '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, parseMoney(c.text)),
            child: const Text('Ajustar'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null) return;
    await s.adjustBalance(v);
    if (context.mounted) toast(context, 'Saldo ajustado a ${money(v)}');
  }

  Future<void> _import(BuildContext context, AppState s) async {
    final ok = await confirm(
      context,
      'Importar respaldo',
      'Los datos actuales se reemplazarán por los del archivo. Te recomendamos guardar un respaldo antes.',
      ok: 'Elegir archivo',
      danger: false,
    );
    if (!ok) return;
    try {
      final data = await Backup.pick();
      if (data == null) return;
      await s.importData(data);
      if (context.mounted) toast(context, 'Datos restaurados');
    } catch (e) {
      if (context.mounted) toast(context, 'No se pudo importar: ${e is FormatException ? e.message : e}');
    }
  }
}
