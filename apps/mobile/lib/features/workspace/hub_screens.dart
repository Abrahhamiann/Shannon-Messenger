import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/widgets.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
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
      padding: const EdgeInsets.all(20),
      children: [
        HubSearch(
          hint: 'Search your conversations',
          onChanged: (value) => setState(() => query = value),
        ),
        const SizedBox(height: 16),
        HubFilters(
          values: const ['All', 'Pinned', 'Archived'],
          selected: filter,
          onChanged: (value) => setState(() => filter = value),
        ),
        SectionHeading(filter == 'All' ? 'Conversations' : filter),
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
              : 'Good conversations start here.',
          message: 'Private messaging is not available in this build. No messages have been sent or received. Your local identity is ready when you are.',
          action: OutlinedButton.icon(
            onPressed: () => context.push('/contacts/add'),
            icon: const Icon(ShannonIconsRegular.userPlus),
            label: const Text('About private contacts'),
          ),
        ),
        const ShannonPanel(
          child: FeatureRow(
            icon: ShannonIconsRegular.eyeSlash,
            title: 'A private space',
            subtitle: 'No public user search. No address-book upload.',
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
      padding: const EdgeInsets.all(20),
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

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});
  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  String filter = 'All';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calls')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        HubFilters(
          values: const ['All', 'Missed'],
          selected: filter,
          onChanged: (value) => setState(() => filter = value),
        ),
        const SectionHeading('Recent'),
        const FeatureNotice(
          icon: ShannonIconsRegular.phone,
          title: 'A familiar voice. A little closer.',
          message: 'Voice and video calls are not available yet. There is no real call history to display.',
        ),
        ShannonPanel(
          child: Column(
            children: [
              FeatureRow(
                icon: ShannonIconsRegular.phone,
                title: 'Voice calls',
                subtitle: 'Explore the interface · calling disabled',
                onTap: () => context.push('/calls/preview'),
              ),
              const Divider(height: 1),
              FeatureRow(
                icon: ShannonIconsRegular.videoCamera,
                title: 'Video calls',
                subtitle: 'Explore the interface · camera stays off',
                onTap: () => context.push('/calls/preview?video=true'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No microphone or camera access is requested by these previews.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
