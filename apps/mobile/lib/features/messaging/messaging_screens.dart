import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'messaging_controller.dart';
import '../contacts/contact_preferences.dart';
export 'private_conversation.dart';

class MessagingSecurityScreen extends ConsumerStatefulWidget {
  const MessagingSecurityScreen({required this.account, super.key});
  final String account;
  @override
  ConsumerState<MessagingSecurityScreen> createState() =>
      _MessagingSecurityState();
}

class _MessagingSecurityState extends ConsumerState<MessagingSecurityScreen> {
  late Future<Map<String, dynamic>> details;
  @override
  void initState() {
    super.initState();
    details = ref.read(messagingProvider.notifier).security(widget.account);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify contact identity')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: details,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Identity details unavailable. Sending must not bypass a key-change warning.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final preferences =
            ref.watch(contactPreferencesProvider).asData?.value ?? {};
        final name = contactName(
          preferences,
          widget.account,
          data['label'] as String? ?? 'Private contact',
        );
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 32,
                child: Text(
                  name.characters.firstOrNull?.toUpperCase() ?? 'S',
                  style: const TextStyle(fontSize: 25),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () async {
                final input = TextEditingController(
                  text: preferences[widget.account]?['name'] as String? ?? '',
                );
                final value = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Name on this device'),
                    content: TextField(
                      controller: input,
                      maxLength: 64,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Contact display name',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, input.text),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (value != null) {
                  try {
                    await ref
                        .read(contactPreferencesProvider.notifier)
                        .saveContact(widget.account, name: value);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not save the local name.'),
                        ),
                      );
                    }
                  }
                }
                // Dialog route transitions may still use its controller this frame.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  input.dispose();
                });
              },
              child: const Text('Edit local display name'),
            ),
            const Text(
              'Profile photos are not shared in this build. This avatar is an on-device fallback.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            SelectableText(
              widget.account,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text(
              data['identity_changed'] == true
                  ? 'Identity changed · Sending blocked'
                  : data['verified'] == true
                  ? 'Verified by your comparison'
                  : 'Identity not verified',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Compare this complete fingerprint with your contact in person or through a separate trusted channel. A username match or an invitation QR does not verify encryption keys.',
            ),
            const SizedBox(height: 24),
            SelectableText(
              data['fingerprint'] as String,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 20),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: data['identity_changed'] == true
                  ? null
                  : () async {
                      await ref
                          .read(messagingProvider.notifier)
                          .verified(widget.account, true);
                      if (mounted) {
                        setState(
                          () => details = ref
                              .read(messagingProvider.notifier)
                              .security(widget.account),
                        );
                      }
                    },
              child: const Text('I compared the full fingerprint'),
            ),
            if (data['verified'] == true)
              TextButton(
                onPressed: () async {
                  await ref
                      .read(messagingProvider.notifier)
                      .verified(widget.account, false);
                  if (mounted) {
                    setState(
                      () => details = ref
                          .read(messagingProvider.notifier)
                          .security(widget.account),
                    );
                  }
                },
                child: const Text('Mark unverified'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Classical Olm v1. This is a Shannon fingerprint, not a Signal safety number. Account recovery and chat backup remain unavailable.',
            ),
          ],
        );
      },
    ),
  );
}
