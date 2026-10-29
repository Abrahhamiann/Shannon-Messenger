import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';
import '../messaging/messaging_controller.dart';
import '../messaging/chat_components.dart';
import '../contacts/contact_preferences.dart';
import '../identity/presentation/identity_controller.dart';

class LocalConversation {
  const LocalConversation({
    required this.id,
    required this.nickname,
    this.username = '',
    this.groupName = '',
    this.preview = '',
    this.pinned = false,
    this.archived = false,
  });
  final String id, nickname, username, groupName, preview;
  final bool pinned, archived;
}

// M4 must supply real local records. Search never discovers remote accounts.
final localConversationsProvider = Provider<List<LocalConversation>>(
  (ref) => !m4MessagingEnabled
      ? const []
      : ref
            .watch(messagingProvider)
            .conversations
            .map(
              (row) => LocalConversation(
                id: row['binding']['account'] as String,
                nickname: contactName(
                  ref.watch(contactPreferencesProvider).asData?.value ?? {},
                  row['binding']['account'] as String,
                  row['label'] as String,
                ),
                pinned: row['chat_pinned'] == true,
                archived: row['archived'] == true,
                // Chat-list screenshots remain allowed. Plaintext previews are
                // confined to the capture-protected conversation screen.
                preview: 'Encrypted message · Open conversation',
              ),
            )
            .toList(),
);
List<LocalConversation> filterLocalChats(
  List<LocalConversation> records,
  String query,
) {
  final q = query.trim().toLowerCase();
  return records
      .where(
        (r) => [
          r.nickname,
          r.username,
          r.groupName,
        ].any((v) => v.toLowerCase().contains(q)),
      )
      .toList();
}

class ChatSearch extends ConsumerStatefulWidget {
  const ChatSearch({super.key});
  @override
  ConsumerState<ChatSearch> createState() => _ChatSearchState();
}

class _ChatSearchState extends ConsumerState<ChatSearch> {
  final input = TextEditingController();
  final anchors = <String, GlobalKey>{};
  String section = 'All';
  Future<void> menu(LocalConversation chat) async {
    final choice = await showShannonActions(
      context,
      anchor: anchors[chat.id]!,
      actions: [
        const FloatingActionItem(
          'delete',
          'Delete chat',
          Icons.delete_outline,
          hint: 'On this device',
        ),
        const FloatingActionItem(
          'both',
          'Delete chat for both participants',
          Icons.delete_forever_outlined,
          enabled: false,
          hint: 'Unavailable. Only your own messages support confirmed remote deletion.',
        ),
        FloatingActionItem(
          'pin',
          chat.pinned ? 'Unpin chat' : 'Pin chat',
          Icons.push_pin_outlined,
          hint: 'On this device',
        ),
        FloatingActionItem(
          'archive',
          chat.archived ? 'Unarchive' : 'Archive',
          Icons.archive_outlined,
          hint: 'On this device',
        ),
        const FloatingActionItem('block', 'Block user', Icons.block_outlined),
      ],
    );
    if (!mounted || choice == null) return;
    final service = ref.read(messagingProvider.notifier);
    try {
      if (choice.action == 'pin' || choice.action == 'archive') {
        await service.chatAction(
          chat.id,
          'chat_preferences',
          pinned: choice.action == 'pin' ? !chat.pinned : null,
          archived: choice.action == 'archive' ? !chat.archived : null,
        );
      } else {
        final block = choice.action == 'block';
        final approved = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(block ? 'Block user?' : 'Delete chat on this device?'),
            content: Text(
              block
                  ? 'Block new interaction with this account. Existing history and cryptographic keys remain. Unblock in Contact privacy.'
                  : 'Hide this chat and logically delete its local messages. The other participant’s copies stay. Keys and contact identity remain; already queued messages can still deliver. New messages can reopen the chat.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(block ? 'Block' : 'Delete'),
              ),
            ],
          ),
        );
        if (approved != true || !mounted) return;
        if (block) {
          await ref.read(identityRepositoryProvider).contactRequest(
            'POST',
            '/block',
            {'target': chat.id},
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'User blocked. Saved history and keys are preserved.',
                ),
              ),
            );
          }
        } else {
          await service.chatAction(chat.id, 'delete_chat');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not complete this action. Your keys were preserved.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records =
        filterLocalChats(ref.watch(localConversationsProvider), input.text)
            .where(
              (r) => section == 'Archived'
                  ? r.archived
                  : !r.archived && (section != 'Pinned' || r.pinned),
            )
            .toList()
          ..sort((a, b) => (b.pinned ? 1 : 0).compareTo(a.pinned ? 1 : 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: input,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Search Chats',
            hintText: 'Search existing conversations',
            prefixIcon: const Icon(ShannonIconsRegular.magnifyingGlass),
            suffixIcon: input.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(input.clear),
                    icon: const Icon(ShannonIconsRegular.x),
                  ),
          ),
        ),
        if (input.text.isNotEmpty || m4MessagingEnabled) ...[
          if (m4MessagingEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final label in ['All', 'Pinned', 'Archived'])
                    ChoiceChip(
                      label: Text(label),
                      selected: section == label,
                      onSelected: (_) => setState(() => section = label),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (records.isEmpty && input.text.isNotEmpty)
            const Text('No existing chats match.'),
          for (final record in records)
            ListTile(
              key: anchors.putIfAbsent(record.id, () => GlobalKey()),
              title: Text(
                record.nickname.isEmpty ? record.username : record.nickname,
              ),
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              trailing: record.pinned
                  ? const Icon(Icons.push_pin_outlined, size: 18)
                  : null,
              subtitle: Text(
                record.preview.isEmpty ? record.groupName : record.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => context.push(
                '/conversation/${Uri.encodeComponent(record.id)}',
              ),
              onLongPress: () => menu(record),
            ),
        ],
      ],
    );
  }
}
