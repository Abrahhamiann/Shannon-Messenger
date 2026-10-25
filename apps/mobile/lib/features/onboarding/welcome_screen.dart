import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/widgets.dart';
import '../identity/presentation/identity_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider).asData?.value;
    final hasIdentity = identity?.id != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              children: [
                const ShannonReveal(
                  child: Column(
                    children: [
                      ShannonMark(size: 112),
                      SizedBox(height: 20),
                      Text(
                        'Shannon',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.9,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'A little more private.',
                        style: TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  hasIdentity ? 'Welcome back.' : 'Your identity.\nYour space.',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'Start with an identity that belongs to you.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const ShannonPanel(
                  child: Column(
                    children: [
                      FeatureRow(
                        icon: ShannonIconsRegular.userCircle,
                        title: 'No phone number. No email.',
                        subtitle: 'Choose a nickname, or leave it blank.',
                      ),
                      FeatureRow(
                        icon: ShannonIconsRegular.lockKey,
                        title: 'Created on your device',
                        subtitle: 'Your private identity keys stay here.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.push('/identity'),
                  child: Text(
                    hasIdentity
                        ? 'Open my identity'
                        : 'Create Private Identity',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/chats'),
                  child: const Text('Open Shannon'),
                ),
                TextButton(
                  onPressed: () => context.push('/identity/restore'),
                  child: const Text('Restore Identity'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Early access · Messaging and calls are not available yet. Recovery is not supported; keep this installation and its data.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/connection'),
                  child: const Text('Check backend connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
