import '../../l10n/strings.dart';

import 'package:flutter/material.dart';

import '../../app/design_system.dart';
import '../../app/screen_privacy.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});
  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool enabled = false, available = false, busy = true;
  int seconds = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final state = await privacyChannel.invokeMapMethod<String, dynamic>(
        'appLockState',
      );
      if (mounted) {
        setState(() {
          enabled = state?['enabled'] == true;
          available = state?['available'] == true;
          seconds = state?['seconds'] as int? ?? 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'App Lock requires a supported Android device.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> change(bool value, int timeout) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await privacyChannel.invokeMethod<void>('configureAppLock', {
        'enabled': value,
        'seconds': timeout,
      });
      await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Device authentication was cancelled or settings could not be saved. Your previous setting is unchanged.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(strings(context).appLock)),
    body: ListView(
      padding: EdgeInsets.all(24),
      children: [
        Text(strings(context).lockDescription),
        SizedBox(height: 24),
        ShannonPanel(
          child: SwitchListTile(
            title: Text(strings(context).enableAppLock),
            value: enabled,
            subtitle: Text(
              available
                  ? strings(context).lockLaunch
                  : strings(context).setDeviceLock,
            ),
            onChanged: busy || !available ? null : (v) => change(v, seconds),
          ),
        ),
        SizedBox(height: 24),
        Text(strings(context).lockAfter),
        SizedBox(height: 12),
        for (final option in [
          (0, strings(context).immediately),
          (30, strings(context).thirtySeconds),
          (60, strings(context).oneMinute),
          (300, strings(context).fiveMinutes),
        ])
          ListTile(
            title: Text(option.$2),
            leading: Icon(
              seconds == option.$1
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            selected: seconds == option.$1,
            enabled: enabled && !busy,
            onTap: enabled && !busy ? () => change(true, option.$1) : null,
          ),
        if (busy) LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(error!, semanticsLabel: error),
          ),
        SizedBox(height: 24),
        FilledButton(
          onPressed: !enabled || busy
              ? null
              : () async {
                  try {
                    await privacyChannel.invokeMethod<void>('lockNow');
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error = 'Unable to lock. Please restart Shannon.',
                      );
                    }
                  }
                },
          child: Text(strings(context).lockNow),
        ),
      ],
    ),
  );
}
