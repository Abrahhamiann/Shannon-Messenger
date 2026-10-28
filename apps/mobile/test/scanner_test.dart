import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/screen_privacy.dart';
import 'package:shannon/features/contacts/contact_screen.dart';

void main() {
  for (final outcome in ['cancel', 'denied', 'invalid', 'unavailable']) {
    testWidgets('scanner $outcome is explicit and repeatable', (tester) async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacyChannel, (call) async {
            expect(call.method, 'scanInvite');
            calls++;
            switch (outcome) {
              case 'cancel':
                return null;
              case 'denied':
                throw PlatformException(code: 'permission_denied');
              case 'invalid':
                return 'https://example.invalid';
              default:
                throw PlatformException(code: 'camera_unavailable');
            }
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(privacyChannel, null),
      );
      await tester.pumpWidget(const MaterialApp(home: ContactScanner()));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Open app settings'), findsOneWidget);
      await tester.tap(find.text('Start scanning'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  }
  testWidgets('closing Flutter route while native scanner is pending is safe', (
    tester,
  ) async {
    final pending = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (_) => pending.future);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacyChannel, null),
    );
    await tester.pumpWidget(const MaterialApp(home: ContactScanner()));
    await tester.tap(find.text('Start scanning'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(null);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
