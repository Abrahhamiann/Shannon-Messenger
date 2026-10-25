import 'package:flutter/material.dart';

/// Shared measurements for new Shannon screens; no device-size assumptions.
abstract final class ShannonSpace {
  static const double small = 8, medium = 16, large = 24, section = 32;
  static const double page = 20, control = 48, cardRadius = 20;
}

abstract final class ShannonMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const entrance = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

/// One short entrance, never an ambient loop. Reduced motion stays static.
class ShannonReveal extends StatelessWidget {
  const ShannonReveal({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ShannonMotion.entrance,
      curve: ShannonMotion.curve,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class ShannonPanel extends StatelessWidget {
  const ShannonPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(ShannonSpace.cardRadius),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
