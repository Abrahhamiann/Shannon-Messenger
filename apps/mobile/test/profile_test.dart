import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/identity/presentation/profile_page.dart';

import 'identity_test.dart' show MemoryStore;

void main() {
  test(
    'nickname survives reload, never changes identity or makes HTTP requests',
    () async {
      final store = MemoryStore();
      final client = MockClient(
        (_) async => throw StateError('Unexpected HTTP'),
      );
      addTearDown(client.close);
      final repository = IdentityRepository(store, client);
      final initial = await repository.create('Before');
      final before =
          jsonDecode(store.values[IdentityRepository.identityKey]!) as Map;
      await repository.updateNickname('  Շենոն · Шеннон  ');
      final after =
          jsonDecode(store.values[IdentityRepository.identityKey]!) as Map;
      expect(after['root_seed'], before['root_seed']);
      expect(after['device_seed'], before['device_seed']);
      expect(after['registered'], before['registered']);
      final loaded = await IdentityRepository(store, client).resume();
      expect(loaded.id, initial.id);
      expect(loaded.nickname, 'Շենոն · Шеннон');
      await expectLater(
        repository.updateNickname('x' * 65),
        throwsA(isA<IdentityFailure>()),
      );
      expect(store.values[IdentityRepository.identityKey], jsonEncode(after));
    },
  );

  test(
    'controller reports failed operations without claiming logout succeeded',
    () async {
      final store = MemoryStore();
      final client = MockClient((_) async => http.Response('', 503));
      addTearDown(client.close);
      final repository = IdentityRepository(store, client);
      await repository.create('Test');
      await store.write(
        IdentityRepository.sessionKey,
        jsonEncode({'refresh_token': encode64(List.filled(32, 1))}),
      );
      final before = store.values[IdentityRepository.identityKey];
      final container = ProviderContainer(
        overrides: [identityRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await container.read(identityControllerProvider.future);
      final success = await container
          .read(identityControllerProvider.notifier)
          .run((r) => r.logout());
      expect(success, isFalse);
      expect(store.values[IdentityRepository.identityKey], before);
    },
  );

  testWidgets('logout requires confirmation and displays failure', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShannonProfilePage(
          onLogout: () async {
            calls++;
            throw StateError('private error');
          },
          sessionLabel: 'Session verified',
          canLogout: true,
          onEdit: () {},
          onDevices: () {},
          onSecurity: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Log Out'), 250);
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(
      find.text('Could not complete logout. Please retry.'),
      findsOneWidget,
    );
    expect(find.textContaining('private error'), findsNothing);
  });
}
