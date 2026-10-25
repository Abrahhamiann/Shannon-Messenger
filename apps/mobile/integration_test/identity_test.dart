import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/data/avatar_repository.dart';

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
        final local = await repo.create('test-only');
        expect(local.stage, IdentityStage.local);
        expect((await repo.connect()).stage, IdentityStage.authenticated);
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
        expect((await restarted.logout()).stage, IdentityStage.local);
        expect((await restarted.connect()).stage, IdentityStage.authenticated);
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
