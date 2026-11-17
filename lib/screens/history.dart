import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'category_detail.dart';

enum Period { today, week, month, lastMonth, all, custom }

const _periodLabels = {
  Period.today: 'Hoy',
  Period.week: '7 días',
  Period.month: 'Este mes',
  Period.lastMonth: 'Mes pasado',
  Period.all: 'Todo',
  Period.custom: 'Elegir fechas',
};

/// Historial con búsqueda por texto y filtros por fechas, módulo y tipo.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Period _period = Period.month;
  DateTimeRange? _custom;
  final Set<int> _cats = {};
  int? _type;
  final _search = TextEditingController();
  Timer? _debounce;

  List<DayGroup> _groups = [];
  int _spent = 0, _income = 0, _count = 0;
  bool _loading = true;
  AppState? _s;
  int _req = 0;

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
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  (DateTime?, DateTime?) _range() {
    final now = DateTime.now();
    final today = dateOnly(now);
    switch (_period) {
      case Period.today:
        return (today, today);
      case Period.week:
        return (today.subtract(const Duration(days: 6)), today);
      case Period.month:
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
      case Period.lastMonth:
        return (DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0));
      case Period.all:
        return (null, null);
      case Period.custom:
        return (_custom?.start, _custom?.end);
    }
  }

  Future<void> _load() async {
    final id = ++_req;
    final (from, to) = _range();
    final list = await _s!.queryTxns(TxFilter(from: from, to: to, categories: _cats, type: _type, text: _search.text));
    if (!mounted || id != _req) return;
    var sp = 0, inc = 0;
    for (final t in list) {
      if (t.isExpense) {
        sp += t.amount;
      } else {
        inc += t.amount;
      }
    }
    setState(() {
      _groups = AppState.groupByDay(list);
      _spent = sp;
      _income = inc;
      _count = list.length;
      _loading = false;
    });
  }

  Future<void> _setPeriod(Period p) async {
    HapticFeedback.selectionClick();
    if (p == Period.custom) {
      final now = DateTime.now();
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 1, 12, 31),
        initialDateRange: _custom ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
        helpText: 'Elige el rango de fechas',
        saveText: 'Aplicar',
      );
      if (r == null) return;
      _custom = r;
    }
    setState(() => _period = p);
    _load();
  }

  String _periodText() {
    if (_period == Period.custom && _custom != null) {
      return '${shortDate(_custom!.start)} – ${shortDate(_custom!.end)}';
    }
    return _periodLabels[_period]!;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 0),
          sliver: SliverList.list(children: [
            const Text('Historial', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '¿Qué día gasté en…? (ej. pizza, taxi)',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                          _load();
                        },
                      ),
              ),
              onChanged: (_) {
                setState(() {});
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 250), _load);
              },
            ),
            const SizedBox(height: 12),
          ]),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final p in Period.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p == Period.custom && _period == Period.custom ? _periodText() : _periodLabels[p]!),
                      avatar: p == Period.custom
                          ? Icon(Icons.date_range_rounded, size: 18, color: _period == p ? Colors.black : AppColors.gold)
                          : null,
                      selected: _period == p,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: _period == p ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
                      onSelected: (_) => _setPeriod(p),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _typeChip('Todo', null),
                _typeChip('Gastos', TxType.expense),
                _typeChip('Ingresos', TxType.income),
                Container(width: 1, margin: const EdgeInsets.fromLTRB(4, 8, 12, 8), color: AppColors.border),
                for (final c in s.catById.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(iconFor(c.icon), size: 16, color: _cats.contains(c.id) ? Colors.black : Color(c.color)),
                      label: Text(c.archived ? '${c.name} (archivado)' : c.name),
                      selected: _cats.contains(c.id),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                          color: _cats.contains(c.id) ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
                      onSelected: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => v ? _cats.add(c.id!) : _cats.remove(c.id));
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          sliver: SliverToBoxAdapter(child: _summary()),
        ),
        if (!_loading && _groups.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 30),
              child: Column(children: [
                Owl(size: 90),
                SizedBox(height: 12),
                Text('No hay movimientos con estos filtros', style: TextStyle(color: AppColors.muted)),
              ]),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + pad.bottom),
          sliver: SliverList.builder(
            itemCount: _groups.length,
            itemBuilder: (context, i) => FadeIn(index: i, child: DayCard(g: _groups[i], cats: s.catById)),
          ),
        ),
      ],
    );
  }

  Widget _typeChip(String label, int? type) {
    final sel = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        labelStyle: TextStyle(color: sel ? Colors.black : AppColors.text, fontWeight: FontWeight.w700),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => _type = type);
          _load();
        },
      ),
    );
  }

  Widget _summary() {
    Widget col(String label, int v, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedMoney(v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            ),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_periodText(), style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('$_count movimientos', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          col('Gastado', _spent, AppColors.text),
          col('Ingresado', _income, AppColors.green),
          col('Neto', _income - _spent, _income - _spent < 0 ? AppColors.red : AppColors.gold),
        ]),
      ]),
    );
  }
}
