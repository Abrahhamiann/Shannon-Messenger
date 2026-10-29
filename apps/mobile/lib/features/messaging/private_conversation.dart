import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/icons.dart';
import '../../app/screen_privacy.dart';
import '../contacts/contact_preferences.dart';
import '../identity/presentation/identity_controller.dart';
import 'messaging_controller.dart';
import 'chat_components.dart';

Map<String, dynamic> _reference(String value) {
  final parts = value.split(':');
  return {'sender_device': parts.first, 'id': parts.last};
}

String _key(Map<String, dynamic> message) =>
    '${message['sender_device']}:${message['id']}';

final conversationWindowProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, String, int)>((
      ref,
      key,
    ) async {
      final view = ref.watch(messagingProvider);
      if (!view.ready || !view.foreground) return [];
      final rows = <Map<String, dynamic>>[];
      int? before;
      for (var page = 0; page < key.$3.clamp(1, 20); page++) {
        final result = await messagingNative({
          'op': page == 0 && key.$2.isNotEmpty ? 'around' : 'history',
          'account': key.$1,
          if (page == 0 && key.$2.isNotEmpty) 'target': _reference(key.$2),
          'before': ?before,
        });
        if (!ref.mounted || !ref.read(messagingProvider).foreground) return [];
        final items = (result['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        rows.addAll(items);
        if (items.length < 50) break;
        before = items.last['local_row'] as int;
      }
      return rows;
    });
final pinnedMessageProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (String, String)>((ref, key) async {
      final view = ref.watch(messagingProvider);
      if (!view.ready || !view.foreground || key.$2.isEmpty) return {};
      return messagingNative({
        'op': 'message',
        'account': key.$1,
        'target': _reference(key.$2),
      });
    });

class PrivateConversationScreen extends ConsumerStatefulWidget {
  const PrivateConversationScreen({required this.account, super.key});
  final String account;
  @override
  ConsumerState<PrivateConversationScreen> createState() =>
      _PrivateConversationState();
}

class _PrivateConversationState
    extends ConsumerState<PrivateConversationScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  final focus = FocusNode();
  final anchors = <String, GlobalKey>{};
  bool opening = true, sending = false;
  String? error;
  String anchor = '';
  int pages = 1;
  Map<String, dynamic>? reply, editing;
  String draftBeforeEdit = '';
  final selected = <String, Map<String, dynamic>>{};
  void selectMessage(Map<String, dynamic> message) {
    final id = _key(message);
    if (!selected.containsKey(id) && selected.length >= 100) {
      notice('Select up to 100 messages at a time.');
      return;
    }
    setState(
      () => selected.containsKey(id)
          ? selected.remove(id)
          : selected[id] = message,
    );
  }

  Future<void> deleteSelected(bool capable) async {
    final messages = selected.values.toList();
    final allowed =
        capable &&
        messages.every(
          (m) => m['sender'] == service.ownAccount && m['deleted'] != true,
        );
    final scope = await showDialog<DeleteScope>(
      context: context,
      builder: (_) => DeleteConfirmation(
        count: messages.length,
        canDeleteEveryone: allowed,
        disabledReason: 'Shared deletion requires every selected message to be yours and the peer to support encrypted deletion.',
      ),
    );
    if (scope == null || !mounted) return;
    await act(() async {
      await service.deleteMessages(
        widget.account,
        messages,
        everyone: scope == DeleteScope.everyone,
      );
      if (mounted) setState(selected.clear);
    });
  }

  Future<void> forwardSelected() async {
    final ordered = selected.values.toList()
      ..sort(
        (a, b) => (a['local_row'] as int? ?? a['timestamp'] as int).compareTo(
          b['local_row'] as int? ?? b['timestamp'] as int,
        ),
      );
    final texts = ordered
        .where((m) => m['deleted'] != true)
        .map((m) => m['text'] as String)
        .toList();
    if (texts.length != selected.length) {
      notice('Deleted messages cannot be forwarded.');
      return;
    }
    final destination = await showDialog<String>(
      context: context,
      builder: (_) => ForwardMessageSelector(text: texts.first, texts: texts),
    );
    if (destination != null && mounted) {
      setState(selected.clear);
      if (destination != widget.account) {
        context.push('/conversation/${Uri.encodeComponent(destination)}');
      }
    }
  }

  MessagingController get service => ref.read(messagingProvider.notifier);
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await service.openPeer(widget.account);
      } catch (failure) {
        if (mounted) setState(() => error = messagingFailureMessage(failure));
      }
      if (mounted) setState(() => opening = false);
    });
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (failure) {
      if (mounted) setState(() => error = messagingFailureMessage(failure));
    }
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> send() async {
    if (sending || input.text.trim().isEmpty) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      if (editing != null) {
        await service.interact(
          widget.account,
          'edit',
          editing!,
          text: input.text,
        );
      } else {
        await service.send(
          widget.account,
          input.text,
          reply: reply == null ? null : messageReference(reply!),
        );
      }
      if (mounted) {
        setState(() {
          input.clear();
          reply = null;
          editing = null;
          anchor = '';
          pages = 1;
        });
        if (scroll.hasClients) {
          unawaited(
            scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
            ),
          );
        }
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () =>
              error = '${messagingFailureMessage(failure)} Your draft is kept.',
        );
      }
    }
    if (mounted) setState(() => sending = false);
  }

  Future<void> jump(Map<String, dynamic> target) async {
    final result = await messagingNative({
      'op': 'message',
      'account': widget.account,
      'target': target,
    });
    if (!mounted) return;
    if (result.isEmpty) {
      notice('Original message unavailable on this device.');
      return;
    }
    setState(() {
      anchor = _key(target);
      pages = 1;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> react(Map<String, dynamic> message, String emoji) async {
    final own = (message['reactions'] as List? ?? [])
        .where((r) => r['own'] == true)
        .firstOrNull;
    await act(
      () => service.interact(
        widget.account,
        'reaction',
        message,
        emoji: own?['emoji'] == emoji ? '' : emoji,
      ),
    );
  }

  Future<void> menu(
    Map<String, dynamic> message,
    Map<String, dynamic> peer,
  ) async {
    final own = message['sender'] == service.ownAccount,
        deleted = message['deleted'] == true;
    final capable =
        peer['interactions'] == true && peer['identity_changed'] != true;
    final selected =
        (message['reactions'] as List? ?? [])
                .where((r) => r['own'] == true)
                .firstOrNull?['emoji']
            as String?;
    final pinned = peer['pinned_message'] == _key(message);
    final result = await showShannonActions(
      context,
      anchor: anchors[_key(message)]!,
      reactions: !deleted,
      reactionsEnabled: capable,
      selectedReaction: selected,
      explanation: !capable && !deleted
          ? 'This contact must confirm encrypted interaction support. Text messaging still works.'
          : null,
      actions: [
        const FloatingActionItem(
          'select',
          'Select messages',
          Icons.checklist_outlined,
        ),
        FloatingActionItem(
          'reply',
          'Reply',
          Icons.reply_rounded,
          enabled: capable && !deleted,
        ),
        FloatingActionItem(
          'copy',
          'Copy',
          ShannonIconsRegular.copy,
          enabled: !deleted,
        ),
        FloatingActionItem(
          'forward',
          'Forward',
          Icons.shortcut_outlined,
          enabled: !deleted,
        ),
        FloatingActionItem(
          'pin',
          pinned ? 'Unpin' : 'Pin',
          ShannonIconsRegular.pushPin,
          hint: 'On this device',
        ),
        if (own)
          FloatingActionItem(
            'edit',
            'Edit',
            Icons.edit_outlined,
            enabled: capable && !deleted,
          ),
        const FloatingActionItem('delete', 'Delete', Icons.delete_outline),
      ],
    );
    if (!mounted || result == null || !ref.read(messagingProvider).foreground) {
      return;
    }
    switch (result.action) {
      case 'select':
        selectMessage(message);
        break;
      case 'reply':
        setState(() {
          editing = null;
          reply = message;
        });
        focus.requestFocus();
        break;
      case 'copy':
        await act(() async {
          if (nativePrivacy) {
            await privacyChannel.invokeMethod<void>(
              'copyPrivate',
              message['text'],
            );
          } else {
            await Clipboard.setData(
              ClipboardData(text: message['text'] as String),
            );
          }
          notice('Copied. Your clipboard may retain this text.');
        });
        break;
      case 'reaction':
        await act(
          () => service.interact(
            widget.account,
            'reaction',
            message,
            emoji: result.value!,
          ),
        );
        break;
      case 'pin':
        await act(
          () => service.localAction(
            widget.account,
            'pin',
            message,
            value: !pinned,
          ),
        );
        break;
      case 'edit':
        setState(() {
          draftBeforeEdit = input.text;
          reply = null;
          editing = message;
          input.text = message['text'] as String;
        });
        focus.requestFocus();
        break;
      case 'delete':
        final scope = await showDialog<DeleteScope>(
          context: context,
          builder: (_) => DeleteConfirmation(
            canDeleteEveryone: own && capable && !deleted,
            disabledReason: !own
                ? 'Only the sender can request shared deletion.'
                : deleted
                ? 'This message is already deleted.'
                : 'The contact has not confirmed encrypted deletion support.',
          ),
        );
        if (scope == null || !mounted) return;
        await act(
          () => scope == DeleteScope.me
              ? service.localAction(widget.account, 'local_delete', message)
              : service.interact(widget.account, 'delete', message),
        );
        break;
      case 'forward':
        final destination = await showDialog<String>(
          context: context,
          builder: (_) =>
              ForwardMessageSelector(text: message['text'] as String),
        );
        if (destination != null && mounted) {
          if (destination != widget.account) {
            context.push('/conversation/${Uri.encodeComponent(destination)}');
          } else {
            notice('Encrypted copy queued.');
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(messagingProvider);
    final peer = ref.watch(messagingPeerProvider(widget.account)).value ?? {};
    final preferences =
        ref.watch(contactPreferencesProvider).asData?.value ?? {};
    final fallback = peer['label'] as String?;
    final name = contactName(
      preferences,
      widget.account,
      fallback == null || fallback == widget.account
          ? 'Private contact'
          : fallback,
    );
    final history = ref.watch(
      conversationWindowProvider((widget.account, anchor, pages)),
    );
    final pin = peer['pinned_message'] as String? ?? '';
    final pinned = pin.isEmpty
        ? <String, dynamic>{}
        : ref.watch(pinnedMessageProvider((widget.account, pin))).value ?? {};
    final capable =
        peer['interactions'] == true && peer['identity_changed'] != true;
    return PopScope(
      canPop: selected.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selected.isNotEmpty) setState(selected.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: selected.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Cancel selection',
                  onPressed: () => setState(selected.clear),
                  icon: const Icon(Icons.close),
                ),
          titleSpacing: 0,
          title: selected.isNotEmpty
              ? Text('${selected.length} selected')
              : ConversationIdentityHeader(
                  name: name,
                  onTap: () => context.push(
                    '/conversation/${Uri.encodeComponent(widget.account)}/security',
                  ),
                ),
          actions: [
            if (selected.isNotEmpty) ...[
              IconButton(
                tooltip: 'Forward selected messages',
                onPressed: forwardSelected,
                icon: const Icon(Icons.shortcut_outlined),
              ),
              IconButton(
                tooltip: 'Delete selected messages',
                onPressed: () => deleteSelected(capable),
                icon: const Icon(Icons.delete_outline),
              ),
            ] else
              IconButton(
                tooltip: 'Contact details and security',
                onPressed: () => context.push(
                  '/conversation/${Uri.encodeComponent(widget.account)}/security',
                ),
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (opening) const LinearProgressIndicator(minHeight: 2),
              if (peer['identity_changed'] == true)
                Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Contact identity changed. Sending is blocked. Review contact security.',
                    ),
                  ),
                ),
              if (error != null || view.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    error ?? view.error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (pin.isNotEmpty && view.foreground && view.ready)
                PinnedMessageIndicator(
                  text: pinned['deleted'] == true
                      ? 'Message deleted'
                      : pinned['text'] as String? ?? 'Message unavailable',
                  onTap: () => act(() => jump(_reference(pin))),
                  onUnpin: () => act(
                    () => service.localAction(
                      widget.account,
                      'pin',
                      _reference(pin),
                      value: false,
                    ),
                  ),
                ),
              if (anchor.isNotEmpty)
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Earlier messages',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        anchor = '';
                        pages = 1;
                      }),
                      child: const Text('Latest'),
                    ),
                  ],
                ),
              Expanded(
                child: !view.foreground || !view.ready
                    ? const SizedBox.shrink()
                    : history.when(
                        skipLoadingOnRefresh: true,
                        skipLoadingOnReload: true,
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const Center(
                          child: Text(
                            'Encrypted history unavailable. No keys or data were reset.',
                          ),
                        ),
                        data: (records) {
                          for (final message in records) {
                            if (selected.containsKey(_key(message))) {
                              selected[_key(message)] = message;
                            }
                          }
                          final ids = records.map(_key).toSet();
                          anchors.removeWhere((id, _) => !ids.contains(id));
                          if (records.isEmpty) {
                            return Center(
                              child: Text(
                                anchor.isEmpty
                                    ? 'Send your first message.'
                                    : 'Message unavailable on this device.',
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scroll,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            itemCount: records.length + 1,
                            itemBuilder: (context, index) {
                              if (index == records.length) {
                                return TextButton(
                                  onPressed: () => setState(() {
                                    if (pages < 20) {
                                      pages++;
                                    } else {
                                      anchor = _key(records.last);
                                      pages = 1;
                                      if (scroll.hasClients) scroll.jumpTo(0);
                                    }
                                  }),
                                  child: Text(
                                    pages < 20
                                        ? 'Older messages'
                                        : 'Continue earlier',
                                  ),
                                );
                              }
                              final message = records[index];
                              final id = _key(message);
                              final key = anchors.putIfAbsent(
                                id,
                                () => GlobalKey(),
                              );
                              return Column(
                                key: ValueKey(id),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      if (selected.isNotEmpty)
                                        Checkbox(
                                          value: selected.containsKey(id),
                                          onChanged: (_) =>
                                              selectMessage(message),
                                        ),
                                      Expanded(
                                        child: CompactMessageBubble(
                                          anchorKey: key,
                                          message: message,
                                          own:
                                              message['sender'] ==
                                              service.ownAccount,
                                          contactName: name,
                                          highlight:
                                              id == anchor ||
                                              selected.containsKey(id),
                                          onTap: () => selected.isEmpty
                                              ? menu(message, peer)
                                              : selectMessage(message),
                                          onLongPress: () =>
                                              selectMessage(message),
                                          onReaction:
                                              capable && selected.isEmpty
                                              ? (emoji) => react(message, emoji)
                                              : null,
                                          onReplyTap: selected.isNotEmpty
                                              ? () => selectMessage(message)
                                              : message['reply_preview']?['available'] ==
                                                    true
                                              ? () => act(
                                                  () => jump(
                                                    Map<String, dynamic>.from(
                                                      message['reply'] as Map,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (message['state'] == 'failed')
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => act(
                                          () => service.retry(
                                            message['id'] as String,
                                          ),
                                        ),
                                        child: const Text('Retry same message'),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
              ),
              if (reply != null || editing != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: ReplyPreview(
                    title: editing != null
                        ? 'Editing message'
                        : reply!['sender'] == service.ownAccount
                        ? 'Reply to you'
                        : 'Reply to $name',
                    text: (editing ?? reply)!['text'] as String,
                    onCancel: () => setState(() {
                      if (editing != null) input.text = draftBeforeEdit;
                      reply = null;
                      editing = null;
                    }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 10),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          focusNode: focus,
                          enabled:
                              view.ready &&
                              view.foreground &&
                              !opening &&
                              !sending &&
                              peer['identity_changed'] != true,
                          minLines: 1,
                          maxLines: 6,
                          maxLength: 4000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: editing == null
                                ? 'Message'
                                : 'Edit message',
                            counterText: '',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: editing == null
                            ? 'Send encrypted message'
                            : 'Save encrypted edit',
                        onPressed:
                            view.ready &&
                                view.foreground &&
                                !opening &&
                                !sending &&
                                peer['identity_changed'] != true
                            ? send
                            : null,
                        icon: sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                editing == null
                                    ? ShannonIconsRegular.paperPlaneTilt
                                    : Icons.check,
                              ),
                      ),
                      const SizedBox(width: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ForwardMessageSelector extends ConsumerStatefulWidget {
  const ForwardMessageSelector({required this.text, this.texts, super.key});
  final String text;
  final List<String>? texts;
  @override
  ConsumerState<ForwardMessageSelector> createState() =>
      _ForwardMessageSelectorState();
}

class _ForwardMessageSelectorState
    extends ConsumerState<ForwardMessageSelector> {
  late Future<List<Map<String, dynamic>>> destinations;
  String? error;
  bool busy = false;
  int queued = 0;
  @override
  void initState() {
    super.initState();
    destinations = load();
  }

  Future<List<Map<String, dynamic>>> load() async {
    final accepted = <String>{};
    String next = '';
    for (var i = 0; i < 5; i++) {
      final result = await ref
          .read(identityRepositoryProvider)
          .contactRequest(
            'GET',
            next.isEmpty ? '' : '?after=${Uri.encodeQueryComponent(next)}',
          );
      accepted.addAll(
        (result['items'] as List)
            .where((e) => e['kind'] == 'accepted')
            .map((e) => e['id'] as String),
      );
      next = result['next'] as String;
      if (next.isEmpty) break;
    }
    return ref
        .read(messagingProvider)
        .conversations
        .where((row) => accepted.contains(row['binding']['account']))
        .toList();
  }

  Future<void> choose(Map<String, dynamic> destination) async {
    final account = destination['binding']['account'] as String;
    final preferences =
        ref.read(contactPreferencesProvider).asData?.value ?? {};
    final name = contactName(
      preferences,
      account,
      destination['label'] as String,
    );
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.texts == null
              ? 'Forward to $name?'
              : 'Forward ${widget.texts!.length} messages to $name?',
        ),
        content: const Text(
          'Send a new encrypted copy. The original sender’s identity is not included.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forward'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      final service = ref.read(messagingProvider.notifier);
      final texts = widget.texts ?? [widget.text];
      while (queued < texts.length) {
        await service.send(account, texts[queued], forwarded: true);
        queued++;
      }
      if (mounted) Navigator.pop(context, account);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error =
              '${messagingFailureMessage(failure)} $queued already queued; retry continues with the remaining messages.',
        );
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Forward message'),
    content: SizedBox(
      width: 340,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: destinations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Connect to load eligible existing conversations.',
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data!.isEmpty) {
            return const Text(
              'No eligible conversations. Add and accept a contact, then open a conversation first.',
            );
          }
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .5,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) Text(error!),
                  for (final row in snapshot.data!)
                    ListTile(
                      enabled: !busy,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        contactName(
                          ref.watch(contactPreferencesProvider).asData?.value ??
                              {},
                          row['binding']['account'] as String,
                          row['label'] as String,
                        ),
                      ),
                      onTap: () => choose(row),
                    ),
                  if (busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
