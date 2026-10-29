import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/screen_privacy.dart';
import 'package:shannon/app/theme.dart';
import 'package:shannon/features/contacts/contact_preferences.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/messaging/messaging_controller.dart';
import 'package:shannon/features/messaging/private_conversation.dart';

import 'identity_fixture.dart';

const peer = 'shn1_test_peer', owner = 'shn1_test_owner';
Map<String, dynamic> ownMessage() => {
  'id': 'own-message',
  'sender': owner,
  'sender_device': 'dev1_test_owner',
  'text': 'My original text',
  'timestamp': 1,
  'local_row': 2,
  'state': 'accepted',
  'reactions': [],
};
Map<String, dynamic> receivedMessage() => {
  'id': 'peer-message',
  'sender': peer,
  'sender_device': 'dev1_test_peer',
  'text': 'A received message',
  'timestamp': 1,
  'local_row': 1,
  'state': 'received',
  'reactions': [],
};
Map<String, dynamic> conversation() => {
  'binding': {'account': peer},
  'label': '@test_peer',
  'last': ownMessage(),
};

class _Preferences extends ContactPreferences {
  @override
  Future<Map<String, dynamic>> build() async => {};
}

class _Repository extends FixtureRepository {
  @override
  Future<Map<String, dynamic>> contactRequest(
    String method,
    String operation, [
    Map<String, dynamic>? body,
  ]) async => {
    'items': [
      {'id': peer, 'kind': 'accepted', 'username': 'test_peer'},
    ],
    'next': '',
  };
}

class _Messaging extends MessagingController {
  final sent = <Map<String, dynamic>>[], local = <Map<String, dynamic>>[];
  void refresh() => state = MessagingView(
    ready: true,
    revision: state.revision + 1,
    conversations: [conversation()],
  );
  @override
  MessagingView build() =>
      MessagingView(ready: true, conversations: [conversation()]);
  @override
  String? get ownAccount => owner;
  @override
  Future<void> openPeer(String account, {String? label}) async {}
  @override
  Future<void> queue(String account, Map<String, dynamic> content) async {
    sent.add({'account': account, ...content});
    refresh();
  }

  @override
  Future<void> localAction(
    String account,
    String op,
    Map<String, dynamic> message, {
    bool? value,
  }) async {
    local.add({'op': op, 'target': messageReference(message), 'value': value});
    refresh();
  }

  @override
  Future<void> deleteMessages(
    String account,
    List<Map<String, dynamic>> messages, {
    required bool everyone,
  }) async {
    for (final m in messages) {
      if (everyone) {
        sent.add({'kind': 'delete', 'target': messageReference(m)});
      } else {
        local.add({'op': 'local_delete', 'target': messageReference(m)});
      }
    }
    refresh();
  }
}

