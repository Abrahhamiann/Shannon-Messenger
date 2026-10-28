import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/screen_privacy.dart';
import 'package:shannon/features/contacts/contact_screen.dart';

void main() {
  testWidgets(
    'opaque cover releases protection; pop reacquires; dialogs retain it',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final leases = <String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacyChannel, (call) async {
            if (call.method == 'acquire') leases.add(call.arguments as String);
            if (call.method == 'release') {
              leases.remove(call.arguments as String);
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(privacyChannel, null);
      });
      final observer = ScreenPrivacyObserver();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [observer],
          home: SensitiveScreen(
            observer: observer,
            child: const Scaffold(body: Text('private')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(leases.length, 1);
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('public')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(leases, isEmpty);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(leases.length, 1);
      unawaited(
        showDialog<void>(
          context: tester.element(find.text('private')),
          builder: (_) => const AlertDialog(content: Text('overlay')),
        ),
      );
      await tester.pumpAndSettle();
      expect(leases.length, 1);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(leases, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  test('invite parsing rejects alternate origins, credentials, query and malformed capabilities', () {
    final token = 'A' * 43;
    expect(invitationToken(invitationLink(token)), token);
    for (final value in [
      'https://evil/v1#$token',
      'shannon://invite/other#$token',
      'shannon://x@invite/v1#$token',
      'shannon://invite:80/v1#$token',
      'shannon://invite/v1?q=x#$token',
      'shannon://invite/v1#short',
    ]) {
      expect(invitationToken(value), isNull);
    }
  });
  testWidgets(
    'sensitive content waits for Android acknowledgement; release follows disposal',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final acquire = Completer<void>();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacyChannel, (call) async {
            calls.add(call.method);
            if (call.method == 'acquire') await acquire.future;
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(privacyChannel, null);
      });
      await tester.pumpWidget(
        const MaterialApp(home: SensitiveScreen(child: Text('private'))),
      );
      expect(find.text('private'), findsNothing);
      acquire.complete();
      await tester.pumpAndSettle();
      expect(find.text('private'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: Text('public')));
      await tester.pump();
      expect(calls, ['acquire', 'release']);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('platform failure never renders sensitive content', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(privacyChannel, (call) async {
          throw PlatformException(code: 'unavailable');
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacyChannel, null);
    });
    await tester.pumpWidget(
      const MaterialApp(home: SensitiveScreen(child: Text('private'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('private'), findsNothing);
    expect(find.textContaining('Sensitive content is hidden'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}
