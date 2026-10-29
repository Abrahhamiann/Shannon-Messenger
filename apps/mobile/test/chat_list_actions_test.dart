import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/features/workspace/chat_search.dart';
import 'package:shannon/features/messaging/messaging_controller.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';

import 'identity_fixture.dart';

class _Chats extends MessagingController {
  final actions = <Map<String, dynamic>>[];
  @override
  MessagingView build() => const MessagingView(ready: true);
  @override
  Future<void> chatAction(
    String account,
    String op, {
    bool? pinned,
    bool? archived,
  }) async {
    actions.add({
      'account': account,
      'op': op,
      'pinned': pinned,
      'archived': archived,
    });
  }
}

class _Contacts extends FixtureRepository {
  final requests = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> contactRequest(
    String method,
    String operation, [
    Map<String, dynamic>? body,
  ]) async {
    requests.add({'method': method, 'operation': operation, 'body': body});
    return {};
  }
}

void main() {
  testWidgets(
    'chat long press dispatches local pin/archive/delete and authenticated block with honest remote-deletion scope',
    (tester) async {
      final service = _Chats(), repo = _Contacts();
      final container = ProviderContainer(
        overrides: [
          messagingProvider.overrideWith(() => service),
          identityRepositoryProvider.overrideWithValue(repo),
          localConversationsProvider.overrideWithValue(const [
            LocalConversation(id: 'test-peer', nickname: 'Test peer'),
          ]),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: ChatSearch())),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'peer');
      await tester.pumpAndSettle();
      Future<void> open() async {
        await tester.longPress(find.text('Test peer'));
        await tester.pumpAndSettle();
      }

      await open();
      expect(find.text('Delete chat'), findsOneWidget);
      final both = tester.widget<ListTile>(
        find
            .ancestor(
              of: find.text('Delete chat for both participants'),
              matching: find.byType(ListTile),
            )
            .first,
      );
      expect(both.enabled, isFalse);
      await tester.tap(find.text('Pin chat'));
      await tester.pumpAndSettle();
      expect(service.actions.last['pinned'], true);
      await open();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(service.actions.last['archived'], true);
      await open();
      await tester.tap(find.text('Delete chat'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('other participant’s copies stay'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(service.actions.last['op'], 'delete_chat');
      await open();
      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(repo.requests.single, {
        'method': 'POST',
        'operation': '/block',
        'body': {'target': 'test-peer'},
      });
    },
  );
}
