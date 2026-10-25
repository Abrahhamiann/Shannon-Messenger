import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/widgets.dart';
import '../identity/presentation/identity_controller.dart';
import '../identity/presentation/profile_route.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(identityControllerProvider).asData?.value;
    final avatar = identity?.id == null
        ? null
        : ref.watch(profileAvatarProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ShannonPanel(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: avatar == null ? null : MemoryImage(avatar),
                child: avatar == null
                    ? const Icon(ShannonIconsRegular.user)
                    : null,
              ),
              title: Text(
                identity?.nickname.isNotEmpty == true
                    ? identity!.nickname
                    : 'My profile',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Local identity, nickname & photo'),
              trailing: const Icon(ShannonIconsRegular.caretRight),
              onTap: () => context.push('/profile'),
            ),
          ),
          const SectionHeading('Make it yours'),
          ShannonPanel(
            child: Column(
              children: [
                const FeatureRow(
                  icon: ShannonIconsRegular.palette,
                  title: 'Appearance',
                  subtitle: 'A comfortable view, day or night',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mode in [
                        (ThemeMode.system, 'System'),
                        (ThemeMode.light, 'Light'),
                        (ThemeMode.dark, 'Dark'),
                      ])
                        ChoiceChip(
                          label: Text(mode.$2),
                          selected: ref.watch(themeModeProvider) == mode.$1,
                          onSelected: (_) => ref
                              .read(themeModeProvider.notifier)
                              .setMode(mode.$1),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeading('Identity & privacy'),
          ShannonPanel(
            child: Column(
              children: [
                _row(
                  context,
                  ShannonIconsRegular.shieldCheck,
                  'Privacy',
                  'A clear view of what stays private',
                  '/settings/privacy',
                ),
                const Divider(height: 1),
                _row(
                  context,
                  ShannonIconsRegular.lockKey,
                  'Security',
                  'Identity and session status',
                  '/identity',
                ),
                const Divider(height: 1),
                _row(
                  context,
                  ShannonIconsRegular.devices,
                  'Linked devices',
                  'Registered device and revocation',
                  '/identity/devices',
                ),
                const Divider(height: 1),
                _row(
                  context,
                  ShannonIconsRegular.key,
                  'Recovery',
                  'Not available yet',
                  '/identity/restore',
                ),
              ],
            ),
          ),
          const SectionHeading('App preferences'),
          ShannonPanel(
            child: Column(
              children: [
                _row(
                  context,
                  ShannonIconsRegular.bell,
                  'Notifications',
                  'Messaging notifications not available',
                  '/settings/notifications',
                ),
                const Divider(height: 1),
                _row(
                  context,
                  ShannonIconsRegular.hardDrives,
                  'Storage',
                  'Local data and device safety',
                  '/settings/storage',
                ),
                const Divider(height: 1),
                _row(
                  context,
                  ShannonIconsRegular.globe,
                  'Language',
                  'English · Armenian and Cyrillic fonts',
                  '/settings/language',
                ),
              ],
            ),
          ),
          const SectionHeading('About this build'),
          ShannonPanel(
            child: Column(
              children: [
                _row(
                  context,
                  ShannonIconsRegular.info,
                  'About Shannon',
                  'Early access · open-source notices',
                  '/settings/about',
                ),
                const Divider(height: 1),
                _row(
                  context,
                  ShannonIconsRegular.arrowCounterClockwise,
                  'Backend connection',
                  'Check service availability',
                  '/connection',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Center(child: ShannonMark(size: 36)),
          const SizedBox(height: 8),
          Text(
            'Shannon · a little more private.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String route,
  ) => FeatureRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: const Icon(ShannonIconsRegular.caretRight, size: 18),
    onTap: () => context.push(route),
  );
}

class PreferenceScreen extends StatelessWidget {
  const PreferenceScreen({required this.section, super.key});
  final String section;
  @override
  Widget build(BuildContext context) {
    final (icon, title, description, rows) = switch (section) {
      'privacy' => (
        ShannonIconsRegular.shieldCheck,
        'Privacy',
        'Private by intent. Honest about this build.',
        const [
          (
            'No address-book upload',
            'Your contacts are not collected. Private contact exchange is still being built.',
          ),
          (
            'No activity tracking',
            'No analytics, typing indicators, read receipts, last-seen or online status.',
          ),
          (
            'Local profile',
            'Nickname and avatar are stored on this device. They are not synchronized or uploaded.',
          ),
          (
            'Messaging is not implemented',
            'Authentication does not mean messages are end-to-end encrypted. This build cannot send messages.',
          ),
        ],
      ),
      'notifications' => (
        ShannonIconsRegular.bell,
        'Notifications',
        'Quiet until there is something real to say.',
        const [
          (
            'No messaging notifications',
            'Push and background delivery are not implemented. No notification permission is requested.',
          ),
          (
            'No preview controls yet',
            'Notification-content controls will be connected to actual encrypted message delivery.',
          ),
        ],
      ),
      'storage' => (
        ShannonIconsRegular.hardDrives,
        'Storage',
        'Keep this installation safe.',
        const [
          (
            'Identity and session',
            'Private identity keys and session tokens use encrypted Android app storage.',
          ),
          (
            'Profile photo',
            'A resized pixel-only image is stored locally. The system picker may retain a temporary source copy in app cache.',
          ),
          (
            'No recovery or backup',
            'Do not clear app data or uninstall. Identity loss can be permanent. There is no delete-identity action here.',
          ),
        ],
      ),
      'language' => (
        ShannonIconsRegular.globe,
        'Language',
        'Readable in the scripts you use.',
        const [
          (
            'Interface language',
            'English is currently the only translated interface. Language switching is not implemented.',
          ),
          (
            'Հայերեն · Русский · English',
            'Bundled Manrope and Noto Sans Armenian fonts support nicknames in these scripts without network font requests.',
          ),
        ],
      ),
      _ => (
        ShannonIconsRegular.info,
        'About Shannon',
        'A private messenger, being built carefully.',
        const [
          (
            'Working today',
            'Local identities, signed authentication, local profile editing, device registration and logout.',
          ),
          (
            'Still being built',
            'Encrypted messaging, private contacts, groups, calling, recovery and device linking. This is not a production-ready messenger.',
          ),
        ],
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FeatureNotice(icon: icon, title: title, message: description),
          ShannonPanel(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    title: Text(
                      rows[i].$1,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        rows[i].$2,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (section == 'about') ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Shannon'),
              child: const Text('Open-source licenses'),
            ),
          ],
        ],
      ),
    );
  }
}
