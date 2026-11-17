import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'add_txn.dart';
import 'categories.dart';
import 'home.dart';

class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});
  final int categoryId;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<DayGroup> _groups = [];
  int _lastMonth = 0;
  int _count = 0;
  bool _loaded = false;
  AppState? _s;

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
    final list = await s.queryTxns(TxFilter(categories: {widget.categoryId}), limit: 1000);
    final now = DateTime.now();
    final lm = await s.categorySpent(DateTime(now.year, now.month - 1, 1), DateTime(now.year, now.month, 0));
    if (!mounted) return;
    setState(() {
      _groups = AppState.groupByDay(list);
      _count = list.length;
      _lastMonth = lm[widget.categoryId] ?? 0;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cat = s.catById[widget.categoryId];
    if (cat == null) return const Scaffold();
    final month = s.monthByCat[cat.id] ?? 0;
    final c = Color(cat.color);
    return Scaffold(
      appBar: AppBar(
        title: Text(cat.name),
        actions: [
          IconButton(onPressed: () => showCategoryEditor(context, cat), icon: const Icon(Icons.edit_rounded)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [c.withValues(alpha: 0.28), AppColors.surface],
                        ),
                        border: Border.all(color: c.withValues(alpha: 0.35)),
                      ),
                      child: Row(children: [
                        CatBadge(icon: cat.icon, color: cat.color, size: 60),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Este mes', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                            AnimatedMoney(month, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text('Mes pasado: ${money(_lastMonth)} · $_count registros',
                                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
                if (_loaded && _groups.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Owl(size: 90),
                        SizedBox(height: 12),
                        Text('Sin gastos en este módulo todavía', style: TextStyle(color: AppColors.muted)),
                      ]),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, i) => FadeIn(index: i, child: DayCard(g: _groups[i], cats: s.catById)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GoldButton(
              label: 'Agregar en ${cat.name}',
              onTap: () => Navigator.of(context).push(smoothRoute(AddTxnScreen(categoryId: cat.id))),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Tarjeta de un día: encabezado con totales y sus movimientos.
class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.g, required this.cats});
  final DayGroup g;
  final Map<int, Category> cats;

  @override
  Widget build(BuildContext context) {
    final d = fromKey(g.day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              Expanded(
                child: Text(dayLabel(d),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              if (g.spent > 0)
                Text(money(-g.spent), style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
              if (g.income > 0) ...[
                const SizedBox(width: 10),
                Text(money(g.income, sign: true), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ]),
          ),
          const SizedBox(height: 4),
          const Divider(),
          for (final t in g.items)
            SwipeTx(
              key: ValueKey('h${t.id}'),
              t: t,
              child: TxTile(
                t: t,
                cat: cats[t.categoryId],
                onTap: () => Navigator.of(context).push(smoothRoute(AddTxnScreen(editing: t))),
              ),
            ),
        ]),
      ),
    );
  }
}
