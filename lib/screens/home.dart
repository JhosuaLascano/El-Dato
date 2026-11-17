import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'add_txn.dart';
import 'categories.dart';
import 'category_detail.dart';
import 'reminders.dart';
import 'settings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '¡Buenos días!';
    if (h < 19) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  IconData _greetingIcon() {
    final h = DateTime.now().hour;
    if (h < 6 || h >= 19) return Icons.dark_mode_outlined;
    if (h < 17) return Icons.wb_sunny_outlined;
    return Icons.wb_twilight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pad = MediaQuery.paddingOf(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, 0),
          sliver: SliverList.list(children: [
            _header(context),
            const SizedBox(height: 14),
            FadeIn(index: 0, child: _statsBar(s)),
            const SizedBox(height: 14),
            FadeIn(index: 1, child: _hero(context, s)),
            const SizedBox(height: 14),
            FadeIn(index: 2, child: _monthCard(s)),
            const SizedBox(height: 18),
            SectionTitle('Módulos', icon: Icons.grid_view_rounded, action: 'Editar', onAction: () {
              Navigator.of(context).push(smoothRoute(const CategoriesScreen()));
            }),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
            itemCount: s.categories.length + 1,
            itemBuilder: (context, i) {
              if (i == s.categories.length) return FadeIn(index: i, child: const _NewModuleTile());
              final c = s.categories[i];
              if (c.isSavings) {
                return FadeIn(
                  index: i,
                  child: _ModuleTile(
                    cat: c,
                    spent: s.saved,
                    pct: s.effectiveGoal == 0 ? 0 : (s.saved / s.effectiveGoal).clamp(0.0, 1.0),
                    caption: 'en el chanchito',
                    onTap: () => onNavigate(2),
                  ),
                );
              }
              final spent = s.monthByCat[c.id] ?? 0;
              return FadeIn(
                index: i,
                child: _ModuleTile(cat: c, spent: spent, pct: s.monthSpent == 0 ? 0 : spent / s.monthSpent),
              );
            },
          ),
        ),
        if (s.pending.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            sliver: SliverList.list(children: [
              SectionTitle('Próximos recordatorios', icon: Icons.notifications_active_rounded, action: 'Ver todo', onAction: () => onNavigate(4)),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(children: [for (final r in s.pending.take(3)) ReminderTile(r: r, compact: true)]),
              ),
            ]),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          sliver: SliverToBoxAdapter(
            child: SectionTitle('Hoy', icon: Icons.today_rounded, action: 'Historial', onAction: () => onNavigate(1)),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + pad.bottom),
          sliver: SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: s.today.isEmpty ? _emptyToday() : _todayList(context, s),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    return Row(children: [
      const Owl(size: 34, float: false),
      const SizedBox(width: 8),
      const Text('EL ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text, letterSpacing: -0.5)),
      const Text('DATO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.gold, letterSpacing: -0.5)),
      const Spacer(),
      Pressable(
        onTap: () => Navigator.of(context).push(smoothRoute(const SettingsScreen())),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.tune_rounded, color: AppColors.text, size: 20),
        ),
      ),
    ]);
  }

  Widget _statsBar(AppState s) {
    Widget item(IconData icon, String value, String label) => Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: AppColors.gold),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ]),
          ]),
        );
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(children: [
        item(Icons.local_fire_department_outlined, '${s.streak}', s.streak == 1 ? 'día seguido' : 'días seguidos'),
        item(Icons.eco_outlined, '${s.noSpendDays}', 'días sin gastos'),
        item(Icons.notifications_none_rounded, '${s.pending.length}', 'pendientes'),
      ]),
    );
  }

  Widget _hero(BuildContext context, AppState s) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A3C17), Color(0xFF241E10), Color(0xFF17150E)],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: const Color(0xFF5C4B1F)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const Owl(size: 104),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_greetingIcon(), size: 14, color: AppColors.gold),
                  const SizedBox(width: 5),
                  Text(_greeting(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 10),
              const Text('Saldo disponible', style: TextStyle(color: Color(0xFFD9CFB4), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedMoney(
                  s.balance,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: s.balance < 0 ? AppColors.red : AppColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: Color(0xFFD9CFB4)), children: [
                const TextSpan(text: 'Hoy  '),
                TextSpan(text: money(-s.todaySpent), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                const TextSpan(text: '   '),
                TextSpan(text: money(s.todayIncome, sign: true), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.green)),
              ])),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GoldButton(
              label: 'Agregar gasto',
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(smoothRoute(const AddTxnScreen()));
              },
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            onTap: () => Navigator.of(context).push(smoothRoute(const AddTxnScreen(initialType: TxType.income))),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.5)),
              ),
              child: const Row(children: [
                Icon(Icons.south_west_rounded, color: AppColors.green, size: 20),
                SizedBox(width: 6),
                Text('Ingreso', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _monthCard(AppState s) {
    final now = DateTime.now();
    final base = s.monthIncome > 0 ? s.monthIncome : (s.monthSpent + (s.balance > 0 ? s.balance : 0));
    final pct = base <= 0 ? 0.0 : (s.monthSpent / base).clamp(0.0, 1.0);
    final daysLeft = DateTime(now.year, now.month + 1, 0).day - now.day;
    String compare;
    Color cColor = AppColors.muted;
    if (s.lastMonthSpentToDate == 0) {
      compare = 'Sin datos del mes pasado para comparar';
    } else {
      final d = (s.monthSpent - s.lastMonthSpentToDate) / s.lastMonthSpentToDate * 100;
      compare = d >= 0
          ? '▲ ${d.toStringAsFixed(0)}% más que el mes pasado a esta fecha'
          : '▼ ${(-d).toStringAsFixed(0)}% menos que el mes pasado a esta fecha';
      cColor = d > 0 ? AppColors.red : AppColors.green;
    }
    return Panel(
      onTap: () => onNavigate(3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
            child: const Icon(Icons.attach_money_rounded, color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(monthLabel(now.year, now.month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
        const SizedBox(height: 14),
        Text.rich(TextSpan(children: [
          TextSpan(text: money(s.monthSpent), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const TextSpan(text: '  gastado', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          if (s.monthIncome > 0) TextSpan(text: ' de ${money(s.monthIncome)} recibidos', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ])),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(v > 0.85 ? AppColors.red : AppColors.gold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(compare, style: TextStyle(color: cColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('$daysLeft días restantes en el mes', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _emptyToday() {
    return const Panel(
      child: Row(children: [
        Owl(size: 56, float: false),
        SizedBox(width: 12),
        Expanded(
          child: Text('Aún no registras movimientos hoy.\nToca + para agregar tu primer gasto.',
              style: TextStyle(color: AppColors.muted, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _todayList(BuildContext context, AppState s) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(children: [
        for (var i = 0; i < s.today.length; i++)
          SwipeTx(
            key: ValueKey('tx${s.today[i].id}'),
            t: s.today[i],
            child: TxTile(
              t: s.today[i],
              cat: s.catById[s.today[i].categoryId],
              onTap: () => Navigator.of(context).push(smoothRoute(AddTxnScreen(editing: s.today[i]))),
            ),
          ),
      ]),
    );
  }
}

/// Deslizar para eliminar con opción de deshacer.
class SwipeTx extends StatelessWidget {
  const SwipeTx({super.key, required this.t, required this.child});
  final Txn t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('d${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: AppColors.red),
      ),
      onDismissed: (_) {
        final s = AppScope.read(context);
        final messenger = ScaffoldMessenger.of(context);
        HapticFeedback.mediumImpact();
        s.deleteTxn(t);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text('Movimiento eliminado (${money(t.amount)})'),
          action: SnackBarAction(label: 'Deshacer', onPressed: () => s.restoreTxn(t)),
        ));
      },
      child: child,
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.cat, required this.spent, required this.pct, this.caption, this.onTap});
  final Category cat;
  final int spent;
  final double pct;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Color(cat.color);
    return Pressable(
      onTap: onTap ?? () => Navigator.of(context).push(smoothRoute(CategoryDetailScreen(categoryId: cat.id!))),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showCategoryEditor(context, cat);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CatBadge(icon: cat.icon, color: cat.color, size: 36),
            const Spacer(),
            Text('${(pct * 100).round()}%', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const Spacer(),
          Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(caption == null ? money(spent) : '${money(spent)} $caption',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: pct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NewModuleTile extends StatelessWidget {
  const _NewModuleTile();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => showCategoryEditor(context, null),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 1.2),
          color: AppColors.goldSoft.withValues(alpha: 0.06),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_circle_outline_rounded, color: AppColors.gold, size: 30),
          SizedBox(height: 6),
          Text('Nuevo módulo', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
