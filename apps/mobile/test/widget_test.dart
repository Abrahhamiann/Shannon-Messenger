import 'identity_fixture.dart';

import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/core/api/health_api.dart';

void main() {
  testWidgets('navigation, theme, and backend health contract', (tester) async {
    final client = MockClient(
      (_) async => http.Response(
        '{"status":"ok","database":"up","service":"shannon-api"}',
        200,
      ),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityControllerProvider.overrideWith(
            AuthenticatedIdentityController.new,
          ),
          healthApiProvider.overrideWithValue(
            HealthApi(client, 'http://localhost:8080'),
          ),
        ],
        child: const ShannonApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Shannon'), findsWidgets);
    expect(find.text('Chats'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Light'), 250);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Light'))).brightness,
      Brightness.light,
    );

    await tester.scrollUntilVisible(find.text('Backend connection'), 200);
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backend connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to Shannon'), findsOneWidget);
  });

  testWidgets('failed connection can be retried', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var attempts = 0;
    final client = MockClient(
      (_) async => ++attempts == 1
          ? http.Response('', 503)
          : http.Response(
              '{"status":"ok","database":"up","service":"shannon-api"}',
              200,
            ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityControllerProvider.overrideWith(
            AuthenticatedIdentityController.new,
          ),
          healthApiProvider.overrideWithValue(
            HealthApi(client, 'http://localhost:8080'),
          ),
        ],
        child: const ShannonApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Backend connection'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backend connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to Shannon'), findsOneWidget);
  });
}
