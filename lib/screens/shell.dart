import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'add_txn.dart';
import 'history.dart';
import 'home.dart';
import 'reminders.dart';
import 'savings.dart';
import 'stats.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _built = <int>{0};

  void go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _index = i;
      _built.add(i);
    });
  }

  Widget _page(int i) {
    if (!_built.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return HomeScreen(onNavigate: go);
      case 1:
        return const HistoryScreen();
      case 2:
        return const SavingsScreen();
      case 3:
        return const StatsScreen();
      default:
        return const RemindersScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) go(0);
      },
      child: Scaffold(
        extendBody: true,
        body: _TabFade(
          index: _index,
          // TickerMode pausa las animaciones de las pestañas ocultas (ahorra batería).
          child: IndexedStack(
            index: _index,
            children: List.generate(5, (i) => TickerMode(enabled: i == _index, child: _page(i))),
          ),
        ),
        bottomNavigationBar: _NavBar(index: _index, onTap: go),
      ),
    );
  }
}

/// Fade + leve desplazamiento al cambiar de pestaña sin perder el estado de cada una.
class _TabFade extends StatefulWidget {
  const _TabFade({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: 1);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _o = Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(_a);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _a, child: SlideTransition(position: _o, child: widget.child));
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _icons = [
    Icons.home_rounded,
    Icons.calendar_month_rounded,
    Icons.savings_rounded,
    Icons.insights_rounded,
    Icons.notifications_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.brown.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFF4A3F27)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 8))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_icons.length, (i) {
                  final sel = i == index;
                  return Pressable(
                    onTap: () => onTap(i),
                    scale: 0.9,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.gold : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icons[i], color: sel ? Colors.black : const Color(0xFFD8CDB0), size: 24),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(smoothRoute(const AddTxnScreen()));
            },
            scale: 0.88,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gold, AppColors.goldDeep],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF6B551E), width: 2),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.black, size: 32),
            ),
          ),
        ]),
      ),
    );
  }
}
