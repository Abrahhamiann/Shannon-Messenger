import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/core/api/health_api.dart';

void main() {
  testWidgets('navigation, theme, and real-contract connection', (
    tester,
  ) async {
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
    await tester.tap(find.text('Open Shannon'));
    await tester.pumpAndSettle();
    expect(find.text('Your conversations will appear here.'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.light,
    );
    await tester.tap(find.text('Backend connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to Shannon'), findsOneWidget);
  });
  testWidgets('failed connection can be retried', (tester) async {
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
          healthApiProvider.overrideWithValue(
            HealthApi(client, 'http://localhost:8080'),
          ),
        ],
        child: const ShannonApp(),
      ),
    );
    await tester.ensureVisible(find.text('Check backend connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check backend connection'));
    await tester.pumpAndSettle();
    expect(find.text('Connection unavailable'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Connected to Shannon'), findsOneWidget);
  });
}
