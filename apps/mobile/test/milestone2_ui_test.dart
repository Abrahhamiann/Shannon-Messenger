import 'identity_fixture.dart';

import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shannon/app/app.dart';

void main() {
  testWidgets('Welcome opens four main tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityControllerProvider.overrideWith(NoIdentityController.new),
        ],
        child: const ShannonApp(),
      ),
    );
    await tester.scrollUntilVisible(find.text('Open Shannon'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Shannon'));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsWidgets);

    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(find.text('RECENT'), findsOneWidget);

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('Add contact'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('My profile'), findsOneWidget);
  });

  testWidgets('Settings theme switch changes brightness', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          identityControllerProvider.overrideWith(NoIdentityController.new),
        ],
        child: const ShannonApp(),
      ),
    );
    await tester.scrollUntilVisible(find.text('Open Shannon'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Shannon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Light'), 250);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Light'))).brightness,
      Brightness.light,
    );
  });
}
