import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';

import 'identity_test.dart' show MemoryStore;

void main() {
  test('messaging uses a bound unexpired bearer without redundant me requests and respects local logout', () async {
    final store = MemoryStore();
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(
        request.headers['Authorization'],
        'Bearer ${encode64(List.filled(32, 8))}',
      );
      return http.Response('{"remaining":50}', 200);
    });
    addTearDown(client.close);
    final repository = IdentityRepository(store, client);
    final identity = await repository.create('isolated session test');
    final savedIdentity = store.values[IdentityRepository.identityKey];
    store.values[IdentityRepository.sessionKey] = jsonEncode({
      'identity_id': identity.id,
      'device_id': identity.deviceId,
      'access_token': encode64(List.filled(32, 8)),
      'refresh_token': encode64(List.filled(32, 9)),
      'access_expires_at': DateTime.now()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'expires_at': DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String(),
    });
    expect(
      (await repository.messagingRequest('GET', '/inventory'))['remaining'],
      50,
    );
    expect(paths, ['/api/v1/messaging/inventory']);
    store.values[IdentityRepository.signedOutKey] = 'local-sign-out';
    await expectLater(
      repository.messagingRequest('GET', '/inventory'),
      throwsA(isA<IdentityFailure>().having((e) => e.status, 'status', 401)),
    );
    expect(paths.length, 1);
    expect(store.values[IdentityRepository.identityKey], savedIdentity);
  });
  test(
    'messaging rejects a session for a different identity before any HTTP',
    () async {
      final store = MemoryStore();
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final repository = IdentityRepository(store, client);
      final identity = await repository.create('isolated binding test');
      store.values[IdentityRepository.sessionKey] = jsonEncode({
        'identity_id': 'another account',
        'device_id': identity.deviceId,
        'access_token': encode64(List.filled(32, 8)),
        'access_expires_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
      });
      await expectLater(
        repository.messagingRequest('GET', '/inventory'),
        throwsA(isA<IdentityFailure>()),
      );
      expect(requests, 0);
    },
  );
}
