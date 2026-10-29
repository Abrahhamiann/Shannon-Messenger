import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/widgets.dart';
import 'chat_search.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messaging/messaging_controller.dart';

class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});
  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  String filter = 'All', query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Shannon'),
      actions: [
        IconButton(
          tooltip: 'My profile',
          onPressed: () => context.push('/profile'),
          icon: const Icon(ShannonIconsRegular.userCircle),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        if (m4MessagingEnabled) const SectionHeading('Conversations'),
        const ChatSearch(),
        const SizedBox(height: 16),
        if (!m4MessagingEnabled)
          HubFilters(
            values: const ['All', 'Pinned', 'Archived'],
            selected: filter,
            onChanged: (value) => setState(() => filter = value),
          ),
        if (!m4MessagingEnabled)
          SectionHeading(filter == 'All' ? 'Conversations' : filter),
        if (!m4MessagingEnabled ||
            ref.watch(messagingProvider).conversations.isEmpty)
          FeatureNotice(
            icon: filter == 'Archived'
                ? ShannonIconsRegular.archive
                : ShannonIconsRegular.chatsCircle,
            title: query.isNotEmpty
                ? 'No conversations to search'
                : filter == 'Pinned'
                ? 'Keep your favorites close'
                : filter == 'Archived'
                ? 'A quieter inbox'
                : 'Start a private conversation',
            message: m4MessagingEnabled
                ? 'Add and accept a contact, then open an encrypted text conversation from Contacts.'
                : 'Connect with someone to get started. Contact requests work now; encrypted messaging is not available yet.',
            action: Column(
              children: [
                FeatureRow(
                  icon: Icons.search,
                  title: 'Search Username',
                  subtitle: 'Find someone by exact @username',
                  onTap: () => context.push('/contacts/add'),
                ),
                FeatureRow(
                  icon: Icons.qr_code_scanner,
                  title: 'Scan QR Code',
                  subtitle: 'Scan a private contact invitation',
                  onTap: () => context.push('/contacts/scan'),
                ),
                FeatureRow(
                  icon: Icons.link,
                  title: 'Share Invite',
                  subtitle: 'Create and share your invitation',
                  onTap: () => context.push('/contacts/qr'),
                ),
              ],
            ),
          ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Private contact options',
      onPressed: () => context.push('/contacts/add'),
      child: const Icon(ShannonIconsRegular.plus),
    ),
  );
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String filter = 'People', query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Contacts'),
      actions: [
        IconButton(
          tooltip: 'Add contact',
          onPressed: () => context.push('/contacts/add'),
          icon: const Icon(ShannonIconsRegular.userPlus),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        HubSearch(
          hint: 'Search saved contacts',
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 16),
        HubFilters(
          values: const ['People', 'Groups'],
          selected: filter,
          onChanged: (value) => setState(() => filter = value),
        ),
        FeatureNotice(
          icon: filter == 'Groups'
              ? ShannonIconsRegular.usersThree
              : ShannonIconsRegular.users,
          title: query.isNotEmpty
              ? 'No saved contacts to search'
              : filter == 'Groups'
              ? 'Together, in your own space.'
              : 'Your people. By invitation.',
          message: filter == 'Groups'
              ? 'Group communication is disabled until a secure group protocol is implemented.'
              : 'Contact exchange is still being built. Shannon never searches for strangers or uploads your address book.',
          action: TextButton(
            onPressed: () => context.push(
              filter == 'Groups' ? '/groups/new' : '/contacts/add',
            ),
            child: Text(filter == 'Groups' ? 'Group details' : 'Add contact'),
          ),
        ),
        const SectionHeading('Private connections'),
        ShannonPanel(
          child: Column(
            children: [
              FeatureRow(
                icon: ShannonIconsRegular.qrCode,
                title: 'My public identity',
                subtitle: 'Copy your identifier · QR invites unavailable',
                onTap: () => context.push('/profile'),
              ),
              const Divider(height: 1),
              FeatureRow(
                icon: ShannonIconsRegular.userPlus,
                title: 'Contact requests',
                subtitle: 'Not available in this build',
                onTap: () => context.push('/contacts/requests'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calls')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ShannonIconsRegular.phone,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text('No calls yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Your call history will appear here.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Secure calling is not available yet.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

class HubSearch extends StatelessWidget {
  const HubSearch({required this.hint, required this.onChanged, super.key});
  final String hint;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(ShannonIconsRegular.magnifyingGlass, size: 21),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    ),
  );
}

class HubFilters extends StatelessWidget {
  const HubFilters({
    required this.values,
    required this.selected,
    required this.onChanged,
    super.key,
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        ChoiceChip(
          label: Text(value),
          selected: selected == value,
          showCheckmark: false,
          onSelected: (_) => onChanged(value),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide.none,
          ),
        ),
    ],
  );
}
