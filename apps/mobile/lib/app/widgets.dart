import 'package:flutter/material.dart';

import 'design_system.dart';

class ShannonMark extends StatelessWidget {
  const ShannonMark({this.size = 96, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Shannon',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/branding/shannon_ribbon.png',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {this.trailing, super.key});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class FeatureRow extends StatelessWidget {
  const FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(
      subtitle,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
    ),
    trailing: trailing,
    onTap: onTap,
  );
}

class FeatureNotice extends StatelessWidget {
  const FeatureNotice({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => ShannonReveal(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.65,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}
