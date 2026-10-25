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
  testWidgets('UI authentication state expires without background polling', (
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
    expect(find.text('expired'), findsOneWidget);
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
      await tester.scrollUntilVisible(
        find.text('Create Private Identity'),
        200,
      );
      await tester.tap(find.text('Create Private Identity'));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(
        FilledButton,
        'Generate local identity',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Identity saved on this device'), findsOneWidget);
      await tester.tap(find.text('Connect and authenticate'));
      await tester.pumpAndSettle();
      expect(find.text('Authenticated with Shannon'), findsNothing);
      expect(store.values.containsKey(IdentityRepository.identityKey), isTrue);
      await tester.tap(find.text('Restore Identity'));
      await tester.pumpAndSettle();
      expect(find.text('Recovery is not available yet'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
