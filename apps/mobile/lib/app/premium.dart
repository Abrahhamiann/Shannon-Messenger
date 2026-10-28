import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_system.dart';

/// Static atmosphere avoids a continuously running GPU animation behind forms.
class ShannonAtmosphere extends StatelessWidget {
  const ShannonAtmosphere({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -.65),
        radius: 1.1,
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [Color(0xFF082C51), Color(0xFF030C17)]
            : const [Color(0xFFE0F4FF), Color(0xFFF6F8FB)],
      ),
    ),
    child: CustomPaint(
      painter: _AtmospherePainter(
        Theme.of(context).brightness == Brightness.dark,
      ),
      child: child,
    ),
  );
}

class _AtmospherePainter extends CustomPainter {
  _AtmospherePainter(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    if (!dark) return;
    final random = math.Random(12);
    final paint = Paint()
      ..color = const Color(0xFF43CFFF).withValues(alpha: .35);
    for (var i = 0; i < 38; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height * .56,
        ),
        i % 6 == 0 ? 1.4 : .6,
        paint,
      );
    }
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .81),
      width: size.width * 1.8,
      height: size.height * .52,
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF168DFF).withValues(alpha: .2);
    canvas.drawOval(oval, paint);
    for (var i = 1; i < 4; i++) {
      canvas.drawOval(
        oval.deflate(i * 8),
        paint..color = paint.color.withValues(alpha: .07),
      );
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      dark != oldDelegate.dark;
}

class ShannonPrimaryButton extends StatefulWidget {
  const ShannonPrimaryButton({
    required this.onPressed,
    required this.child,
    super.key,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  State<ShannonPrimaryButton> createState() => _ShannonPrimaryButtonState();
}

class _ShannonPrimaryButtonState extends State<ShannonPrimaryButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.onPressed == null
        ? null
        : (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale: pressed ? .98 : 1,
      duration: ShannonMotion.duration(context, ShannonMotion.quick),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: widget.onPressed == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF086CE5), Color(0xFF0054EF)],
                ),
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.onPressed == null
                ? null
                : Colors.transparent,
            shadowColor: Colors.transparent,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    ),
  );
}
