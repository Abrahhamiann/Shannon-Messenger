import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/messaging/messaging_controller.dart';

import 'identity_fixture.dart';

class _SlowDirectory extends FixtureRepository {
  final waiting = Completer<Map<String, dynamic>>();
  int lookups = 0, submitted = 0;
  @override
  Future<Map<String, dynamic>> messagingRequest(
    String method,
    String operation, [
    Map<String, dynamic>? body,
  ]) {
    if (operation.startsWith('/bundle')) {
      lookups++;
      return waiting.future;
    }
    submitted++;
    throw StateError(
      'Ciphertext must not bypass the pinned-identity directory check',
    );
  }
}

class _Ready extends MessagingController {
  @override
  MessagingView build() => const MessagingView(ready: true);
}

class _RejectedDirectory extends FixtureRepository {
  _RejectedDirectory(this.status);
  final int status;
  int lookups = 0, submitted = 0;

  @override
  Future<Map<String, dynamic>> messagingRequest(
    String method,
    String operation, [
    Map<String, dynamic>? body,
  ]) async {
    if (operation.startsWith('/bundle')) {
      lookups++;
      throw IdentityFailure('Directory rejected this peer', status);
    }
    if (operation == '/envelopes') {
      submitted++;
      return {'state': 'accepted'};
    }
    return {'items': [], 'next': '0'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in [403, 404, 409]) {
    test('directory $status cannot authorize later queued messages', () async {
      final repo = _RejectedDirectory(status);
      final failed = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(messagingChannel, (call) async {
        final input = jsonDecode(call.arguments as String) as Map;
        if (input['op'] == 'state' && input['state'] == 'failed') {
          failed.add(input['id'] as String);
        }
        return jsonEncode(switch (input['op']) {
          'outbox' => {
            'items': [
              {'recipient': 'peer', 'id': 'first'},
              {'recipient': 'peer', 'id': 'second'},
            ],
          },
          'conversations' => {'items': []},
          _ => {},
        });
      });
      final container = ProviderContainer(
        overrides: [
          identityRepositoryProvider.overrideWithValue(repo),
          identityControllerProvider.overrideWith(
            AuthenticatedIdentityController.new,
          ),
          messagingProvider.overrideWith(_Ready.new),
        ],
      );
      addTearDown(() {
        container.dispose();
        messenger.setMockMethodCallHandler(messagingChannel, null);
      });
      await container.read(identityControllerProvider.future);
      await container.read(messagingProvider.notifier).synchronize();
      expect(repo.submitted, 0);
      expect(repo.lookups, 2);
      expect(failed, ['first', 'second']);
    });
  }
  test('local reaction commits while a directory lookup is stalled, without transmitting before validation', () async {
    final repo = _SlowDirectory();
    final operations = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(messagingChannel, (call) async {
      final value = jsonDecode(call.arguments as String) as Map;
      final op = value['op'] as String;
      operations.add(op);
      return jsonEncode(switch (op) {
        'peer' => {'interactions': true},
        'send' => {'id': 'durable-local-reaction'},
        'conversations' => {'items': []},
        'outbox' => {
          'items': [
            {'recipient': 'peer', 'id': 'durable-local-reaction'},
          ],
        },
        _ => {},
      });
    });
    final container = ProviderContainer(
      overrides: [
        identityRepositoryProvider.overrideWithValue(repo),
        identityControllerProvider.overrideWith(
          AuthenticatedIdentityController.new,
        ),
        messagingProvider.overrideWith(_Ready.new),
      ],
    );
    addTearDown(() {
      container.dispose();
      messenger.setMockMethodCallHandler(messagingChannel, null);
    });
    await container.read(identityControllerProvider.future);
    final service = container.read(messagingProvider.notifier);
    await service
        .queue('peer', {
          'kind': 'reaction',
          'emoji': '❤️',
          'target': {'id': 'message', 'sender_device': 'peer-device'},
        })
        .timeout(const Duration(milliseconds: 500));
    await Future<void>.delayed(Duration.zero);
    expect(operations, contains('send'));
    expect(repo.lookups, 1);
    expect(repo.waiting.isCompleted, isFalse);
    expect(repo.submitted, 0);
    repo.waiting.completeError(
      const IdentityFailure('Backend unavailable', 503),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.submitted, 0);
  });
}
