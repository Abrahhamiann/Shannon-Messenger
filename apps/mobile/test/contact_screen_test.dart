import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shannon/app/theme.dart';
import 'package:shannon/features/contacts/contact_screen.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';

class _Identity extends IdentityController {
  @override
  Future<IdentityView> build() async =>
      const IdentityView(IdentityStage.authenticated, id: 'self');
}

class _Repository extends IdentityRepository {
  _Repository() : super(AndroidKeyStore(), http.Client());
  final operations = <String>[];
  bool accepted = false;
  @override
  Future<Map<String, dynamic>> contactRequest(
    String method,
    String op, [
    Map<String, dynamic>? body,
  ]) async {
    operations.add('$method $op');
    if (op == '/profile') return {'username': 'tester', 'discoverable': false};
    if (op == '/lookup') return {'id': 'peer', 'username': 'friend'};
    if (op == '/invitation') {
      return {
        'invitation': 'A' * 43,
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
      };
    }
    if (op == '/accept') accepted = true;
    if (op == '') {
      return {
        'items': [
          if (!accepted)
            {'id': 'peer', 'username': 'friend', 'kind': 'incoming'},
        ],
        'next': '',
      };
    }
    return {'ok': true};
  }
}

void main() {
  for (final dark in [true, false]) {
    for (final section in [
      'contacts',
      'add',
      'requests',
      'qr',
      'privacy',
      'blocked',
    ]) {
      testWidgets(
        '$section ${dark ? 'dark' : 'light'} fits phone and large text',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _Repository();
          addTearDown(repo.client.close);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                identityControllerProvider.overrideWith(_Identity.new),
                identityRepositoryProvider.overrideWithValue(repo),
              ],
              child: MaterialApp(
                theme: dark ? ShannonTheme.dark : ShannonTheme.light,
                builder: (_, child) => MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(1.5),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: ContactScreen(section: section),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (section == 'qr') {
            await tester.tap(find.text('Generate private invite'));
            await tester.pumpAndSettle();
            expect(find.byType(QrImageView), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('Revoke current invitation'),
              250,
            );
            await tester.pumpAndSettle();
            await tester.drag(find.byType(ListView), const Offset(0, -500));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Revoke current invitation'));
            await tester.pumpAndSettle();
            expect(find.byType(QrImageView), findsNothing);
            expect(repo.operations, contains('DELETE /invitation'));
          }
          if (section == 'requests') {
            await tester.ensureVisible(find.text('Accept'));
            await tester.tap(find.text('Accept'));
            await tester.pumpAndSettle();
            expect(repo.operations, contains('POST /accept'));
            expect(find.text('Accept'), findsNothing);
          }
          if (section == 'add') {
            await tester.enterText(find.byType(TextField), '@friend');
            expect(
              repo.operations,
              isEmpty,
            ); // No autocomplete or search on typing.
            await tester.tap(find.text('Find exact match'));
            await tester.pumpAndSettle();
            expect(repo.operations, ['POST /lookup']);
            await tester.ensureVisible(find.text('Send request'));
            await tester.pumpAndSettle();
            await tester.drag(find.byType(ListView), const Offset(0, -600));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Send request'));
            await tester.pumpAndSettle();
            expect(repo.operations, contains('POST /request'));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
