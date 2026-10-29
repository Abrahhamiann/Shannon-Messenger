import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/messaging/messaging_identity.dart';

import 'identity_test.dart' show MemoryStore;

Future<Map<String, dynamic>> fixture() async {
  final store = MemoryStore();
  final client = http.Client();
  addTearDown(client.close);
  final repo = IdentityRepository(store, client);
  await repo.create('isolated identity');
  final before = store.values[IdentityRepository.identityKey];
  final pair = await Ed25519().newKeyPair();
  final public = await pair.extractPublicKey();
  final bundle = await repo.authorizeMessagingIdentity({
    'curve': encode64(List.filled(32, 7)),
    'signing': encode64(public.bytes),
  });
  final prekey = <String, dynamic>{
    'id': encode64(List.filled(32, 8)),
    'key': encode64(List.filled(32, 8)),
  };
  prekey['signature'] = encode64(
    (await Ed25519().sign(
      utf8.encode(messagingPrekey(bundle, prekey)),
      keyPair: pair,
    )).bytes,
  );
  bundle['prekeys'] = [prekey];
  expect(
    store.values[IdentityRepository.identityKey],
    before,
    reason: 'messaging binding never modifies auth identity',
  );
  return bundle;
}

void main() {
  test('authorized messaging identity and signed prekey verify without key replacement', () async {
    final bundle = await fixture();
    await verifyMessagingBundle(
      bundle,
      bundle['account'] as String,
      authAudience,
    );
  });
  test(
    'malicious directory cannot change a bound messaging identity',
    () async {
      final bundle = await fixture();
      final changed = {...bundle, 'curve': encode64(List.filled(32, 9))};
      await expectLater(
        verifyMessagingBundle(
          changed,
          bundle['account'] as String,
          authAudience,
        ),
        throwsA(isA<IdentityFailure>()),
      );
      await expectLater(
        verifyMessagingBundle(bundle, 'shn1_${'A' * 43}', authAudience),
        throwsA(isA<IdentityFailure>()),
      );
    },
  );
  test('forged prekey and cross-audience authorization fail', () async {
    final bundle = await fixture();
    final changed = jsonDecode(jsonEncode(bundle)) as Map<String, dynamic>;
    changed['prekeys'][0]['signature'] = encode64(List.filled(64, 0));
    await expectLater(
      verifyMessagingBundle(changed, bundle['account'] as String, authAudience),
      throwsA(isA<IdentityFailure>()),
    );
    await expectLater(
      verifyMessagingBundle(
        bundle,
        bundle['account'] as String,
        'other-server',
      ),
      throwsA(isA<IdentityFailure>()),
    );
  });
  test(
    'verification fingerprint is symmetric and binds both complete identities',
    () async {
      final a = await fixture(), b = await fixture();
      final first = await messagingFingerprint(a, b, authAudience);
      expect(await messagingFingerprint(b, a, authAudience), first);
      expect(
        await messagingFingerprint(a, {
          ...b,
          'curve': encode64(List.filled(32, 6)),
        }, authAudience),
        isNot(first),
      );
    },
  );
}
