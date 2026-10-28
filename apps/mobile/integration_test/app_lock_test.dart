import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shannon/app/screen_privacy.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'physical device authentication enables, unlocks and disables isolated App Lock',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Shannon App Lock validation\nComplete the device prompts.\nThe normal Shannon app is unchanged.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = await privacyChannel.invokeMapMethod<String, dynamic>(
        'appLockState',
      );
      expect(
        before?['available'],
        true,
        reason: 'A secure device screen lock is required.',
      );
      expect(
        before?['enabled'],
        false,
        reason: 'This test starts with the isolated validation lock disabled.',
      );
      await privacyChannel.invokeMethod<void>('configureAppLock', {
        'enabled': true,
        'seconds': 0,
      });
      expect(
        (await privacyChannel.invokeMapMethod<String, dynamic>(
          'appLockState',
        ))?['enabled'],
        true,
      );
      await privacyChannel.invokeMethod<void>('lockNow');
      expect(
        (await privacyChannel.invokeMapMethod<String, dynamic>(
          'appLockState',
        ))?['locked'],
        true,
      );
      expect(await privacyChannel.invokeMethod<bool>('isProtected'), true);
      var unlocked = false;
      for (var attempt = 0; attempt < 90; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if ((await privacyChannel.invokeMapMethod<String, dynamic>(
              'appLockState',
            ))?['locked'] ==
            false) {
          unlocked = true;
          break;
        }
      }
      expect(
        unlocked,
        true,
        reason: 'Tap Unlock and complete device authentication on the phone.',
      );
      await privacyChannel.invokeMethod<void>('configureAppLock', {
        'enabled': false,
        'seconds': 0,
      });
      expect(
        (await privacyChannel.invokeMapMethod<String, dynamic>(
          'appLockState',
        ))?['enabled'],
        false,
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
