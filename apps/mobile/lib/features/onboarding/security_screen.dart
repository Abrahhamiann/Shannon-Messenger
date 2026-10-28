import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/premium.dart';
import '../../app/widgets.dart';

class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ShannonAtmosphere(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                const ShannonReveal(
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 112,
                    color: Color(0xFF43CFFF),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Account created!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Shannon account is ready. Review how to keep access to it safe.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ShannonPrimaryButton(
                  onPressed: () => context.go('/onboarding/security'),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Secure your account')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const LinearProgressIndicator(value: .66, minHeight: 3),
        const SizedBox(height: 24),
        const Text(
          'Keep this device and its app data safe. Account recovery is not available in this build.',
        ),
        const SizedBox(height: 24),
        const ShannonPanel(
          child: FeatureRow(
            icon: Icons.key,
            title: 'Save a recovery key',
            subtitle: 'Unavailable · recovery protocol is not implemented',
          ),
        ),
        const SizedBox(height: 12),
        const ShannonPanel(
          child: FeatureRow(
            icon: Icons.description_outlined,
            title: 'Use a recovery phrase',
            subtitle: 'Unavailable · no recovery words have been generated',
          ),
        ),
        TextButton(
          onPressed: () => context.push('/onboarding/recovery-phrase'),
          child: const Text('About recovery phrases'),
        ),
        const SizedBox(height: 24),
        const ShannonPanel(
          child: FeatureRow(
            icon: Icons.lock_outline,
            title: 'Protect access on this device',
            subtitle: 'App Lock uses your fingerprint or device credential. It does not back up your account.',
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.push('/settings/app-lock'),
          child: const Text('Set up App Lock'),
        ),
        ShannonPrimaryButton(
          onPressed: () => context.go('/chats'),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

class RecoveryPhraseInfoScreen extends StatelessWidget {
  const RecoveryPhraseInfoScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ShannonReveal(
          child: Icon(
            Icons.admin_panel_settings_outlined,
            size: 100,
            color: Color(0xFF43CFFF),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your recovery phrase',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Not available yet. Shannon has not generated a phrase and cannot restore this account on another device.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const ShannonPanel(
          child: FeatureRow(
            icon: Icons.lock_outline,
            title: 'Keep secrets private',
            subtitle: 'Never enter another app’s recovery words into Shannon.',
          ),
        ),
        const SizedBox(height: 12),
        const ShannonPanel(
          child: FeatureRow(
            icon: Icons.phonelink_lock,
            title: 'Keep this installation',
            subtitle: 'Uninstalling or clearing app data can permanently lose your account.',
          ),
        ),
        const SizedBox(height: 12),
        const ShannonPanel(
          child: FeatureRow(
            icon: Icons.security,
            title: 'A protocol comes first',
            subtitle: 'A word list alone cannot authorize recovery. Security review and server integration are required.',
          ),
        ),
        const SizedBox(height: 24),
        ShannonPrimaryButton(
          onPressed: () => context.pop(),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}
