import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/app/screen_privacy.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/messaging/messaging_controller.dart';

const _account = 'shn1_unit_test_peer';
const _privateText = 'PRIVATE_UNIT_TEST_CONTENT';

class _AuthenticatedIdentity extends IdentityController {
  @override
  Future<IdentityView> build() async => const IdentityView(
    IdentityStage.authenticated,
    id: 'shn1_unit_test_owner',
    deviceId: 'dev1_unit_test_owner',
  );
}

class _ReadyMessaging extends MessagingController {
  @override
  MessagingView build() => const MessagingView(
    ready: true,
    conversations: [
      {
        'binding': {'account': _account},
        'label': '@unit_test_peer',
        'last': {'text': _privateText, 'timestamp': 1},
      },
    ],
  );
  @override
  Future<void> openPeer(String account, {String? label}) async {}
}

void main() {
  testWidgets(
    'enabled M4 shell stays visible and plaintext only opens behind capture protection',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final leases = <String>{};
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(privacyChannel, (call) async {
        if (call.method == 'acquire') leases.add(call.arguments as String);
        if (call.method == 'release') leases.remove(call.arguments as String);
        return null;
      });
      messenger.setMockMethodCallHandler(messagingChannel, (call) async {
        final request = jsonDecode(call.arguments as String) as Map;
        if (request['op'] == 'history') {
          return jsonEncode({
            'items': [
              {
                'text': _privateText,
                'id': 'unit-message',
                'sender': _account,
                'sender_device': 'dev1_unit_test_peer',
                'timestamp': 1,
                'state': 'received',
                'local_row': 1,
              },
            ],
          });
        }
        return '{}';
      });
      final container = ProviderContainer(
        overrides: [
          identityControllerProvider.overrideWith(_AuthenticatedIdentity.new),
          messagingProvider.overrideWith(_ReadyMessaging.new),
        ],
      );
      addTearDown(() {
        container.dispose();
        messenger.setMockMethodCallHandler(privacyChannel, null);
        messenger.setMockMethodCallHandler(messagingChannel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShannonApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('@unit_test_peer'), findsOneWidget);
      expect(
        find.text('Encrypted message · Open conversation'),
        findsOneWidget,
      );
      expect(find.text(_privateText), findsNothing);
      expect(leases, isEmpty);
      await tester.tap(find.text('@unit_test_peer'));
      await tester.pumpAndSettle();
      expect(find.text(_privateText), findsOneWidget);
      expect(leases, hasLength(1));
      container.read(routerProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(find.text(_privateText), findsNothing);
      expect(leases, isEmpty);
      container.read(routerProvider).go('/chats');
      await tester.pumpAndSettle();
      expect(find.text('@unit_test_peer'), findsOneWidget);
      expect(find.text(_privateText), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
    skip: !m4MessagingEnabled,
  );
}
