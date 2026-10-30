import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../identity/data/identity_repository.dart';
import '../identity/presentation/identity_controller.dart';
import 'messaging_identity.dart';

const m4MessagingEnabled = bool.fromEnvironment('SHANNON_M4_MESSAGING');
const messagingChannel = MethodChannel('shannon/messaging');

String messagingFailureMessage(Object error) {
  if (error is PlatformException && error.code == 'identity_changed') {
    return 'Contact identity changed. Sending is blocked until it can be verified again.';
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is http.ClientException ||
      error is IdentityFailure &&
          error.status != null &&
          error.status! >= 500) {
    return 'Backend connection unavailable. Encrypted history stays on this device and queued messages will retry.';
  }
  if (error is IdentityFailure) {
    return switch (error.status) {
      401 => 'Session unavailable. Sign in to resume encrypted delivery.',
      403 => 'Contact messaging is blocked or no longer authorized.',
      404 => 'This contact has no available messaging device.',
      409 => 'The messaging identity, prekey inventory or saved message was rejected. Refresh the contact identity before retrying.',
      429 =>
        'Messaging limit reached. Queued messages will retry after a delay.',
      _ => error.message,
    };
  }
  return 'Messaging could not complete. Your saved identity and encrypted history are preserved.';
}

class MessagingView {
  const MessagingView({
    this.ready = false,
    this.foreground = true,
    this.revision = 0,
    this.conversations = const [],
    this.error,
  });
  final bool ready, foreground;
  final int revision;
  final List<Map<String, dynamic>> conversations;
  final String? error;
}

final messagingProvider = NotifierProvider<MessagingController, MessagingView>(
  MessagingController.new,
);
Future<Map<String, dynamic>> messagingNative(Map<String, dynamic> input) async {
  final raw = await messagingChannel.invokeMethod<String>(
    'invoke',
    jsonEncode(input),
  );
  return Map<String, dynamic>.from(jsonDecode(raw!) as Map);
}

