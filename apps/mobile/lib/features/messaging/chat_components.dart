import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/icons.dart';

const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

class MessageChoice {
  const MessageChoice(this.action, [this.value]);
  final String action;
  final String? value;
}

class FloatingActionItem {
  const FloatingActionItem(
    this.action,
    this.label,
    this.icon, {
    this.enabled = true,
    this.hint,
  });
  final String action, label;
  final IconData icon;
  final bool enabled;
  final String? hint;
}

Future<MessageChoice?> showShannonActions(
  BuildContext context, {
  required GlobalKey anchor,
  required List<FloatingActionItem> actions,
  bool reactions = false,
  bool reactionsEnabled = false,
  String? selectedReaction,
  String? explanation,
}) async {
  // Snapshot while the tapped element is active. Never inspect its element
  // from an overlay build: history updates can deactivate that element.
  final render = anchor.currentContext?.findRenderObject();
  final anchorRect = render is RenderBox && render.attached && render.hasSize
      ? render.localToGlobal(Offset.zero) & render.size
      : Rect.fromCenter(
          center: MediaQuery.sizeOf(context).center(Offset.zero),
          width: 1,
          height: 1,
        );
  FocusManager.instance.primaryFocus?.unfocus();
  final route = RawDialogRoute<MessageChoice>(
    barrierDismissible: true,
    barrierLabel: 'Dismiss actions',
    barrierColor: Colors.black.withValues(alpha: .12),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 130),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: .97, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
    pageBuilder: (context, _, _) => LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final width = math.min(
          reactions ? 292.0 : 250.0,
          media.size.width - 24,
        );
        final rect = anchorRect;
        final top = media.padding.top + 8;
        final bottom = math.max(
          top + 48,
          media.size.height -
              media.padding.bottom -
              media.viewInsets.bottom -
              8,
        );
        return CustomSingleChildLayout(
          delegate: _ActionMenuPosition(rect, width, top, bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: rect.center.dx > media.size.width / 2
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (reactions) ...[
                  ReactionBar(
                    enabled: reactionsEnabled,
                    selected: selectedReaction,
                    onSelected: (emoji) => Navigator.pop(
                      context,
                      MessageChoice('reaction', emoji),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                SizedBox(
                  width: reactions ? math.min(240.0, width) : width,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(19),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in actions)
                            MessageActionRow(
                              item: item,
                              onTap: () => Navigator.pop(
                                context,
                                MessageChoice(item.action),
                              ),
                            ),
                          if (explanation != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                              child: Text(
                                explanation,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  if (result?.action == 'reaction') return result;
  // Let the popup release its focus scope before Reply/Edit focus the composer
  // or Delete/Forward open another route.
  await route.completed;
  return result;
}

/// Position from measured content rather than guessing scaled row heights.
class _ActionMenuPosition extends SingleChildLayoutDelegate {
  _ActionMenuPosition(this.anchor, this.width, this.top, this.bottom);
  final Rect anchor;
  final double width, top, bottom;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: bottom - top);
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x =
        (anchor.center.dx > size.width / 2
                ? anchor.right - childSize.width
                : anchor.left)
            .clamp(12.0, math.max(12.0, size.width - childSize.width - 12));
    final y =
        (anchor.bottom + childSize.height + 6 <= bottom
                ? anchor.bottom + 6
                : anchor.top - childSize.height - 6)
            .clamp(top, math.max(top, bottom - childSize.height));
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(covariant _ActionMenuPosition old) =>
      old.anchor != anchor ||
      old.width != width ||
      old.top != top ||
      old.bottom != bottom;
}

class ReactionBar extends StatelessWidget {
  const ReactionBar({
    required this.enabled,
    required this.onSelected,
    this.selected,
    super.key,
  });
  final bool enabled;
  final String? selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    elevation: 8,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final emoji in quickReactions)
              Semantics(
                button: true,
                enabled: enabled,
                selected: emoji == selected,
                label: emoji == selected
                    ? 'Remove $emoji reaction'
                    : 'React $emoji',
                child: InkWell(
                  onTap: enabled
                      ? () => onSelected(emoji == selected ? '' : emoji)
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: emoji == selected
                          ? Theme.of(context).colorScheme.primary
                                .withValues(alpha: .17)
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Opacity(
                      opacity: enabled ? 1 : .35,
                      child: Text(emoji, style: const TextStyle(fontSize: 25)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class MessageActionRow extends StatelessWidget {
  const MessageActionRow({required this.item, required this.onTap, super.key});
  final FloatingActionItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    enabled: item.enabled,
    dense: true,
    minTileHeight: 44,
    minLeadingWidth: 22,
    horizontalTitleGap: 12,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: Icon(item.icon, size: 21),
    title: Text(
      item.label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: item.hint == null
        ? null
        : Text(item.hint!, style: const TextStyle(fontSize: 11)),
    onTap: item.enabled ? onTap : null,
  );
}

enum DeleteScope { me, everyone }

class DeleteConfirmation extends StatefulWidget {
  const DeleteConfirmation({
    required this.canDeleteEveryone,
    this.disabledReason,
    this.count = 1,
    super.key,
  });
  final bool canDeleteEveryone;
  final String? disabledReason;
  final int count;
  @override
  State<DeleteConfirmation> createState() => _DeleteConfirmationState();
}

class _DeleteConfirmationState extends State<DeleteConfirmation> {
  DeleteScope? selected;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.count == 1
          ? 'Delete message?'
          : 'Delete ${widget.count} messages?',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected == DeleteScope.me,
            onChanged: (value) => setState(
              () => selected = value == true ? DeleteScope.me : null,
            ),
            title: const Text('Delete for me'),
            subtitle: const Text(
              'Hide this copy on this device. The other participant’s copy stays.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected == DeleteScope.everyone,
            onChanged: widget.canDeleteEveryone
                ? (value) => setState(
                    () =>
                        selected = value == true ? DeleteScope.everyone : null,
                  )
                : null,
            title: const Text('Delete for everyone'),
            subtitle: Text(
              widget.canDeleteEveryone
                  ? 'Send an encrypted deletion request. Confirmation waits for the recipient.'
                  : widget.disabledReason ??
                        'Only the sender can request shared deletion.',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Already seen, copied, exported or captured content cannot be recalled. Local deletion is logical; secure erasure of flash storage is not guaranteed.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: selected == null
            ? null
            : () => Navigator.pop(context, selected),
        child: const Text('Delete'),
      ),
    ],
  );
}

class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    required this.title,
    required this.text,
    this.onCancel,
    this.onTap,
    super.key,
  });
  final String title, text;
  final VoidCallback? onCancel, onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: 'Cancel',
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    ),
  );
}

class ConversationIdentityHeader extends StatelessWidget {
  const ConversationIdentityHeader({
    required this.name,
    required this.onTap,
    super.key,
  });
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary
                .withValues(alpha: .14),
            child: Text(
              name.characters.firstOrNull?.toUpperCase() ?? 'S',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );
}

class PinnedMessageIndicator extends StatelessWidget {
  const PinnedMessageIndicator({
    required this.text,
    required this.onTap,
    required this.onUnpin,
    super.key,
  });
  final String text;
  final VoidCallback onTap, onUnpin;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    minTileHeight: 48,
    leading: Icon(
      ShannonIconsRegular.pushPin,
      size: 18,
      color: Theme.of(context).colorScheme.primary,
    ),
    title: const Text(
      'Pinned on this device',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
    onTap: onTap,
    trailing: IconButton(
      tooltip: 'Unpin message on this device',
      onPressed: onUnpin,
      icon: const Icon(Icons.close, size: 17),
    ),
  );
}

class CompactMessageBubble extends StatelessWidget {
  const CompactMessageBubble({
    required this.message,
    required this.own,
    required this.contactName,
    required this.onTap,
    required this.onLongPress,
    this.onReplyTap,
    this.onReaction,
    this.anchorKey,
    this.highlight = false,
    super.key,
  });
  final GlobalKey? anchorKey;
  final Map<String, dynamic> message;
  final bool own, highlight;
  final String contactName;
  final VoidCallback onTap, onLongPress;
  final VoidCallback? onReplyTap;
  final ValueChanged<String>? onReaction;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deleted = message['deleted'] == true;
    final time = DateTime.fromMillisecondsSinceEpoch(
      message['timestamp'] as int,
    ).toLocal();
    final timestamp =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final state = message['state'];
    final preview = message['reply_preview'] as Map?;
    final changes = message['change_state'];
    final changeLabel = changes == null || changes == 'received'
        ? ''
        : changes == 'applied'
        ? 'Confirmed by recipient'
        : changes == 'queued'
        ? 'Change queued'
        : changes == 'failed'
        ? 'Change failed'
        : changes == 'expired'
        ? 'Change expired'
        : 'Waiting for recipient';
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: own
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Semantics(
              button: true,
              label:
                  '${own ? 'Your message' : contactName}. Open message actions',
              child: Container(
                key: anchorKey,
                constraints: BoxConstraints(
                  maxWidth: math.min(
                    520,
                    MediaQuery.sizeOf(context).width * .82,
                  ),
                ),
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.fromLTRB(11, 7, 10, 6),
                decoration: BoxDecoration(
                  color: own
                      ? scheme.primary.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.22
                              : 0.12,
                        )
                      : scheme.surfaceContainerHigh,
                  border: highlight ? Border.all(color: scheme.primary) : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(17),
                    topRight: const Radius.circular(17),
                    bottomLeft: Radius.circular(own ? 17 : 5),
                    bottomRight: Radius.circular(own ? 5 : 17),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message['forwarded'] == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Forwarded',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (preview != null && !deleted) ...[
                      ReplyPreview(
                        title: preview['own'] == true ? 'You' : contactName,
                        text: preview['text'] as String,
                        onTap: onReplyTap,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      deleted ? 'Message deleted' : message['text'] as String,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.3,
                        color: deleted
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontStyle: deleted ? FontStyle.italic : null,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message['edited'] == true && !deleted)
                          Text(
                            'edited · ',
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          timestamp,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (own) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: state == 'accepted'
                                ? 'Sent to server'
                                : state == 'queued'
                                ? 'Queued on this device'
                                : state == 'failed'
                                ? 'Failed to send'
                                : state == 'expired'
                                ? 'Expired'
                                : 'Saved',
                            child: Icon(
                              state == 'accepted'
                                  ? Icons.done
                                  : state == 'failed'
                                  ? Icons.error_outline
                                  : state == 'expired'
                                  ? Icons.timer_off_outlined
                                  : Icons.schedule,
                              size: 13,
                              color: state == 'failed'
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (changeLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          changeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if ((message['reactions'] as List? ?? []).isNotEmpty && !deleted)
            Wrap(
              spacing: 4,
              children: [
                for (final reaction in message['reactions'] as List)
                  Tooltip(
                    message: reaction['own'] != true
                        ? 'Contact reaction'
                        : reaction['state'] == 'queued'
                        ? 'Reaction queued on this device'
                        : reaction['state'] == 'applied'
                        ? 'Reaction confirmed by recipient'
                        : 'Reaction waiting for recipient',
                    child: InkWell(
                      onTap: onReaction == null
                          ? null
                          : () => onReaction!(reaction['emoji'] as String),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: reaction['own'] == true
                                ? scheme.primary.withValues(alpha: .14)
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            reaction['emoji'] as String,
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
