import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';

import 'identity_test.dart' show MemoryStore;

class MarkerFailureStore extends MemoryStore {
  @override
  Future<String?> read(String key) async {
    if (key == IdentityRepository.registrationKey) {
      throw StateError('storage failure');
    }
    return super.read(key);
  }
}

void main() {
  test(
    'reachable API requiring TLS reports its transport configuration',
    () async {
      final store = MemoryStore();
      final client = MockClient(
        (_) async => http.Response('{"error":"TLS required"}', 426),
      );
      addTearDown(client.close);
      final repo = IdentityRepository(store, client);
      await repo.create('Saved');
      final record = store.values[IdentityRepository.identityKey];
      await expectLater(
        repo.connect(),
        throwsA(
          isA<IdentityFailure>()
              .having((e) => e.status, 'status', 426)
              .having(
                (e) => e.message,
                'diagnostic',
                contains('SHANNON_ALLOW_INSECURE_LOCAL_AUTH=1'),
              ),
        ),
      );
      expect(store.values[IdentityRepository.identityKey], record);
    },
  );
  test(
    'pending signup restart restores identity without registration requests',
    () async {
      final store = MemoryStore();
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        throw StateError('No request authorized');
      });
      addTearDown(client.close);
      await IdentityRepository(store, client).create('Pending');
      await store.write(
        IdentityRepository.registrationKey,
        jsonEncode({'nickname': 'Pending', 'username': 'pending_user'}),
      );
      final before = Map<String, String>.of(store.values);
      final restored = await IdentityRepository(store, client).resume();
      expect(restored.stage, IdentityStage.registrationInterrupted);
      expect(restored.nickname, 'Pending');
      expect(requests, 0);
      expect(store.values, before);
    },
  );
  test(
    'failure reading account markers fails closed and preserves keys',
    () async {
      final store = MarkerFailureStore();
      final client = MockClient((_) async => throw StateError('No network'));
      addTearDown(client.close);
      final repo = IdentityRepository(store, client);
      await repo.create('Saved');
      final record = store.values[IdentityRepository.identityKey];
      expect((await repo.resume()).stage, IdentityStage.storageUnavailable);
      expect(store.values[IdentityRepository.identityKey], record);
    },
  );
  test('simultaneous creation cannot overwrite the first identity', () async {
    final store = MemoryStore();
    final client = MockClient((_) async => throw StateError('No network'));
    addTearDown(client.close);
    final repo = IdentityRepository(store, client);
    final first = repo.create('First');
    await expectLater(repo.create('Second'), throwsA(isA<IdentityFailure>()));
    expect((await first).nickname, 'First');
    expect(
      (await IdentityRepository(store, client).resume()).nickname,
      'First',
    );
  });

  test(
    'interrupted signup and username conflict reuse keys after restart',
    () async {
      final store = MemoryStore();
      var loseResponse = true, conflict = true;
      String? root, device;
      final client = MockClient((request) async {
        final body = request.body.isEmpty
            ? {}
            : jsonDecode(request.body) as Map;
        final path = request.url.path;
        if (path.endsWith('/challenge')) {
          root = body['root_key'] as String;
          device = body['device_key'] as String;
          final nonce = encode64(List.filled(32, 4));
          return http.Response(
            jsonEncode({
              'nonce': nonce,
              'payload': jsonEncode({
                'version': 1,
                'audience': authAudience,
                'purpose': body['purpose'],
                'root_key': root,
                'device_key': device,
                'nonce': nonce,
                'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 120,
              }),
            }),
            200,
          );
        }
        final id = await publicID(decode64(root!), 'shn1_');
        final did = await publicID(decode64(device!), 'dev1_');
        if (path.endsWith('/register') || path.endsWith('/verify')) {
          if (loseResponse) {
            loseResponse = false;
            throw http.ClientException('lost response');
          }
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
            200,
          );
        }
        if (path.endsWith('/profile')) {
          return http.Response('{}', conflict ? 409 : 200);
        }
        throw StateError('Unexpected request');
      });
      addTearDown(client.close);
      await expectLater(
        IdentityRepository(store, client).signup('Saved', 'taken'),
        throwsA(isA<http.ClientException>()),
      );
      final first =
          jsonDecode(store.values[IdentityRepository.identityKey]!) as Map;
      final restarted = IdentityRepository(store, client);
      expect(
        (await restarted.resume()).stage,
        IdentityStage.registrationInterrupted,
      );
      await expectLater(
        restarted.signup('Saved', 'taken'),
        throwsA(isA<IdentityFailure>()),
      );
      expect(
        (await IdentityRepository(store, client).resume()).stage,
        IdentityStage.registrationInterrupted,
      );
      conflict = false;
      final last = await IdentityRepository(
        store,
        client,
      ).signup('Saved', 'available');
      expect(last.stage, IdentityStage.authenticated);
      final after =
          jsonDecode(store.values[IdentityRepository.identityKey]!) as Map;
      expect(after['root_seed'], first['root_seed']);
      expect(after['device_seed'], first['device_seed']);
      expect(store.values[IdentityRepository.registrationKey], isNull);
    },
  );

  test('concurrent resume shares one verification', () async {
    final store = MemoryStore();
    final ready = Completer<void>();
    var calls = 0;
    String? id, did;
    final client = MockClient((_) async {
      calls++;
      await ready.future;
      return http.Response(
        jsonEncode({'identity_id': id, 'device_id': did}),
        200,
      );
    });
    addTearDown(client.close);
    final repo = IdentityRepository(store, client);
    final view = await repo.create('Saved');
    id = view.id;
    did = view.deviceId;
    await store.write(
      IdentityRepository.sessionKey,
      jsonEncode({
        'access_token': 'test',
        'access_expires_at': DateTime.now()
            .add(const Duration(minutes: 15))
            .toIso8601String(),
      }),
    );
    final a = repo.resume(), b = repo.resume();
    ready.complete();
    expect((await a).stage, IdentityStage.authenticated);
    expect((await b).stage, IdentityStage.authenticated);
    expect(calls, 1);
  });
}
