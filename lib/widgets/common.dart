import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';

/// Tarjeta base con borde suave (estilo de la referencia).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap!, child: box);
  }
}

/// Escala al presionar: feedback táctil fluido y barato (solo transform).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.onLongPress, this.scale = 0.96});
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Monto que "cuenta" suavemente hasta su nuevo valor.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.cents, {super.key, this.style});
  final int cents;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: cents.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text(money(v.round()), style: style, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
    );
  }
}

/// Entrada escalonada (fade + slide) para listas.
class FadeIn extends StatelessWidget {
  const FadeIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ms = 260 + (index.clamp(0, 8) * 45);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

class CatBadge extends StatelessWidget {
  const CatBadge({super.key, required this.icon, required this.color, this.size = 42});
  final String icon;
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(iconFor(icon), color: c, size: size * 0.52),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction, this.icon});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: AppColors.gold),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.gold, visualDensity: VisualDensity.compact),
            child: Text(action!),
          ),
      ]),
    );
  }
}

/// Fila de movimiento reutilizada en inicio, historial y módulos.
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.t, required this.cat, this.onTap, this.showDate = false});
  final Txn t;
  final Category? cat;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final savings = cat?.isSavings ?? false;
    final income = !t.isExpense && !savings;
    final kindLabel = savings
        ? (t.isExpense ? 'Ahorro · depósito' : 'Ahorro · retiro')
        : (income ? 'Ingreso' : (cat?.name ?? 'Sin módulo'));
    final title = t.note.isNotEmpty ? t.note : (savings ? kindLabel : (income ? 'Ingreso' : (cat?.name ?? 'Gasto')));
    final sub = [
      kindLabel,
      showDate ? '${shortDate(t.date)} · ${timeLabel(t.date)}' : timeLabel(t.date),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Row(children: [
          income
              ? Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.south_west_rounded, color: AppColors.green, size: 22),
                )
              : CatBadge(icon: cat?.icon ?? 'other', color: cat?.color ?? 0xFF9A9483),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            money(t.signed, sign: true),
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: savings ? AppColors.gold : (income ? AppColors.green : AppColors.text)),
          ),
        ]),
      ),
    );
  }
}

/// Botón principal dorado tipo "AGREGAR GASTO +".
class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, required this.onTap, this.icon = Icons.add_rounded, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.4,
      duration: const Duration(milliseconds: 200),
      child: Pressable(
        onTap: enabled ? onTap : () {},
        child: Container(
          height: 56,
          padding: const EdgeInsets.only(left: 22, right: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldDeep]),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Expanded(
              child: Text(label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.gold),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Imagen del búho (assets/owl.png) con flotado suave.
class Owl extends StatefulWidget {
  const Owl({super.key, this.size = 110, this.float = true});
  final double size;
  final bool float;

  @override
  State<Owl> createState() => _OwlState();
}

class _OwlState extends State<Owl> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.float) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      'assets/owl.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      cacheWidth: (widget.size * 3).round(),
      filterQuality: FilterQuality.medium,
    );
    if (!widget.float) return img;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, -5 * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: img,
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String msg, {String ok = 'Eliminar', bool danger = true}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(msg, style: const TextStyle(color: AppColors.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.muted))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: danger ? AppColors.red : AppColors.gold, foregroundColor: Colors.black),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg, {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    duration: const Duration(seconds: 3),
    action: action == null ? null : SnackBarAction(label: action, onPressed: onAction ?? () {}),
  ));
}

/// Ruta con deslizamiento + fade, más suave que la default.
Route<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c), child: child),
        );
      },
    );
