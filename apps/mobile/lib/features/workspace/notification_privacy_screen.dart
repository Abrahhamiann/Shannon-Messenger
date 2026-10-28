import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/design_system.dart';

enum NotificationPreview { contentHidden, senderOnly, anonymous, disabled }

class NotificationPrivacyScreen extends StatefulWidget {
  const NotificationPrivacyScreen({super.key});
  @override
  State<NotificationPrivacyScreen> createState() =>
      _NotificationPrivacyScreenState();
}

class _NotificationPrivacyScreenState extends State<NotificationPrivacyScreen> {
  NotificationPreview selected = NotificationPreview.anonymous;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await SharedPreferencesAsync().getString(
        'notification_preview_v1',
      );
      if (mounted) {
        setState(
          () => selected = NotificationPreview.values.firstWhere(
            (e) => e.name == value,
            orElse: () => NotificationPreview.anonymous,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load your preference.');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> select(NotificationPreview value) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await SharedPreferencesAsync().setString(
        'notification_preview_v1',
        value.name,
      );
      if (mounted) setState(() => selected = value);
    } catch (_) {
      if (mounted) setState(() => error = 'Preference was not saved. Retry.');
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification privacy')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ShannonPanel(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Saved preference for future messaging. This build does not deliver message notifications or request notification permission.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        for (final option in [
          (
            NotificationPreview.contentHidden,
            'Hide message content on lock screen',
          ),
          (NotificationPreview.senderOnly, 'Show sender name only'),
          (NotificationPreview.anonymous, 'Hide sender and content'),
          (NotificationPreview.disabled, 'Disable previews entirely'),
        ])
          ListTile(
            title: Text(option.$2),
            selected: selected == option.$1,
            leading: Icon(
              selected == option.$1
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            onTap: loading ? null : () => select(option.$1),
          ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        const SizedBox(height: 24),
        const Text(
          'Android and your notification-channel settings also control what appears on the lock screen. Shannon cannot override stricter system settings. No fake notifications are generated.',
        ),
      ],
    ),
  );
}
