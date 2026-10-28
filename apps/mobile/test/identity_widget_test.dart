import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';

import 'identity_test.dart' show MemoryStore;

class ExpiringRepository extends IdentityRepository {
  ExpiringRepository(super.store, super.client);
  @override
  Future<IdentityView> resume() async => IdentityView(
    IdentityStage.authenticated,
    id: 'test-public-id',
    deviceId: 'test-device-id',
    validUntil: DateTime.now().add(const Duration(seconds: 1)),
  );
}

void main() {
  testWidgets('normal startup and form edits never authorize signup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryStore();
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('', 503);
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            IdentityRepository(store, client),
          ),
        ],
        child: const ShannonApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(store.values, isEmpty);
    expect(requests, 0);
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    final button = find.widgetWithText(FilledButton, 'Create account');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'Manual name');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 5));
    expect(store.values, isEmpty);
    expect(requests, 0);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(store.values, isEmpty);
    expect(requests, 0);
  });
  testWidgets('UI authentication renews at expiry without background polling', (
    tester,
  ) async {
    final client = MockClient((_) async => http.Response('', 500));
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityRepositoryProvider.overrideWithValue(
            ExpiringRepository(MemoryStore(), client),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (_, ref, _) {
              final view = ref.watch(identityControllerProvider).asData?.value;
              return Text(view?.stage.name ?? 'loading');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('authenticated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('authenticated'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'explicit consent, local creation, offline state and unavailable recovery',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final store = MemoryStore();
      final client = MockClient((_) async => http.Response('', 503));
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityRepositoryProvider.overrideWithValue(
              IdentityRepository(store, client),
            ),
          ],
          child: const ShannonApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'New account');
      final button = find.widgetWithText(FilledButton, 'Create account');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.textContaining('Server did not accept'), findsOneWidget);
      expect(find.text('Search Chats'), findsNothing);
      expect(store.values.containsKey(IdentityRepository.identityKey), isTrue);
      final saved = store.values[IdentityRepository.identityKey];
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(store.values[IdentityRepository.identityKey], saved);
    },
  );
}
