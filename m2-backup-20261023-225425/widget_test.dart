import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/core/api/health_api.dart';

void main() {
  Future<void> setTestScreenSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> tapVisible(
    WidgetTester tester,
    Finder finder,
  ) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'navigation, theme, and real-contract connection',
    (tester) async {
      await setTestScreenSize(tester);

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
            healthApiProvider.overrideWithValue(
              HealthApi(client, 'http://localhost:8080'),
            ),
          ],
          child: const ShannonApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Open Shannon
      await tapVisible(
        tester,
        find.text('Open Shannon'),
      );

      expect(
        find.text('Your conversations will appear here.'),
        findsOneWidget,
      );

      // Navigate to Settings
      await tapVisible(
        tester,
        find.text('Settings'),
      );

      // Switch to light theme
      await tapVisible(
        tester,
        find.text('Light'),
      );

      expect(
        Theme.of(
          tester.element(find.text('Appearance')),
        ).brightness,
        Brightness.light,
      );

      // Check real API contract using mocked HTTP response
      await tapVisible(
        tester,
        find.text('Backend connection'),
      );

      expect(
        find.text('Connected to Shannon'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'failed connection can be retried',
    (tester) async {
      await setTestScreenSize(tester);

      var attempts = 0;

      final client = MockClient(
        (_) async {
          attempts++;

          if (attempts == 1) {
            return http.Response('', 503);
          }

          return http.Response(
            '{"status":"ok","database":"up","service":"shannon-api"}',
            200,
          );
        },
      );

      addTearDown(client.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthApiProvider.overrideWithValue(
              HealthApi(client, 'http://localhost:8080'),
            ),
          ],
          child: const ShannonApp(),
        ),
      );

      await tester.pumpAndSettle();

      // First connection attempt should fail
      await tapVisible(
        tester,
        find.text('Check backend connection'),
      );

      expect(
        find.text('Connection unavailable'),
        findsOneWidget,
      );

      expect(attempts, 1);

      // Retry should succeed
      await tapVisible(
        tester,
        find.text('Check again'),
      );

      expect(
        find.text('Connected to Shannon'),
        findsOneWidget,
      );

      expect(attempts, 2);
    },
  );
}
