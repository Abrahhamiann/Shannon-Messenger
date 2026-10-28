import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/data/avatar_repository.dart';
import 'package:shannon/app/screen_privacy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:shannon/features/contacts/contact_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';

import '../test/avatar_test.dart' show avatarFixture;

// A separate encrypted namespace ensures tests never overwrite a user's identity.
class TestAndroidStore implements SecureKeyStore {
  final storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace:
          'shannon_validation_${DateTime.now().microsecondsSinceEpoch}',
    ),
  );
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android Keystore → signed Go registration → PostgreSQL → restart → logout → revoke',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      final store = TestAndroidStore();
      final client = http.Client();
      try {
        final repo = IdentityRepository(store, client);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [identityRepositoryProvider.overrideWithValue(repo)],
            child: const ShannonApp(),
          ),
        );
        await ProviderScope.containerOf(tester.element(find.byType(ShannonApp)))
            .read(identityControllerProvider.future);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Sign Up'), 200);
        await tester.tap(find.text('Sign Up'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'test-only');
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(Checkbox),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
        await tester.ensureVisible(find.text('Create account'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create account'));
        // Settling animation frames does not wait for real HTTP/Keystore work.
        final signupDeadline = DateTime.now().add(const Duration(seconds: 30));
        while (find.text('Account created!').evaluate().isEmpty &&
            DateTime.now().isBefore(signupDeadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        expect(find.text('Account created!'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Continue'), 250);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Search Chats'), findsOneWidget);
        final local = await repo.resume();
        expect(local.stage, IdentityStage.authenticated);
        await repo.updateNickname('Շենոն · Шеннон');
        final keyRecord = await store.read(IdentityRepository.identityKey);
        await AvatarRepository(store).save(await avatarFixture());
        final avatar = await AvatarRepository(store).read();
        expect(avatar, isNotNull);
        expect(await AvatarRepository(store).read(), avatar);
        expect(await store.read(IdentityRepository.identityKey), keyRecord);
        final restarted = IdentityRepository(store, client);
        expect((await restarted.resume()).id, local.id);
        expect((await restarted.resume()).nickname, 'Շենոն · Шеннон');
        expect((await restarted.resume()).stage, IdentityStage.authenticated);
        expect((await restarted.devices()).length, 1);
        // A second isolated identity exercises real contacts, never a user's keys.
        final other = IdentityRepository(TestAndroidStore(), client);
        final otherLocal = await other.create('contact-test');
        await other.connect();
        final invite = await other.contactRequest('POST', '/invitation', {});
        final link = invitationLink(invite['invitation'] as String);
        final qrKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: qrKey,
                  child: QrImageView(
                    data: link,
                    size: 280,
                    padding: const EdgeInsets.all(36),
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary =
            qrKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final temporary = await Directory.systemTemp.createTemp(
          'shannon-qr-validation-',
        );
        final qrFile = File('${temporary.path}/invite.png');
        await qrFile.writeAsBytes(png!.buffer.asUint8List());
        final decoded = await privacyChannel.invokeMethod<String>(
          'decodeQrForValidation',
          qrFile.path,
        );
        expect(decoded, link);
        expect(invitationToken(decoded!), invite['invitation']);
        await qrFile.delete();
        await temporary.delete();
        final preview = await restarted.contactRequest('POST', '/resolve', {
          'invitation': invite['invitation'],
        });
        expect(preview['id'], otherLocal.id);
        await restarted.contactRequest('POST', '/request', {
          'invitation': invite['invitation'],
          'target': otherLocal.id,
        });
        final pending = await other.contactRequest('GET', '');
        expect((pending['items'] as List).single['kind'], 'incoming');
        await other.contactRequest('POST', '/accept', {'target': local.id});
        final contacts = await restarted.contactRequest('GET', '');
        expect((contacts['items'] as List).single['kind'], 'accepted');
        await other.contactRequest('POST', '/block', {'target': local.id});
        expect((await restarted.contactRequest('GET', ''))['items'], isEmpty);

        await privacyChannel.invokeMethod<void>('ready');
        expect(await privacyChannel.invokeMethod<bool>('isProtected'), false);
        await tester.pumpWidget(
          const MaterialApp(
            home: SensitiveScreen(child: Text('TEST PRIVATE CONTENT')),
          ),
        );
        await tester.pumpAndSettle();
        expect(await privacyChannel.invokeMethod<bool>('isProtected'), true);
        debugPrint('SHANNON_PRIVACY_TEST_SECURE');
        await Future<void>.delayed(const Duration(seconds: 10));
        await tester.pumpWidget(
          const MaterialApp(home: Text('TEST PUBLIC CONTENT')),
        );
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(await privacyChannel.invokeMethod<bool>('isProtected'), false);
        debugPrint('SHANNON_PRIVACY_TEST_PUBLIC');
        await Future<void>.delayed(const Duration(seconds: 10));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              identityRepositoryProvider.overrideWithValue(restarted),
            ],
            child: const ShannonApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ShannonApp)),
        );
        container.read(routerProvider).go('/profile');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Log Out'), 250);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Log Out'));
        await tester.pumpAndSettle();
        expect(
          find.text('Continue with identity on this device'),
          findsOneWidget,
        );
        expect((await restarted.resume()).stage, IdentityStage.local);
        expect(await store.read(IdentityRepository.identityKey), keyRecord);
        await tester.tap(find.text('Continue with identity on this device'));
        await tester.pumpAndSettle();
        expect(find.text('Search Chats'), findsOneWidget);
        expect((await restarted.resume()).id, local.id);
        expect(
          (await restarted.revokeThisDevice()).stage,
          IdentityStage.revoked,
        );
        expect(
          (await IdentityRepository(store, client).resume()).stage,
          IdentityStage.revoked,
        );
      } finally {
        client.close();
      }
    },
  );
}
