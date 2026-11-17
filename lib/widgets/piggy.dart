import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Chanchito de ahorro que se llena de "oro líquido" según [fill] (0..1).
/// El nivel se anima al cambiar y la superficie ondula suavemente.
class PiggyBank extends StatefulWidget {
  const PiggyBank({super.key, required this.fill, this.width = 240});
  final double fill;
  final double width;

  @override
  State<PiggyBank> createState() => _PiggyBankState();
}

class _PiggyBankState extends State<PiggyBank> with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.width * 0.8;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.fill.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (_, level, _) => CustomPaint(
          size: Size(widget.width, h),
          painter: _PigPainter(level: level, wave: _wave),
        ),
      ),
    );
  }
}

class _PigPainter extends CustomPainter {
  _PigPainter({required this.level, required this.wave}) : super(repaint: wave);
  final double level;
  final Animation<double> wave;

  // Diseño en un lienzo de 200 x 160.
  static Path _shape() {
    Path p = Path()..addOval(Rect.fromCenter(center: const Offset(98, 90), width: 148, height: 112));
    Path add(Path other) => Path.combine(PathOperation.union, p, other);
    // Hocico
    p = add(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(156, 74, 32, 34), const Radius.circular(13))));
    // Oreja
    p = add(Path()
      ..moveTo(112, 44)
      ..quadraticBezierTo(126, 10, 146, 20)
      ..quadraticBezierTo(150, 40, 140, 52)
      ..close());
    // Patas
    p = add(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 128, 24, 26), const Radius.circular(8))));
    p = add(Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(118, 128, 24, 26), const Radius.circular(8))));
    return p;
  }

  static final Path _pig = _shape();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 200, size.height / 160);
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 160 * s) / 2);
    canvas.scale(s);

    // Sombra
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(98, 156), width: 130, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Cola rizada
    final tail = Path()
      ..moveTo(26, 86)
      ..cubicTo(8, 82, 10, 62, 22, 66)
      ..cubicTo(32, 70, 22, 84, 12, 76);
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold,
    );

    // Cuerpo vacío
    canvas.drawPath(_pig, Paint()..color = const Color(0xFF221F14));

    // Líquido dorado recortado a la silueta
    if (level > 0) {
      canvas.save();
      canvas.clipPath(_pig);
      const top = 18.0, bottom = 156.0;
      final y = bottom - (bottom - top) * level;
      final phase = wave.value * 2 * math.pi;
      final amp = level >= 0.999 ? 0.0 : 3.5;

      Path waveAt(double shift, double a) {
        final w = Path()..moveTo(0, bottom + 2);
        for (double x = 0; x <= 200; x += 5) {
          w.lineTo(x, y + math.sin(x / 200 * 3 * math.pi + phase + shift) * a);
        }
        return w
          ..lineTo(200, bottom + 2)
          ..close();
      }

      canvas.drawPath(waveAt(math.pi, amp * 0.8), Paint()..color = AppColors.goldDeep.withValues(alpha: 0.55));
      canvas.drawPath(
        waveAt(0, amp),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD866), AppColors.gold, AppColors.goldDeep],
          ).createShader(Rect.fromLTRB(0, y, 200, bottom)),
      );
      // Brillo
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(70, 70), width: 30, height: 16),
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
      canvas.restore();
    }

    // Contorno
    canvas.drawPath(
      _pig,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.gold,
    );

    const ink = Color(0xFF14130D);
    // Ranura para monedas
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(80, 37, 34, 7), const Radius.circular(4)),
      Paint()..color = ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(80, 37, 34, 7), const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.gold,
    );
    // Ojo
    canvas.drawCircle(const Offset(146, 72), 6, Paint()..color = ink);
    canvas.drawCircle(const Offset(148, 70), 2, Paint()..color = Colors.white);
    // Fosas nasales
    canvas.drawOval(Rect.fromCenter(center: const Offset(168, 91), width: 6, height: 10), Paint()..color = ink);
    canvas.drawOval(Rect.fromCenter(center: const Offset(178, 91), width: 6, height: 10), Paint()..color = ink);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PigPainter old) => old.level != level;
}

/// Moneda que cae dentro de la ranura (se dispara con [trigger]).
class FallingCoin extends StatefulWidget {
  const FallingCoin({super.key, required this.trigger, required this.slotY});
  final int trigger;
  final double slotY;

  @override
  State<FallingCoin> createState() => _FallingCoinState();
}

class _FallingCoinState extends State<FallingCoin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void didUpdateWidget(FallingCoin old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        if (!_c.isAnimating) return const SizedBox.shrink();
        final t = Curves.easeIn.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -60 + (widget.slotY + 60) * t),
          child: Opacity(
            opacity: t > 0.85 ? (1 - t) / 0.15 : 1,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(t * math.pi * 3),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFE08A), AppColors.goldDeep]),
                  border: Border.all(color: const Color(0xFFB8860B), width: 2),
                ),
                child: const Icon(Icons.attach_money_rounded, size: 18, color: Color(0xFF6B4E00)),
              ),
            ),
          ),
        );
      },
    );
  }
}
