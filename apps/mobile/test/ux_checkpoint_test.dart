import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/workspace/chat_search.dart';

import 'identity_test.dart' show MemoryStore;

class FixedIdentity extends IdentityController {
  FixedIdentity(this.view);
  final IdentityView view;
  @override
  Future<IdentityView> build() async => view;
  void change(IdentityView value) => state = AsyncData(value);
}

class SearchRepository extends IdentityRepository {
  SearchRepository() : super(MemoryStore(), http.Client());
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> contactRequest(
    String method,
    String operation, [
    Map<String, dynamic>? body,
  ]) async {
    calls.add(operation);
    if (operation == '/request') return {'kind': 'outgoing'};
    return {
      'id': 'peer',
      'username': body!['username'].toString().substring(1),
    };
  }
}

class DeleteFailureStore extends MemoryStore {
  @override
  Future<void> delete(String key) async {
    if (key == IdentityRepository.sessionKey) {
      throw StateError('delete failure');
    }
    await super.delete(key);
  }
}

void main() {
  for (final offline in [false, true]) {
    test('logout $offline preserves account across restart', () async {
      final store = MemoryStore();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/v1/auth/logout');
        expect(jsonDecode(request.body)['refresh_token'], 'refresh');
        if (offline) throw http.ClientException('offline');
        return http.Response('', 204);
      });
      final repo = IdentityRepository(store, client);
      await repo.create('Saved name');
      final identity = store.values[IdentityRepository.identityKey];
      store.values['avatar_v1'] = 'saved-photo';
      await store.write(
        IdentityRepository.sessionKey,
        jsonEncode({
          'refresh_token': 'refresh',
          'access_expires_at': '2020-01-01T00:00:00Z',
        }),
      );
      if (offline) {
        await expectLater(repo.logout(), throwsA(isA<http.ClientException>()));
        expect(store.values[IdentityRepository.sessionKey], isNotNull);
        await repo.signOutLocally();
      } else {
        await repo.logout();
      }
      expect(store.values[IdentityRepository.sessionKey], isNull);
      expect(
        (await IdentityRepository(store, client).resume()).stage,
        IdentityStage.local,
      );
      expect(requests, 1);
      expect(store.values[IdentityRepository.identityKey], identity);
      expect(store.values['avatar_v1'], 'saved-photo');
      client.close();
    });
  }
  test('durable marker denies stale tokens when deletion fails', () async {
    final store = DeleteFailureStore();
    final client = MockClient(
      (_) async => throw StateError('No network permitted'),
    );
    final repo = IdentityRepository(store, client);
    await repo.create('Saved');
    await store.write(IdentityRepository.sessionKey, 'stale');
    await expectLater(repo.signOutLocally(), throwsStateError);
    expect(
      (await IdentityRepository(store, client).resume()).stage,
      IdentityStage.local,
    );
    client.close();
  });
  for (final stage in [
    IdentityStage.none,
    IdentityStage.local,
    IdentityStage.authenticated,
    IdentityStage.offline,
    IdentityStage.revoked,
    IdentityStage.storageUnavailable,
  ]) {
    testWidgets('startup routes $stage truthfully', (tester) async {
      final controller = FixedIdentity(
        IdentityView(stage, id: stage == IdentityStage.none ? null : 'self'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityControllerProvider.overrideWith(() => controller),
          ],
          child: const ShannonApp(),
        ),
      );
      await tester.pumpAndSettle();
      if (stage == IdentityStage.none) {
        expect(find.text('Sign Up'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Already Have an Account?'),
          200,
        );
        expect(find.text('Already Have an Account?'), findsOneWidget);
        expect(find.text('Open Shannon'), findsNothing);
      } else if (stage == IdentityStage.authenticated) {
        expect(find.text('Search Chats'), findsOneWidget);
        controller.change(const IdentityView(IdentityStage.local, id: 'self'));
        await tester.pumpAndSettle();
        expect(
          find.text('Continue with identity on this device'),
          findsOneWidget,
        );
      } else {
        expect(find.text('Your account'), findsOneWidget);
      }
    });
  }
  test('local filtering by nickname username and group', () {
    const chats = [
      LocalConversation(id: '1', nickname: 'Anna', username: 'anna_84'),
      LocalConversation(id: '2', nickname: '', groupName: 'Family'),
    ];
    expect(filterLocalChats(chats, 'ANNA').single.id, '1');
    expect(filterLocalChats(chats, 'family').single.id, '2');
    expect(filterLocalChats(chats, 'missing'), isEmpty);
  });
  testWidgets('Search Chats never sends local queries to the server', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = SearchRepository();
    addTearDown(repo.client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          identityControllerProvider.overrideWith(
            () => FixedIdentity(
              const IdentityView(IdentityStage.authenticated, id: 'self'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ChatSearch())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'anna');
    await tester.pump(const Duration(seconds: 1));
    expect(repo.calls, isEmpty);
    await tester.enterText(find.byType(TextField), '@ann');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), '@anna_84');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.text('No existing chats match.'), findsOneWidget);
    expect(find.text('Send Contact Request'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No existing chats match.'), findsNothing);
  });
}
