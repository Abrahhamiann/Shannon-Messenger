import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';

class MemoryStore implements SecureKeyStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async {
    if (fail) throw StateError('test storage failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('test storage failure');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

List<int> unhex(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  for (final changedField in [
    'version',
    'purpose',
    'root_key',
    'device_key',
    'nonce',
    'exp',
  ]) {
    test('rejects substituted challenge field: $changedField', () async {
      final store = MemoryStore();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final input = jsonDecode(request.body) as Map;
        final nonce = encode64(List.filled(32, 1));
        final payload = <String, dynamic>{
          'version': 1,
          'audience': authAudience,
          'purpose': 'register',
          'root_key': input['root_key'],
          'device_key': input['device_key'],
          'nonce': nonce,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120,
        };
        payload[changedField] = switch (changedField) {
          'version' => 2,
          'exp' => DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600,
          _ => 'substituted',
        };
        return http.Response(
          jsonEncode({'nonce': nonce, 'payload': jsonEncode(payload)}),
          200,
        );
      });
      addTearDown(client.close);
      final repository = IdentityRepository(store, client);
      await repository.create('');
      await expectLater(repository.connect(), throwsA(anything));
      expect(requests, 1);
      expect((await repository.resume()).stage, IdentityStage.local);
    });
  }
  test('RFC 8032 published vector and invalid signature', () async {
    final algorithm = Ed25519();
    final key = await algorithm.newKeyPairFromSeed(
      unhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'),
    );
    final pub = await key.extractPublicKey();
    expect(
      hex(pub.bytes),
      'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
    );
    final signature = await algorithm.sign([], keyPair: key);
    expect(
      hex(signature.bytes),
      'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
    );
    expect(await algorithm.verify([], signature: signature), isTrue);
    expect(await algorithm.verify([1], signature: signature), isFalse);
    expect(
      await publicID(pub.bytes, 'shn1_'),
      isNot(await publicID(pub.bytes, 'dev1_')),
    );
  });

