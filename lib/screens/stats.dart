import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/segmented.dart';

enum StatRange { week, month, sixMonths }

/// Comparación de gastos: semana vs semana anterior, mes vs mes anterior,
/// y tendencia de 6 meses.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatRange _range = StatRange.month;
  AppState? _s;
  bool _loaded = false;

  // Datos calculados
  List<double> _bars = [];
  List<double> _bars2 = [];
  List<String> _barLabels = [];
  int _total = 0;
  int _prevTotal = 0;
  int _days = 1;
  Map<int, int> _cats = {};
  Map<int, int> _prevCats = {};
  List<Txn> _top = [];

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
    final s = _s!;
    final now = DateTime.now();
    final today = dateOnly(now);
    late DateTime from, to, pFrom, pTo;
    final bars = <double>[], bars2 = <double>[], labels = <String>[];

    switch (_range) {
      case StatRange.week:
        from = today.subtract(const Duration(days: 6));
        to = today;
        pFrom = from.subtract(const Duration(days: 7));
        pTo = from.subtract(const Duration(days: 1));
        final d = await s.dailySpent(from, to);
        for (var i = 0; i < 7; i++) {
          final day = from.add(Duration(days: i));
          bars.add((d[dayKey(day)] ?? 0) / 100);
          labels.add(cap(DateFormat('E', 'es').format(day)).substring(0, 2));
        }
        _days = 7;
      case StatRange.month:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        pFrom = DateTime(now.year, now.month - 1, 1);
        // Comparación justa: mes pasado hasta el mismo día.
        final pLast = DateTime(now.year, now.month, 0).day;
        pTo = DateTime(now.year, now.month - 1, now.day > pLast ? pLast : now.day);
        final d = await s.dailySpent(from, to);
        for (var i = 1; i <= to.day; i++) {
          bars.add((d[now.year * 10000 + now.month * 100 + i] ?? 0) / 100);
          labels.add(i == 1 || i % 5 == 0 ? '$i' : '');
        }
        _days = now.day;
      case StatRange.sixMonths:
        from = DateTime(now.year, now.month - 5, 1);
        to = today;
        pFrom = DateTime(now.year, now.month - 11, 1);
        pTo = DateTime(now.year, now.month - 5, 0);
        final m = await s.monthlyTotals(6);
        for (var i = 5; i >= 0; i--) {
          final dt = DateTime(now.year, now.month - i, 1);
          final v = m[dt.year * 100 + dt.month];
          bars.add((v?[0] ?? 0) / 100);
          bars2.add((v?[1] ?? 0) / 100);
          labels.add(cap(DateFormat('MMM', 'es').format(dt)).replaceAll('.', ''));
        }
        _days = today.difference(from).inDays + 1;
    }

    final results = await Future.wait([
      s.categorySpent(from, to),
      s.categorySpent(pFrom, pTo),
      s.topExpenses(from, to),
    ]);
    if (!mounted) return;
    final cats = results[0] as Map<int, int>;
    final prev = results[1] as Map<int, int>;
    setState(() {
      _bars = bars;
      _bars2 = bars2;
      _barLabels = labels;
      _cats = cats;
      _prevCats = prev;
      _total = cats.values.fold(0, (a, b) => a + b);
      _prevTotal = prev.values.fold(0, (a, b) => a + b);
      _top = results[2] as List<Txn>;
      _loaded = true;
    });
  }

  String get _prevLabel => switch (_range) {
        StatRange.week => 'vs. 7 días anteriores',
        StatRange.month => 'vs. mes pasado (a la misma fecha)',
        StatRange.sixMonths => 'vs. 6 meses anteriores',
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, pad.top + 12, 16, 120 + pad.bottom),
      children: [
        const Text('Comparar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Segmented<StatRange>(
          values: StatRange.values,
          labels: const ['Semana', 'Mes', '6 meses'],
          value: _range,
          onChanged: (v) {
            setState(() => _range = v);
            _load();
          },
        ),
        const SizedBox(height: 14),
        if (_loaded) ...[
          _summary(),
          const SizedBox(height: 14),
          _chart(),
          const SizedBox(height: 18),
          const SectionTitle('Por módulo', icon: Icons.donut_small_rounded),
          _categories(s),
          if (_top.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionTitle('Gastos más grandes', icon: Icons.local_fire_department_rounded),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(children: [for (final t in _top) TxTile(t: t, cat: s.catById[t.categoryId], showDate: true)]),
            ),
          ],
        ],
      ],
    );
  }

  Widget _summary() {
    final diff = _total - _prevTotal;
    final pct = _prevTotal == 0 ? null : diff / _prevTotal * 100;
    final up = diff > 0;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Total gastado', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        AnimatedMoney(_total, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        Row(children: [
          if (pct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (up ? AppColors.red : AppColors.green).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${up ? '▲' : '▼'} ${pct.abs().toStringAsFixed(0)}%',
                  style: TextStyle(color: up ? AppColors.red : AppColors.green, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          if (pct != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              pct == null ? 'Sin datos del periodo anterior' : '$_prevLabel (${money(_prevTotal)})',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _mini('Promedio diario', money((_total / (_days == 0 ? 1 : _days)).round()))),
          Expanded(child: _mini('Diferencia', money(diff, sign: true), color: up ? AppColors.red : AppColors.green)),
        ]),
      ]),
    );
  }

  Widget _mini(String label, String value, {Color color = AppColors.text}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        ],
      );

  Widget _chart() {
    final maxY = [..._bars, ..._bars2, 1.0].reduce((a, b) => a > b ? a : b) * 1.18;
    final six = _range == StatRange.sixMonths;
    final width = six ? 12.0 : (_bars.length > 10 ? 6.0 : 18.0);
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 16, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (six)
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Row(children: [
              _Dot(AppColors.gold),
              Text(' Gastos   ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              _Dot(AppColors.green),
              Text(' Ingresos', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY / 4,
                    getTitlesWidget: (v, meta) => v == 0 || v >= maxY * 0.99
                        ? const SizedBox.shrink()
                        : Text(NumberFormat.compact(locale: 'es').format(v),
                            style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= _barLabels.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_barLabels[i], style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface2,
                  tooltipBorderRadius: BorderRadius.circular(10),
                  getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                    money((rod.toY * 100).round()),
                    TextStyle(color: rod.color, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
              barGroups: List.generate(_bars.length, (i) {
                final isToday = _range == StatRange.month && i == DateTime.now().day - 1 ||
                    _range == StatRange.week && i == 6;
                return BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: _bars[i],
                      width: width,
                      color: isToday ? AppColors.gold : AppColors.gold.withValues(alpha: six ? 1 : 0.65),
                      borderRadius: BorderRadius.circular(width / 2),
                      backDrawRodData: BackgroundBarChartRodData(show: !six, toY: maxY, color: AppColors.surface2),
                    ),
                    if (six) BarChartRodData(toY: _bars2[i], width: width, color: AppColors.green, borderRadius: BorderRadius.circular(width / 2)),
                  ],
                );
              }),
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          ),
        ),
      ]),
    );
  }

  Widget _categories(AppState s) {
    if (_cats.isEmpty) {
      return const Panel(child: Text('Sin gastos en este periodo.', style: TextStyle(color: AppColors.muted)));
    }
    final entries = _cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(children: [
        for (final e in entries) _catRow(s.catById[e.key], e.value, _prevCats[e.key] ?? 0),
      ]),
    );
  }

  Widget _catRow(Category? c, int v, int prev) {
    final pct = _total == 0 ? 0.0 : v / _total;
    final color = Color(c?.color ?? 0xFF9A9483);
    String delta;
    Color dc;
    if (prev == 0) {
      delta = 'nuevo';
      dc = AppColors.muted;
    } else {
      final d = (v - prev) / prev * 100;
      delta = '${d >= 0 ? '▲' : '▼'} ${d.abs().toStringAsFixed(0)}%';
      dc = d > 0 ? AppColors.red : AppColors.green;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        CatBadge(icon: c?.icon ?? 'other', color: c?.color ?? 0xFF9A9483, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(c?.name ?? 'Sin módulo',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(money(v), style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, x, _) => LinearProgressIndicator(
                      value: x,
                      minHeight: 6,
                      backgroundColor: AppColors.surface2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: Text(delta, textAlign: TextAlign.right, style: TextStyle(color: dc, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