class MessagingController extends Notifier<MessagingView> {
  WebSocket? _socket;
  Timer? _retry;
  bool _working = false, _connecting = false, _disposed = false;
  bool _syncAgain = false;
  int _generation = 0, _attempt = 0;
  String? _owner;
  Map<String, dynamic>? _ownBinding;
  final _blocked = <String>{};
  IdentityRepository get _repo => ref.read(identityRepositoryProvider);
  bool get _signedIn =>
      ref.read(identityControllerProvider).asData?.value.stage ==
      IdentityStage.authenticated;
  @override
  MessagingView build() {
    if (!m4MessagingEnabled) return const MessagingView();
    messagingChannel.setMethodCallHandler((call) async {
      if (call.method == 'background') {
        _generation++;
        _retry?.cancel();
        unawaited(_socket?.close());
        _socket = null;
        state = MessagingView(
          ready: state.ready,
          foreground: false,
          revision: state.revision + 1,
        );
      } else if (call.method == 'foreground') {
        state = MessagingView(ready: state.ready, revision: state.revision + 1);
        unawaited(start());
      }
    });
    ref.listen(identityControllerProvider, (_, next) {
      final view = next.asData?.value;
      if (view == null) return;
      if (view.stage == IdentityStage.authenticated ||
          view.stage == IdentityStage.offline) {
        unawaited(start());
      } else {
        _generation++;
        _retry?.cancel();
        unawaited(_socket?.close());
        _socket = null;
        state = MessagingView(
          foreground: state.foreground,
          revision: state.revision + 1,
        );
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _retry?.cancel();
      unawaited(_socket?.close());
      messagingChannel.setMethodCallHandler(null);
    });
    Future.microtask(() async {
      // Native App Lock can cover Flutter before the first lifecycle event.
      // Query its current state so a cold locked start never opens history.
      try {
        final visible = await messagingChannel.invokeMethod<bool>('visibility');
        if (_disposed) return;
        state = MessagingView(foreground: visible == true);
        if (visible == true) await start();
      } catch (_) {
        if (!_disposed) state = const MessagingView(foreground: false);
      }
    });
    return const MessagingView();
  }

  void _error(Object error) {
    if (_disposed || !state.foreground) return;
    final message = messagingFailureMessage(error);
    state = MessagingView(
      ready: state.ready,
      foreground: true,
      revision: state.revision + 1,
      conversations: state.conversations,
      error: message,
    );
  }

  Future<void> reload() async {
    if (_disposed || !state.foreground || !state.ready) return;
    final generation = _generation;
    final rows = await messagingNative({'op': 'conversations'});
    if (_disposed || generation != _generation || !state.foreground) return;
    final items = (rows['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    items.sort(
      (a, b) => (b['last']['timestamp'] as int).compareTo(
        a['last']['timestamp'] as int,
      ),
    );
    state = MessagingView(
      ready: true,
      revision: state.revision + 1,
      conversations: items,
      error: state.error,
    );
  }

  Future<void> start() async {
    if (_disposed || !state.foreground || _connecting) return;
    final identity = ref.read(identityControllerProvider).asData?.value;
    if (identity?.id == null ||
        ![
          IdentityStage.authenticated,
          IdentityStage.offline,
        ].contains(identity?.stage)) {
      return;
    }
    _connecting = true;
    final generation = _generation;
    try {
      final local = await messagingNative({
        'op': 'initialize',
        'account': identity!.id,
        'device': identity.deviceId,
      });
      if (_disposed || generation != _generation) return;
      _owner = identity.id;
      _ownBinding = await _repo.authorizeMessagingIdentity(local);
      if (_disposed || generation != _generation || !state.foreground) return;
      state = MessagingView(
        ready: true,
        revision: state.revision + 1,
        conversations: state.conversations,
      );
      await reload();
      if (!_signedIn) {
        // Only resume a retained session. Never create an identity or undo logout.
        await ref
            .read(identityControllerProvider.notifier)
            .run((r) => r.resume());
        if (_disposed || generation != _generation || !state.foreground) return;
        if (!_signedIn) {
          _schedule();
          return;
        }
      }
      final inventory = await _repo.messagingRequest('GET', '/inventory');
      final needed = max(0, 50 - (inventory['remaining'] as int));
      final publication = await messagingNative({
        'op': 'publish',
        'needed': needed,
      });
      final bundle = {..._ownBinding!, 'prekeys': publication['prekeys']}
        ..remove('root_key')
        ..remove('device_key');
      await _repo.messagingRequest('PUT', '/bundle', bundle);
      await messagingNative({'op': 'mark_published'});
      if (_socket == null) {
        final socket = await _repo.openMessagingSocket();
        if (_disposed || generation != _generation || !state.foreground) {
          await socket.close();
          return;
        }
        _socket = socket;
        socket.listen(
          (event) {
            try {
              final value = jsonDecode(event as String);
              if (value is Map && value['type'] == 'sync_required') {
                unawaited(synchronize());
              }
            } catch (_) {
              /* Only known transport hints are accepted. */
            }
          },
          onError: (Object error) {
            _socket = null;
            _error(error);
            _schedule();
          },
          onDone: () {
            _socket = null;
            _schedule();
          },
        );
      }
      _attempt = 0;
      await synchronize();
    } catch (error) {
      _error(error);
      _schedule();
    } finally {
      _connecting = false;
    }
  }

  void _schedule() {
    final identity = ref.read(identityControllerProvider).asData?.value;
    if (_disposed ||
        !state.foreground ||
        identity?.id == null ||
        ![
          IdentityStage.authenticated,
          IdentityStage.offline,
        ].contains(identity?.stage)) {
      return;
    }
    _retry?.cancel();
    final seconds = min(60, 2 << min(_attempt++, 5));
    final ms = min(
      60000,
      (seconds * 1000 * (0.8 + Random.secure().nextDouble() * 0.4)).round(),
    );
    _retry = Timer(Duration(milliseconds: ms), () => unawaited(start()));
  }

  Future<Map<String, dynamic>> _currentPeer(
    String account, {
    String? label,
    bool claim = false,
  }) async {
    final result = await _repo.messagingRequest(
      claim ? 'POST' : 'GET',
      claim ? '/claim' : '/bundle?account=${Uri.encodeQueryComponent(account)}',
      claim ? {'account': account} : null,
    );
    await verifyMessagingBundle(result, account, _repo.audience);
    try {
      final peer = await messagingNative({
        'op': 'trust',
        'binding': result,
        'label': ?label,
      });
      if (_blocked.contains(account)) {
        throw const IdentityFailure(
          'Contact identity changed. Sending remains blocked.',
        );
      }
      return {...peer, 'claim': result};
    } on PlatformException catch (e) {
      if (e.code == 'identity_changed') _blocked.add(account);
      rethrow;
    }
  }

  Future<void> openPeer(String account, {String? label}) async {
    if (!state.ready) await start();
    final saved = await messagingNative({'op': 'peer', 'account': account});
    if (_signedIn) {
      try {
        await _currentPeer(account, label: label);
      } catch (error) {
        if (saved.isEmpty || !_transportUnavailable(error)) rethrow;
      }
    } else if (saved.isEmpty) {
      throw const IdentityFailure(
        'Connect before starting a first encrypted conversation.',
      );
    }
    await reload();
    final current = await messagingNative({'op': 'peer', 'account': account});
    if (current['capabilities_sent'] != true && _signedIn) {
      try {
        await queue(account, {'kind': 'capabilities'});
      } catch (failure) {
        _error(failure);
      }
    }
  }

  Future<void> send(
    String account,
    String text, {
    Map<String, dynamic>? reply,
    bool forwarded = false,
  }) => queue(account, {
    'text': text,
    'reply': ?reply,
    if (forwarded) 'forwarded': true,
  });

  Future<void> queue(String account, Map<String, dynamic> content) async {
    if (!state.ready || !state.foreground || _blocked.contains(account)) {
      throw const IdentityFailure(
        'Messaging is unavailable or this identity is blocked.',
      );
    }
    final saved = await messagingNative({'op': 'peer', 'account': account});
    if (saved.isEmpty) {
      throw const IdentityFailure(
        'Open and verify this contact before sending.',
      );
    }
    // Commit to the existing pinned session locally first. A fresh directory
    // check still gates every transport batch below, before any ciphertext leaves.
    try {
      await messagingNative({'op': 'send', 'account': account, ...content});
    } on PlatformException catch (error) {
      if (error.code != 'invalid_request') rethrow;
      if (!_signedIn) {
        throw const IdentityFailure(
          'Connect once to establish the first encrypted session. Your draft is kept.',
        );
      }
      final claimed = await _currentPeer(account, claim: true);
      final prekey =
          ((claimed['claim']['prekeys'] as List).single as Map)['key']
              as String;
      await messagingNative({
        'op': 'send',
        'account': account,
        ...content,
        'prekey': prekey,
      });
    }
    // The operation is already durable. A display refresh failure must not make
    // callers retry a new ID and duplicate an already queued message.
    try {
      await reload();
    } catch (error) {
      _error(error);
    }
    unawaited(synchronize());
  }

  bool _transportUnavailable(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is http.ClientException ||
      error is IdentityFailure && error.status != null && error.status! >= 500;

  Future<void> retry(String id) async {
    await messagingNative({'op': 'state', 'id': id, 'state': 'queued'});
    await reload();
    unawaited(synchronize());
  }

  Future<void> synchronize() async {
    if (_working) {
      _syncAgain = true;
      return;
    }
    if (_disposed || !_signedIn || !state.foreground || !state.ready) {
      return;
    }
    _working = true;
    var flushReply = false;
    var dirty = false;
    final generation = _generation;
    try {
      final outbox = await messagingNative({'op': 'outbox'});
      final checkedPeers = <String>{};
      for (final raw in outbox['items'] as List) {
        if (_disposed || generation != _generation || !state.foreground) return;
        final envelope = Map<String, dynamic>.from(raw as Map);
        final created = envelope.remove('local_created') as int?;
        if (created != null &&
            DateTime.fromMillisecondsSinceEpoch(created)
                .add(const Duration(days: 14))
                .isBefore(DateTime.now())) {
          await messagingNative({
            'op': 'state',
            'id': envelope['id'],
            'state': 'expired',
          });
          dirty = true;
          continue;
        }
        try {
          final recipient = envelope['recipient'] as String;
          if (!checkedPeers.contains(recipient)) {
            await _currentPeer(recipient);
            // Cache only successful checks. A rejected first envelope must not
            // authorize later envelopes for this peer in the same batch.
            checkedPeers.add(recipient);
          }
          final receipt = await _repo.messagingRequest(
            'POST',
            '/envelopes',
            envelope,
          );
          await messagingNative({
            'op': 'state',
            'id': envelope['id'],
            'state': receipt['state'] == 'expired' ? 'expired' : 'accepted',
          });
          dirty = true;
        } on IdentityFailure catch (error) {
          if (error.status == 403 ||
              error.status == 404 ||
              error.status == 409) {
            await messagingNative({
              'op': 'state',
              'id': envelope['id'],
              'state': 'failed',
            });
            dirty = true;
            _error(error);
          } else {
            rethrow;
          }
        }
      }
      if ((outbox['items'] as List).length == 50) _syncAgain = true;
      if (dirty) {
        await reload();
        dirty = false;
      }
      var after = '0';
      for (var page = 0; page < 4; page++) {
        if (_disposed || generation != _generation || !state.foreground) return;
        final result = await _repo.messagingRequest(
          'GET',
          '/envelopes?after=$after',
        );
        final items = result['items'] as List;
        if (items.isEmpty) break;
        final acknowledged = <String>[];
        for (final raw in items) {
          if (_disposed || generation != _generation || !state.foreground) {
            return;
          }
          final envelope = Map<String, dynamic>.from(raw as Map);
          try {
            final saved = await messagingNative({
              'op': 'peer',
              'account': envelope['sender'],
            });
            if (saved.isEmpty) await _currentPeer(envelope['sender'] as String);
            final received = await messagingNative({
              'op': 'receive',
              'envelope': envelope,
            });
            flushReply = flushReply || received['needs_flush'] == true;
            dirty = dirty || received['duplicate'] != true;
            acknowledged.add(envelope['sequence'] as String);
          } catch (error) {
            _error(
              error,
            ); /* Never ack unauthenticated or uncommitted content. */
          }
        }
        // Paint committed changes before waiting for transport acknowledgments.
        if (dirty) {
          await reload();
          dirty = false;
        }
        if (acknowledged.isNotEmpty) {
          await _repo.messagingRequest('POST', '/ack', {
            'sequences': acknowledged,
          });
        }
        after = result['next'] as String;
      }
    } catch (error) {
      _error(error);
      _schedule();
    } finally {
      _working = false;
      final again = flushReply || _syncAgain;
      _syncAgain = false;
      if (again && !_disposed && state.foreground) {
        unawaited(synchronize());
      }
    }
  }

  Future<void> localAction(
    String account,
    String op,
    Map<String, dynamic> message, {
    bool? value,
  }) async {
    await messagingNative({
      'op': op,
      'account': account,
      'target': messageReference(message),
      'value': ?value,
    });
    await reload();
  }

  Future<void> chatAction(
    String account,
    String op, {
    bool? pinned,
    bool? archived,
  }) async {
    await messagingNative({
      'op': op,
      'account': account,
      'chat_pinned': ?pinned,
      'archived': ?archived,
    });
    await reload();
  }

  Future<void> deleteMessages(
    String account,
    List<Map<String, dynamic>> messages, {
    required bool everyone,
  }) async {
    if (messages.isEmpty || messages.length > 100) {
      throw const IdentityFailure('Select 1–100 messages.');
    }
    if (!state.ready || !state.foreground || _blocked.contains(account)) {
      throw const IdentityFailure('Messaging unavailable.');
    }
    await messagingNative(
      everyone
          ? {
              'op': 'send_many',
              'account': account,
              'items': messages
                  .map((m) => {'kind': 'delete', 'target': messageReference(m)})
                  .toList(),
            }
          : {
              'op': 'local_delete_many',
              'account': account,
              'targets': messages.map(messageReference).toList(),
            },
    );
    await reload();
    if (everyone) unawaited(synchronize());
  }

  Future<Map<String, dynamic>> peer(String account) =>
      messagingNative({'op': 'peer', 'account': account});

  Future<void> interact(
    String account,
    String kind,
    Map<String, dynamic> message, {
    String? text,
    String? emoji,
  }) => queue(account, {
    'kind': kind,
    'target': messageReference(message),
    'text': ?text,
    'emoji': ?emoji,
  });

  Future<Map<String, dynamic>> security(String account) async {
    final peer = await messagingNative({'op': 'peer', 'account': account});
    final own = _ownBinding;
    if (own == null || peer.isEmpty) {
      throw const IdentityFailure('Messaging identity unavailable.');
    }
    return {
      ...peer,
      'fingerprint': await messagingFingerprint(
        own,
        Map<String, dynamic>.from(peer['binding'] as Map),
        _repo.audience,
      ),
    };
  }

  Future<void> verified(String account, bool value) async {
    await messagingNative({
      'op': 'verify',
      'account': account,
      'verified': value,
    });
    await reload();
  }

  String? get ownAccount => _owner;
}

Map<String, dynamic> messageReference(Map<String, dynamic> message) => {
  'id': message['id'],
  'sender_device': message['sender_device'],
};

final encryptedHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, account) async {
      final view = ref.watch(messagingProvider);
      if (!view.ready || !view.foreground) return [];
      final result = await messagingNative({
        'op': 'history',
        'account': account,
      });
      if (!ref.mounted || !ref.read(messagingProvider).foreground) return [];
      return (result['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });

final messagingPeerProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, account) async {
      final view = ref.watch(messagingProvider);
      if (!view.ready || !view.foreground) return {};
      return messagingNative({'op': 'peer', 'account': account});
    });
