import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/identity_repository.dart';
import 'identity_controller.dart';
import '../../../app/design_system.dart';
import '../../../app/icons.dart';
import '../../../app/widgets.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});
  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen>
    with WidgetsBindingObserver {
  final nickname = TextEditingController();
  bool acknowledged = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(identityControllerProvider.notifier).run((r) => r.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityControllerProvider);
    final controller = ref.read(identityControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Private identity')),
      body: state.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Finishing your request…'),
            ],
          ),
        ),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(identityControllerProvider),
            child: const Text('Retry secure storage'),
          ),
        ),
        data: (view) => ListView(
          padding: const EdgeInsets.all(ShannonSpace.page),
          children: [
            ShannonReveal(
              child: FeatureNotice(
                icon: view.stage == IdentityStage.authenticated
                    ? ShannonIconsRegular.checkCircle
                    : ShannonIconsRegular.key,
                title: view.stage == IdentityStage.none
                    ? 'Make yourself at home.'
                    : view.stage == IdentityStage.authenticated
                    ? 'You’re connected.'
                    : 'An identity that’s yours.',
                message: view.stage == IdentityStage.none
                    ? 'Choose a name. No phone number or email needed.'
                    : 'Your private keys stay on this device. Only proof of ownership is shared.',
              ),
            ),
            const SizedBox(height: 20),
            if (view.message != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(view.message!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (view.stage == IdentityStage.none) ...[
              const ShannonPanel(
                child: FeatureRow(
                  icon: ShannonIconsRegular.shieldWarning,
                  title: 'Keep this installation safe',
                  subtitle: 'Recovery is not available. Uninstalling, clearing app data or losing access to this device can permanently lose your identity.',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nickname,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  helperText: 'Optional · stored only on this device',
                  filled: true,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) =>
                    setState(() => acknowledged = value ?? false),
                title: const Text(
                  'I understand that this identity cannot be recovered yet.',
                ),
              ),
              FilledButton(
                onPressed: acknowledged
                    ? () => controller.run((r) => r.create(nickname.text))
                    : null,
                child: const Text('Generate local identity'),
              ),
            ] else if (view.id != null) ...[
              Text(
                switch (view.stage) {
                  IdentityStage.authenticated => 'Authenticated with Shannon',
                  IdentityStage.revoked => 'This device is revoked',
                  IdentityStage.expired => 'Authentication expired',
                  IdentityStage.offline =>
                    'Local identity · connection unavailable',
                  _ => 'Identity saved on this device',
                },
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (view.nickname.isNotEmpty) Text(view.nickname),
              const SizedBox(height: 16),
              const Text('Public Shannon identifier'),
              SelectableText(view.id!),
              TextButton.icon(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: view.id!)),
                icon: const Icon(Icons.copy),
                label: const Text('Copy public identifier'),
              ),
              const Text(
                'This public identifier contains no private keys. It is not yet an invitation or device-link QR code.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile'),
                icon: const Icon(ShannonIconsRegular.userCircle),
                label: const Text('Choose a photo & edit profile'),
              ),
              const SizedBox(height: 12),
              if (view.stage != IdentityStage.revoked)
                FilledButton(
                  onPressed: () => controller.run((r) => r.connect()),
                  child: Text(
                    view.stage == IdentityStage.authenticated
                        ? 'Renew signed session'
                        : 'Connect and authenticate',
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => controller.run((r) => r.resume()),
                child: const Text('Check session'),
              ),
              if (view.stage == IdentityStage.authenticated) ...[
                OutlinedButton(
                  onPressed: () => context.push('/identity/devices'),
                  child: const Text('View registered devices'),
                ),
                TextButton(
                  onPressed: () => controller.run((r) => r.logout()),
                  child: const Text('Sign out and revoke session'),
                ),
              ],
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.push('/identity/restore'),
              child: const Text('Restore Identity'),
            ),
            TextButton(
              onPressed: () => context.go('/chats'),
              child: const Text('Open Shannon'),
            ),
          ],
        ),
      ),
    );
  }
}

class RestoreIdentityScreen extends StatelessWidget {
  const RestoreIdentityScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restore Identity')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        FeatureNotice(
          icon: ShannonIconsRegular.key,
          title: 'Recovery is not available yet',
          message: 'Your identity currently lives on this device. Keep this installation and its data safe.',
        ),
        ShannonPanel(
          child: Column(
            children: [
              FeatureRow(
                icon: ShannonIconsRegular.shieldWarning,
                title: 'Loss can be permanent',
                subtitle: 'Uninstalling, clearing app data or losing device access can lose your identity. There is no recovery phrase in this build.',
              ),
              Divider(height: 1),
              FeatureRow(
                icon: ShannonIconsRegular.lockKey,
                title: 'Keep your other secrets private',
                subtitle: 'Never enter a wallet phrase or another app’s recovery words into Shannon.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class IdentityDevicesScreen extends ConsumerStatefulWidget {
  const IdentityDevicesScreen({super.key});
  @override
  ConsumerState<IdentityDevicesScreen> createState() =>
      _IdentityDevicesScreenState();
}

class _IdentityDevicesScreenState extends ConsumerState<IdentityDevicesScreen> {
  late Future<List<DeviceView>> pending;
  @override
  void initState() {
    super.initState();
    pending = ref.read(identityRepositoryProvider).devices();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Registered devices')),
    body: FutureBuilder<List<DeviceView>>(
      future: pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => pending = ref.read(identityRepositoryProvider).devices(),
              ),
              child: const Text('Unable to load devices. Retry'),
            ),
          );
        }
        final own = ref
            .watch(identityControllerProvider)
            .asData
            ?.value
            .deviceId;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Linking another device is not available until its authorization protocol is reviewed.',
            ),
            const SizedBox(height: 16),
            for (final device in snapshot.data!)
              Card(
                child: ListTile(
                  title: Text(
                    device.id == own ? 'This device' : 'Registered device',
                  ),
                  subtitle: Text(
                    '${device.id}\n${device.revoked ? "Revoked" : "Active"}',
                  ),
                  trailing: device.id == own && !device.revoked
                      ? IconButton(
                          icon: const Icon(Icons.block),
                          tooltip: 'Revoke this device',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text(
                                  'Permanently revoke this device?',
                                ),
                                content: const Text(
                                  'This ends every session. With no recovery or linked device, account access will be lost. This cannot be undone in M3.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Revoke'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              await ref
                                  .read(identityControllerProvider.notifier)
                                  .run((r) => r.revokeThisDevice());
                              if (context.mounted) context.pop();
                            }
                          },
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    ),
  );
}
