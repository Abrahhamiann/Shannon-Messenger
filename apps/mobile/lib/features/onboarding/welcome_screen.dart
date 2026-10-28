import '../../l10n/strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/widgets.dart';
import '../../app/premium.dart';
import '../identity/presentation/identity_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(identityControllerProvider);
    if (state.isLoading) {
      return Scaffold(
        body: Center(child: ShannonReveal(child: ShannonMark(size: 180))),
      );
    }
    return Scaffold(
      body: ShannonAtmosphere(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: EdgeInsets.all(28),
                children: [
                  SizedBox(height: 24),
                  ShannonReveal(
                    child: Column(
                      children: [
                        ShannonMark(size: 220),
                        SizedBox(height: 24),
                        Text(
                          'Shannon',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          strings(context).tagline,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    runSpacing: 20,
                    spacing: 8,
                    children: [
                      for (final feature in [
                        (Icons.shield_outlined, 0),
                        (Icons.people_outline, 1),
                        (Icons.phone_disabled_outlined, 2),
                      ])
                        SizedBox(
                          width: 100,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .12),
                                child: Icon(
                                  feature.$1,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                strings(context).privacyFeatures
                                    .split('\n')[feature.$2],
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 24),
                  ShannonPrimaryButton(
                    onPressed: () => context.go('/signup'),
                    child: Text(strings(context).signUp),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/account'),
                    child: Text(strings(context).existingAccount),
                  ),
                  SizedBox(height: 24),
                  Text(
                    strings(context).earlyAccess,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
