import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/icons.dart';

import '../../../app/design_system.dart';
import '../data/identity_repository.dart';
import 'identity_controller.dart';

/// Demo content is only available before creating an identity. Fail closed
/// while reading storage, including when storage is unavailable.
class IdentityPreviewBoundary extends ConsumerWidget {
  const IdentityPreviewBoundary({
    required this.section,
    required this.preview,
    super.key,
  });
  final String section;
  final Widget preview;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(identityControllerProvider);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.asData?.value.stage == IdentityStage.none) return preview;
    final (icon, title, detail) =
        state.hasError ||
            state.asData?.value.stage == IdentityStage.storageUnavailable
        ? (
            ShannonIconsRegular.lockKey,
            'Identity storage unavailable',
            'Shannon could not verify local identity storage. No keys were erased. Open identity details before continuing; do not uninstall or clear app data.',
          )
        : switch (section) {
            'Chats' => (
              ShannonIconsRegular.chatsCircle,
              'A space for your conversations',
              'Your identity is here. Private messaging is still being built; no conversations have been sent or received.',
            ),
            'Calls' => (
              ShannonIconsRegular.phone,
              'Closer, wherever you are',
              'Voice and video calling are not available in this build. There is no call history to show.',
            ),
            'Contacts' => (
              ShannonIconsRegular.users,
              'Your people, by invitation',
              'Contact invitations and groups are not available yet. Shannon does not upload your address book.',
            ),
            _ => (
              ShannonIconsRegular.lockKey,
              'This feature is not available yet',
              'Your real identity is active locally. This build cannot send messages, link another device or share profile data.',
            ),
          };
    return Scaffold(
      appBar: AppBar(title: Text(section == 'Chats' ? 'Shannon' : section)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(ShannonSpace.section),
              child: ShannonReveal(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: ShannonSpace.section),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: ShannonSpace.medium),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: ShannonSpace.section),
                    FilledButton(
                      onPressed: () => context.push('/profile'),
                      child: const Text('My profile'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/identity'),
                      child: const Text('Check identity and session'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
