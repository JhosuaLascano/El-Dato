import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../services/notifications.dart';
import '../widgets/common.dart';
import '../widgets/segmented.dart';
import 'add_txn.dart';

const _kindIcon = {
  ReminderKind.pago: Icons.credit_card_rounded,
  ReminderKind.tarea: Icons.task_alt_rounded,
  ReminderKind.compra: Icons.shopping_cart_rounded,
  ReminderKind.otro: Icons.notifications_rounded,
};

const _kindColor = {
  ReminderKind.pago: 0xFFF2C64B,
  ReminderKind.tarea: 0xFF5B9DFF,
  ReminderKind.compra: 0xFFFF9F43,
  ReminderKind.otro: 0xFFA78BFA,
};

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    final now = DateTime.now();
    final today = dateOnly(now);
    final overdue = s.pending.where((r) => r.due.isBefore(now)).toList();
    final todayL = s.pending.where((r) => !r.due.isBefore(now) && dateOnly(r.due) == today).toList();
    final later = s.pending.where((r) => dateOnly(r.due).isAfter(today)).toList();

    Widget group(String title, List<Reminder> list, {Color? color}) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color ?? AppColors.muted, fontSize: 13)),
        ),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(children: [for (final r in list) ReminderTile(key: ValueKey('r${r.id}'), r: r)]),
        ),
      ]);
    }

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 120 + pad.bottom),
      children: [
        Row(children: [
          const Expanded(
            child: Text('Recordatorios', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
          Pressable(
            onTap: () => showReminderEditor(context, null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(30)),
              child: const Row(children: [
                Icon(Icons.add_rounded, color: Colors.black, size: 20),
                SizedBox(width: 4),
                Text('Nuevo', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Segmented<bool>(
          values: const [false, true],
          labels: ['Pendientes (${s.pending.length})', 'Hechos'],
          value: _showDone,
          onChanged: (v) => setState(() => _showDone = v),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showDone
              ? (s.done.isEmpty
                  ? _empty('Aún no completas recordatorios')
                  : Column(key: const ValueKey('done'), children: [group('Completados', s.done)]))
              : (s.pending.isEmpty
                  ? _empty('No tienes pendientes. ¡Todo al día!')
                  : Column(key: const ValueKey('pending'), children: [
                      group('Vencidos', overdue, color: AppColors.red),
                      group('Hoy', todayL, color: AppColors.gold),
                      group('Próximos', later),
                    ])),
        ),
      ],
    );
  }

  Widget _empty(String msg) => Padding(
        key: ValueKey(msg),
        padding: const EdgeInsets.only(top: 40),
        child: Column(children: [
          const Owl(size: 100),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}

class ReminderTile extends StatelessWidget {
  const ReminderTile({super.key, required this.r, this.compact = false});
  final Reminder r;
  final bool compact;

  Future<void> _complete(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final s = AppScope.read(context);
    if (r.done) {
      await s.reopenReminder(r);
      return;
    }
    await s.completeReminder(r);
    if (!context.mounted) return;
    if (r.kind == ReminderKind.pago && r.amount != null) {
      final reg = await confirm(context, '¿Registrar el pago?',
          '¿Quieres registrar ${money(r.amount!)} de "${r.title}" como gasto?', ok: 'Registrar', danger: false);
      if (reg && context.mounted) {
        Navigator.of(context).push(smoothRoute(AddTxnScreen(initialAmount: r.amount, initialNote: r.title)));
      }
    } else {
      toast(context, r.repeat == Repeat.none ? '¡Hecho!' : 'Hecho. Próximo: ${dayLabel(Repeat.next(r.due, r.repeat))}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_kindColor[r.kind] ?? 0xFFA78BFA);
    final overdue = !r.done && r.due.isBefore(DateTime.now());
    final when = '${dayLabel(r.due)} · ${timeLabel(r.due)}';
    final tile = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showReminderEditor(context, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => _complete(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10, left: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: r.done ? AppColors.gold : Colors.transparent,
                border: Border.all(color: r.done ? AppColors.gold : AppColors.muted, width: 2),
              ),
              child: r.done ? const Icon(Icons.check_rounded, size: 18, color: Colors.black) : null,
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(_kindIcon[r.kind], color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: r.done ? TextDecoration.lineThrough : null,
                  color: r.done ? AppColors.muted : AppColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                  child: Text(when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: overdue ? AppColors.red : AppColors.muted, fontSize: 12.5)),
                ),
                if (r.repeat != Repeat.none) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.repeat_rounded, size: 14, color: AppColors.gold),
                  if (!compact) Text(' ${Repeat.labels[r.repeat]}', style: const TextStyle(color: AppColors.gold, fontSize: 12)),
                ],
              ]),
            ]),
          ),
          if (r.amount != null) Text(money(r.amount!), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
    if (compact) return tile;
    return Dismissible(
      key: ValueKey('rd${r.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: AppColors.red),
      ),
      confirmDismiss: (_) => confirm(context, 'Eliminar recordatorio', '¿Eliminar "${r.title}"?'),
      onDismissed: (_) => AppScope.read(context).deleteReminder(r),
      child: tile,
    );
  }
}

Future<void> showReminderEditor(BuildContext context, Reminder? r) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReminderEditor(r: r),
  );
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({this.r});
  final Reminder? r;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final _title = TextEditingController(text: widget.r?.title ?? '');
  late final _note = TextEditingController(text: widget.r?.note ?? '');
  late final _amount = TextEditingController(text: widget.r?.amount != null ? moneyInput(widget.r!.amount!) : '');
  late String _kind = widget.r?.kind ?? ReminderKind.pago;
  late String _repeat = widget.r?.repeat ?? Repeat.none;
  late DateTime _due = widget.r?.due ?? _defaultDue();

  static DateTime _defaultDue() {
    final n = DateTime.now().add(const Duration(hours: 1));
    return DateTime(n.year, n.month, n.day, n.hour);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (t != null) setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    final s = AppScope.read(context);
    await Notifier.requestPermissions();
    final amt = parseMoney(_amount.text);
    await s.saveReminder(Reminder(
      id: widget.r?.id,
      title: _title.text.trim(),
      note: _note.text.trim(),
      kind: _kind,
      due: _due,
      repeat: _repeat,
      amount: amt != null && amt > 0 ? amt : null,
      done: widget.r?.done ?? false,
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: Text(widget.r == null ? 'Nuevo recordatorio' : 'Editar recordatorio',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            if (widget.r != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final s = AppScope.read(context);
                  if (await confirm(context, 'Eliminar recordatorio', '¿Eliminar "${widget.r!.title}"?')) {
                    await s.deleteReminder(widget.r!);
                    nav.pop();
                  }
                },
              ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in ReminderKind.all)
              ChoiceChip(
                avatar: Icon(_kindIcon[k], size: 18, color: _kind == k ? Colors.black : Color(_kindColor[k]!)),
                label: Text(ReminderKind.labels[k]!),
                selected: _kind == k,
                showCheckmark: false,
                labelStyle: TextStyle(color: _kind == k ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _kind = k),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.r == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ej. Pagar internet, comprar pan, tarea de inglés'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [moneyFormatter],
                decoration: const InputDecoration(hintText: 'Monto (opcional)', prefixText: '\$ '),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nota (opcional)'),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _pickerBox(Icons.calendar_today_rounded, dayLabel(_due), _pickDate)),
            const SizedBox(width: 10),
            Expanded(child: _pickerBox(Icons.schedule_rounded, timeLabel(_due), _pickTime)),
          ]),
          const SizedBox(height: 14),
          const Text('Repetir', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final rp in Repeat.all)
              ChoiceChip(
                label: Text(Repeat.labels[rp]!),
                selected: _repeat == rp,
                showCheckmark: false,
                labelStyle: TextStyle(color: _repeat == rp ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _repeat = rp),
              ),
          ]),
          const SizedBox(height: 22),
          GoldButton(
            label: 'Guardar recordatorio',
            icon: Icons.notifications_active_rounded,
            enabled: _title.text.trim().isNotEmpty,
            onTap: _save,
          ),
        ]),
      ),
    );
  }

  Widget _pickerBox(IconData icon, String text, VoidCallback onTap) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.gold, size: 19),
            const SizedBox(width: 8),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
      );
}
