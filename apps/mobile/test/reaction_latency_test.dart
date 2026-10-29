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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