  test('local keys persist independently; no request during generation; no overwrite', () async {
    final store = MemoryStore();
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('', 503);
    });
    addTearDown(client.close);
    final repo = IdentityRepository(store, client);
    final local = await repo.create('Local nickname');
    expect(local.stage, IdentityStage.local);
    expect(requests, 0);
    final record =
        jsonDecode(store.values[IdentityRepository.identityKey]!) as Map;
    expect(record['root_seed'], isNot(record['device_seed']));
    await expectLater(repo.create('second'), throwsA(isA<IdentityFailure>()));
    final restarted = IdentityRepository(store, client);
    expect((await restarted.resume()).id, local.id);
    await expectLater(restarted.connect(), throwsA(isA<IdentityFailure>()));
    expect((await restarted.resume()).id, local.id);
    store.fail = true;
    expect((await restarted.resume()).stage, IdentityStage.storageUnavailable);
    expect(store.values.containsKey(IdentityRepository.identityKey), isTrue);
  });

  test(
    'signed challenge, session verification, restart, logout; public-only HTTP',
    () async {
      final store = MemoryStore();
      String? root, device, id, did;
      var authenticated = false, registrations = 0, logins = 0;
      final client = MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, isNot(contains('root_seed')));
        expect(body.keys, isNot(contains('device_seed')));
        expect(body.keys, isNot(contains('nickname')));
        expect(body.keys, isNot(contains('mnemonic')));
        final stored = store.values[IdentityRepository.identityKey];
        if (stored != null) {
          final secrets = jsonDecode(stored) as Map;
          expect(
            request.body.contains(secrets['root_seed'] as String),
            isFalse,
          );
          expect(
            request.body.contains(secrets['device_seed'] as String),
            isFalse,
          );
        }
        final path = request.url.path;
        if (path.endsWith('/challenge')) {
          root = body['root_key'] as String;
          device = body['device_key'] as String;
          final nonce = encode64(List.filled(32, 7));
          return http.Response(
            jsonEncode({
              'nonce': nonce,
              'payload': jsonEncode({
                'version': 1,
                'audience': authAudience,
                'purpose': body['purpose'],
                'nonce': nonce,
                'root_key': root,
                'device_key': device,
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120,
              }),
            }),
            200,
          );
        }
        if (path.endsWith('/register') || path.endsWith('/verify')) {
          final register = path.endsWith('/register');
          if (register) {
            registrations++;
          } else {
            logins++;
          }
          for (final field
              in register ? ['root_proof', 'device_proof'] : ['device_proof']) {
            final parts = (body[field] as String).split('.');
            expect(utf8.decode(decode64(parts[0])), jwsHeader);
            final publicKey = SimplePublicKey(
              decode64(field == 'root_proof' ? root! : device!),
              type: KeyPairType.ed25519,
            );
            expect(
              await Ed25519().verify(
                utf8.encode('${parts[0]}.${parts[1]}'),
                signature: Signature(decode64(parts[2]), publicKey: publicKey),
              ),
              isTrue,
            );
          }
          id = await publicID(decode64(root!), 'shn1_');
          did = await publicID(decode64(device!), 'dev1_');
          authenticated = true;
          return http.Response(
            jsonEncode({
              'identity_id': id,
              'device_id': did,
              'access_token': encode64(List.filled(32, 8)),
              'refresh_token': encode64(List.filled(32, 9)),
              'expires_at': DateTime.now()
                  .add(const Duration(days: 7))
                  .toIso8601String(),
              'access_expires_at': DateTime.now()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            }),
            200,
          );
        }
        if (path.endsWith('/me')) {
          return http.Response(
            jsonEncode({'identity_id': id, 'device_id': did}),
            authenticated ? 200 : 401,
          );
        }
        if (path.endsWith('/logout')) {
          authenticated = false;
          return http.Response('', 204);
        }
        return http.Response('', 401);
      });
      addTearDown(client.close);
      final repo = IdentityRepository(store, client);
      await repo.create('never uploaded');
      expect((await repo.connect()).stage, IdentityStage.authenticated);
      final restarted = IdentityRepository(store, client);
      expect((await restarted.resume()).stage, IdentityStage.authenticated);
      expect((await restarted.logout()).stage, IdentityStage.local);
      expect(store.values.containsKey(IdentityRepository.identityKey), isTrue);
      expect((await restarted.connect()).stage, IdentityStage.authenticated);
      expect(registrations, 1);
      expect(logins, 1);
    },
  );

  test(
    'challenge substitution refused before any signing proof is sent',
    () async {
      final store = MemoryStore();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body) as Map;
        final nonce = encode64(List.filled(32, 0));
        return http.Response(
          jsonEncode({
            'nonce': nonce,
            'payload': jsonEncode({
              'version': 1,
              'audience': 'attacker',
              'purpose': 'register',
              'nonce': nonce,
              'root_key': body['root_key'],
              'device_key': body['device_key'],
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 100,
            }),
          }),
          200,
        );
      });
      addTearDown(client.close);
      final repo = IdentityRepository(store, client);
      await repo.create('');
      await expectLater(repo.connect(), throwsA(isA<IdentityFailure>()));
      expect(requests, 1);
      expect((await repo.resume()).stage, IdentityStage.local);
    },
  );

  test('corrupted storage fails closed without silent replacement', () async {
    final store = MemoryStore()
      ..values[IdentityRepository.identityKey] = 'not json';
    final client = MockClient((_) async => http.Response('', 500));
    addTearDown(client.close);
    final repo = IdentityRepository(store, client);
    expect((await repo.resume()).stage, IdentityStage.storageUnavailable);
    await expectLater(repo.create(''), throwsA(anything));
    expect(store.values[IdentityRepository.identityKey], 'not json');
  });
}