void main() {
  late ProviderContainer container;
  late _Messaging service;
  String? copied;
  Completer<String>? heldHistory;
  Completer<String>? heldPeer;
  Future<void> mount(WidgetTester tester) async {
    heldHistory = null;
    heldPeer = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(privacyChannel, (call) async {
      if (call.method == 'copyPrivate') copied = call.arguments as String;
      return null;
    });
    messenger.setMockMethodCallHandler(messagingChannel, (call) async {
      final request = jsonDecode(call.arguments as String) as Map;
      if (request['op'] == 'history') {
        if (heldHistory != null) return heldHistory!.future;
        return jsonEncode({
          'items': [ownMessage(), receivedMessage()],
        });
      }
      if (request['op'] == 'peer') {
        if (heldPeer != null) return heldPeer!.future;
        return jsonEncode({
          'label': '@test_peer',
          'interactions': true,
          'binding': {'account': peer},
        });
      }
      return '{}';
    });
    service = _Messaging();
    container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(_Repository()),
        identityControllerProvider.overrideWith(
          AuthenticatedIdentityController.new,
        ),
        contactPreferencesProvider.overrideWith(_Preferences.new),
        messagingProvider.overrideWith(() => service),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ShannonTheme.dark,
          home: const PrivateConversationScreen(account: peer),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() {
      container.dispose();
      messenger.setMockMethodCallHandler(privacyChannel, null);
      messenger.setMockMethodCallHandler(messagingChannel, null);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets(
    'history refresh retains the mounted bubbles while a new native read is pending',
    (tester) async {
      await mount(tester);
      final originalElement = tester.element(find.text('My original text'));
      final pending = Completer<String>();
      heldHistory = pending;
      final peerPending = Completer<String>();
      heldPeer = peerPending;
      service.refresh();
      await tester.pump();
      await tester.pump();
      expect(
        tester.element(find.text('My original text')),
        same(originalElement),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('@test_peer'), findsOneWidget);
      expect(find.text('Private contact'), findsNothing);
      await tester.tap(find.text('My original text'));
      await tester.pumpAndSettle();
      heldHistory = null;
      heldPeer = null;
      peerPending.complete(
        jsonEncode({
          'label': '@test_peer',
          'interactions': true,
          'binding': {'account': peer},
        }),
      );
      pending.complete(
        jsonEncode({
          'items': [ownMessage(), receivedMessage()],
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await finish(tester);
    },
  );
  testWidgets(
    'recipient header, tap reply, reference and cancel editing are real dispatches',
    (tester) async {
      await mount(tester);
      expect(find.text('@test_peer'), findsOneWidget);
      expect(find.text('Private conversation'), findsNothing);
      expect(find.textContaining('Compare fingerprints'), findsNothing);
      await tester.tap(find.text('A received message'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.text('Reply to @test_peer'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'Reply body');
      await tester.tap(find.byTooltip('Send encrypted message'));
      await tester.pumpAndSettle();
      expect(service.sent.single['reply'], messageReference(receivedMessage()));
      expect(service.sent.single['text'], 'Reply body');
      await tester.tap(find.text('My original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Editing message'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'Changed text');
      await tester.tap(find.byTooltip('Save encrypted edit'));
      await tester.pumpAndSettle();
      expect(service.sent.last['kind'], 'edit');
      expect(service.sent.last['target'], messageReference(ownMessage()));
      expect(service.sent.last['text'], 'Changed text');
      await finish(tester);
    },
  );
  testWidgets(
    'copy passes only decrypted text to the native sensitive clipboard',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('My original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, 'My original text');
      expect(
        find.text('Copied. Your clipboard may retain this text.'),
        findsOneWidget,
      );
      await finish(tester);
    },
  );
  testWidgets('local pin and delete scopes call distinct operations', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('My original text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin'));
    await tester.pumpAndSettle();
    expect(service.local.single['op'], 'pin');
    expect(service.local.single['value'], true);
    await tester.tap(find.text('A received message'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    final everyone = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .last;
    expect(everyone.onChanged, isNull);
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.local.last['op'], 'local_delete');
    expect(service.sent, isEmpty);
    await tester.tap(find.text('My original text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.sent.single['kind'], 'delete');
    expect(service.sent.single['target'], messageReference(ownMessage()));
    await finish(tester);
  });
  testWidgets(
    'forward selects and confirms an eligible destination and sends new content only',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('A received message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forward'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('@test_peer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Forward to @test_peer?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Forward'));
      await tester.pumpAndSettle();
      expect(service.sent.single, {
        'account': peer,
        'text': 'A received message',
        'forwarded': true,
      });
      await finish(tester);
    },
  );
  testWidgets(
    'long press selects multiple messages and mixed ownership disables remote deletion',
    (tester) async {
      await mount(tester);
      await tester.longPress(find.text('My original text'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
      await tester.tap(find.text('A received message'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete selected messages'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .last
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('Delete for me'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(service.local.length, 2);
      expect(service.sent, isEmpty);
      expect(find.text('2 selected'), findsNothing);
      await finish(tester);
    },
  );
  testWidgets(
    'selected messages forward as separate new encrypted sends after recipient confirmation',
    (tester) async {
      await mount(tester);
      await tester.longPress(find.text('My original text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A received message'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Forward selected messages'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('@test_peer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Forward 2 messages to @test_peer?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Forward'));
      await tester.pumpAndSettle();
      expect(service.sent.map((m) => m['text']), [
        'A received message',
        'My original text',
      ]);
      expect(
        service.sent.every(
          (m) => m['forwarded'] == true && !m.containsKey('sender'),
        ),
        isTrue,
      );
      await finish(tester);
    },
  );
}
