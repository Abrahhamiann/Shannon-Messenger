import 'package:flutter/material.dart';

import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/widgets.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Conversation', style: TextStyle(fontSize: 19)),
          Text(
            'Messaging unavailable',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: FeatureNotice(
                icon: ShannonIconsRegular.chatsCircle,
                title: 'A conversation needs trust.',
                message: 'Private contact exchange and encrypted messaging are not implemented yet. This screen contains no messages and cannot send anything.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: ShannonPanel(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Attachment options (unavailable)',
                      onPressed: () => _attachments(context),
                      icon: const Icon(ShannonIconsRegular.plus),
                    ),
                    const Expanded(
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: 'Messaging unavailable',
                          border: InputBorder.none,
                        ),
                        maxLines: 4,
                        minLines: 1,
                      ),
                    ),
                    const IconButton(
                      tooltip: 'Send unavailable',
                      onPressed: null,
                      icon: Icon(ShannonIconsRegular.paperPlaneTilt),
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

  void _attachments(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share something',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Attachments are unavailable until encrypted messaging is implemented.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                for (final item in [
                  (ShannonIconsRegular.image, 'Photo'),
                  (ShannonIconsRegular.file, 'File'),
                  (ShannonIconsRegular.microphone, 'Voice'),
                ])
                  SizedBox(
                    width: 80,
                    child: Column(
                      children: [
                        IconButton.filledTonal(
                          onPressed: null,
                          tooltip: '${item.$2} unavailable',
                          icon: Icon(item.$1),
                        ),
                        const SizedBox(height: 8),
                        Text(item.$2),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
