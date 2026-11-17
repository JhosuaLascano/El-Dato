import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/piggy.dart';
import 'home.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  AppState? _s;
  List<Txn> _moves = [];
  int _coin = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_s == null) {
      _s = AppScope.read(context);
      _s!.txVersion.addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    _s?.txVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = _s!.savingsId;
    if (id == null) return;
    final list = await _s!.queryTxns(TxFilter(categories: {id}), limit: 300);
    if (mounted) setState(() => _moves = list);
  }

  Future<void> _move({required bool deposit}) async {
    final s = AppScope.read(context);
    final res = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoveSheet(deposit: deposit, saved: s.saved, balance: s.balance),
    );
    if (res == null) return;
    HapticFeedback.mediumImpact();
    if (deposit) {
      await s.deposit(res.$1, res.$2);
      if (!mounted) return;
      setState(() => _coin++);
      if (mounted && s.goal != null && s.saved >= s.goal!) {
        toast(context, '¡Meta cumplida! Llenaste el chanchito.');
      }
    } else {
      await s.withdraw(res.$1, res.$2);
    }
  }

  Future<void> _editGoal() async {
    final s = AppScope.read(context);
    final res = await showModalBottomSheet<(int?, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(goal: s.goal, name: s.goalName),
    );
    if (res == null) return;
    await s.setGoal(res.$1, res.$2);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    final goal = s.effectiveGoal;
    final hasGoal = s.goal != null;
    final fill = goal <= 0 ? 0.0 : (s.saved / goal).clamp(0.0, 1.0);
    final pct = (fill * 100).round();
    const pigW = 250.0;
    const scale = pigW / 200;

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 120 + pad.bottom),
      children: [
        Row(children: [
          const Expanded(
            child: Text('Ahorro', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ),
          Pressable(
            onTap: _editGoal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.flag_outlined, color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text(hasGoal ? 'Editar meta' : 'Definir meta', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              radius: 1.1,
              colors: [Color(0xFF3A3018), Color(0xFF1A1810), AppColors.surface],
            ),
            border: Border.all(color: const Color(0xFF4A3F22)),
          ),
          child: Column(children: [
            if (s.goalName.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(20)),
                child: Text(s.goalName,
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            SizedBox(
              width: pigW,
              height: pigW * 0.8,
              child: Stack(clipBehavior: Clip.none, children: [
                PiggyBank(fill: fill, width: pigW),
                Positioned(
                  left: 97 * scale - 15,
                  top: 0,
                  child: FallingCoin(trigger: _coin, slotY: 40 * scale - 30),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            AnimatedMoney(s.saved,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1, color: AppColors.gold)),
            const SizedBox(height: 4),
            Text(
              hasGoal ? '$pct% de tu meta de ${money(goal)}' : 'Próximo hito: ${money(goal)} · $pct%',
              style: const TextStyle(color: Color(0xFFD9CFB4), fontWeight: FontWeight.w600),
            ),
            if (hasGoal && s.saved < goal) ...[
              const SizedBox(height: 2),
              Text('Te faltan ${money(goal - s.saved)}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 3,
                child: GoldButton(label: 'Guardar', icon: Icons.savings_outlined, onTap: () => _move(deposit: true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Pressable(
                  onTap: () => s.saved > 0 ? _move(deposit: false) : toast(context, 'El chanchito está vacío'),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.north_east_rounded, color: AppColors.text, size: 18),
                      SizedBox(width: 6),
                      Text('Retirar', style: TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Row(children: [
            Expanded(child: _stat('Este mes', money(s.monthSaved, sign: true), s.monthSaved >= 0 ? AppColors.green : AppColors.red)),
            Expanded(child: _stat('Disponible para gastar', money(s.balance), AppColors.text)),
          ]),
        ),
        const SizedBox(height: 18),
        const SectionTitle('Movimientos del chanchito', icon: Icons.savings_outlined),
        if (_moves.isEmpty)
          const Panel(
            child: Text('Aún no guardas dinero. Toca "Guardar" o elige el módulo Ahorro al registrar un gasto.',
                style: TextStyle(color: AppColors.muted, height: 1.4)),
          )
        else
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(children: [
              for (final t in _moves) SwipeTx(key: ValueKey('sv${t.id}'), t: t, child: _MoveRow(t: t)),
            ]),
          ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color)),
        ],
      );
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.t});
  final Txn t;

  @override
  Widget build(BuildContext context) {
    final dep = t.isExpense;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (dep ? AppColors.gold : AppColors.muted).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(dep ? Icons.savings_outlined : Icons.north_east_rounded,
              color: dep ? AppColors.gold : AppColors.muted, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.note.isNotEmpty ? t.note : (dep ? 'Depósito' : 'Retiro'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${dayLabel(t.date)} · ${timeLabel(t.date)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
        Text(
          money(dep ? t.amount : -t.amount, sign: true),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: dep ? AppColors.gold : AppColors.text),
        ),
      ]),
    );
  }
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.deposit, required this.saved, required this.balance});
  final bool deposit;
  final int saved;
  final int balance;

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String? get _error {
    final a = parseMoney(_amount.text);
    if (a == null || a <= 0) return null;
    if (!widget.deposit && a > widget.saved) return 'Solo tienes ${money(widget.saved)} en el chanchito';
    return null;
  }

  bool get _valid {
    final a = parseMoney(_amount.text);
    return a != null && a > 0 && _error == null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final dep = widget.deposit;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dep ? 'Guardar en el chanchito' : 'Retirar del chanchito',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          dep ? 'Sale de tu saldo disponible (${money(widget.balance)}).' : 'Vuelve a tu saldo disponible.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [moneyFormatter],
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.gold),
          decoration: InputDecoration(hintText: '0,00', prefixText: '\$ ', errorText: _error),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: dep ? 'Nota (ej. vuelto del día)' : 'Motivo (opcional)'),
        ),
        const SizedBox(height: 18),
        GoldButton(
          label: dep ? 'Guardar' : 'Retirar',
          icon: dep ? Icons.savings_outlined : Icons.north_east_rounded,
          enabled: _valid,
          onTap: () => Navigator.pop(context, (parseMoney(_amount.text)!, _note.text.trim())),
        ),
      ]),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({this.goal, required this.name});
  final int? goal;
  final String name;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final _amount = TextEditingController(text: widget.goal != null ? moneyInput(widget.goal!) : '');
  late final _name = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final a = parseMoney(_amount.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Meta de ahorro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('El chanchito se llena a medida que te acercas a la meta.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: '¿Para qué ahorras? (ej. Laptop, viaje)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [moneyFormatter],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.gold),
          decoration: const InputDecoration(hintText: 'Monto de la meta', prefixText: '\$ '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 18),
        GoldButton(
          label: 'Guardar meta',
          icon: Icons.flag_outlined,
          enabled: a != null && a > 0,
          onTap: () => Navigator.pop(context, (a, _name.text)),
        ),
        if (widget.goal != null)
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, (null, '')),
              child: const Text('Quitar meta', style: TextStyle(color: AppColors.muted)),
            ),
          ),
      ]),
    );
  }
}
