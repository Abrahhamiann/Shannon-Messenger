import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';

class LocalConversation {
  const LocalConversation({
    required this.id,
    required this.nickname,
    this.username = '',
    this.groupName = '',
  });
  final String id, nickname, username, groupName;
}

// M4 must supply real local records. Search never discovers remote accounts.
final localConversationsProvider = Provider<List<LocalConversation>>(
  (ref) => const [],
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
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = filterLocalChats(
      ref.watch(localConversationsProvider),
      input.text,
    );
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
        if (input.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (records.isEmpty) const Text('No existing chats match.'),
          for (final record in records)
            ListTile(
              title: Text(
                record.nickname.isEmpty ? record.username : record.nickname,
              ),
              subtitle: Text(record.groupName),
              onTap: () => context.push(
                '/conversation/${Uri.encodeComponent(record.id)}',
              ),
            ),
        ],
      ],
    );
  }
}
