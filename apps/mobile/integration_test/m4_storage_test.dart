import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/messaging/messaging_controller.dart';
import 'package:shannon/features/messaging/messaging_identity.dart';

import '../test/identity_test.dart' show MemoryStore;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated native E2EE, atomic rollback, encrypted history and reopen',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Isolated M4 native storage validation')),
        ),
      );
      final client = http.Client();
      addTearDown(client.close);
      final alice = IdentityRepository(MemoryStore(), client),
          bob = IdentityRepository(MemoryStore(), client);
      final av = await alice.create('isolated A'),
          bv = await bob.create('isolated B');
      final ah = (await messagingChannel.invokeMethod<String>(
        'validationCreate',
      ))!;
      final bh = (await messagingChannel.invokeMethod<String>(
        'validationCreate',
      ))!;
      final timings = <String, List<int>>{};
      Future<Map<String, dynamic>> call(
        String handle,
        Map<String, dynamic> request,
      ) async {
        final watch = Stopwatch()..start();
        final response = await messagingChannel.invokeMethod<String>(
          'validationInvoke',
          jsonEncode({'handle': handle, 'request': request}),
        );
        timings
            .putIfAbsent(request['op'] as String, () => [])
            .add(watch.elapsedMicroseconds);
        return Map<String, dynamic>.from(jsonDecode(response!) as Map);
      }

      final ap = await call(ah, {
        'op': 'initialize',
        'account': av.id,
        'device': av.deviceId,
      });
      final bp = await call(bh, {
        'op': 'initialize',
        'account': bv.id,
        'device': bv.deviceId,
      });
      expect(ap['curve'], isNot(bp['curve']));
      final aKeys = await call(ah, {'op': 'publish'}),
          bKeys = await call(bh, {'op': 'publish'});
      final ab = {
        ...await alice.authorizeMessagingIdentity(ap),
        'prekeys': aKeys['prekeys'],
      };
      final bb = {
        ...await bob.authorizeMessagingIdentity(bp),
        'prekeys': bKeys['prekeys'],
      };
      await verifyMessagingBundle(ab, av.id!, authAudience);
      await verifyMessagingBundle(bb, bv.id!, authAudience);
      await call(ah, {'op': 'trust', 'binding': bb});
      await call(bh, {'op': 'trust', 'binding': ab});
      const marker = 'M4_TEST_NATIVE_Հայերեն_Русский_rollback';
      await call(ah, {
        'op': 'send',
        'account': bv.id,
        'text': marker,
        'prekey': (bKeys['prekeys'] as List).first['key'],
      });
      final outbox = await call(ah, {'op': 'outbox'});
      final envelope = Map<String, dynamic>.from(
        (outbox['items'] as List).single as Map,
      )..addAll({'sender': av.id, 'sender_device': av.deviceId});
      expect(envelope.toString(), isNot(contains(marker)));
      await call(bh, {'op': 'mark_published'});
      expect(
        (await call(bh, {'op': 'publish', 'needed': 0}))['prekeys'],
        isEmpty,
      );
      expect(
        ((await call(bh, {'op': 'publish', 'needed': 1}))['prekeys'] as List)
            .length,
        1,
      );
      await expectLater(
        call(bh, {
          'op': 'receive',
          'envelope': envelope,
          'fail_before_commit': true,
        }),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'fault',
            'injected_write_failure',
          ),
        ),
      );
      expect(
        (await call(bh, {'op': 'history', 'account': av.id}))['items'],
        isEmpty,
      );
      await call(bh, {'op': 'receive', 'envelope': envelope});
      expect(
        (await call(bh, {'op': 'receive', 'envelope': envelope}))['duplicate'],
        true,
      );
      final history = await call(bh, {'op': 'history', 'account': av.id});
      expect((history['items'] as List).single['text'], marker);
      await messagingChannel.invokeMethod<void>('validationReopen', bh);
      final restored = await call(bh, {
        'op': 'initialize',
        'account': bv.id,
        'device': bv.deviceId,
      });
      expect(restored['curve'], bp['curve']);
      expect(
        ((await call(bh, {'op': 'history', 'account': av.id}))['items'] as List)
            .single['text'],
        marker,
      );
      await call(bh, {
        'op': 'send',
        'account': av.id,
        'text': 'M4_TEST_NATIVE_reply',
      });
      final reply = Map<String, dynamic>.from(
        ((await call(bh, {'op': 'outbox'}))['items'] as List).single as Map,
      )..addAll({'sender': bv.id, 'sender_device': bv.deviceId});
      await call(ah, {'op': 'receive', 'envelope': reply});
      expect(
        ((await call(ah, {'op': 'history', 'account': bv.id}))['items'] as List)
            .length,
        2,
      );
      expect(
        (await call(ah, {
          'op': 'validation_scan',
          'marker': marker,
        }))['plaintext_found'],
        false,
      );
      expect(
        (await call(bh, {
          'op': 'validation_scan',
          'marker': marker,
        }))['plaintext_found'],
        false,
      );
      // Application interactions use the same authenticated native ratchet.
      // No plaintext event fields are sent outside the encrypted envelope.
      Future<void> transfer(
        String from,
        String to,
        IdentityView sender, {
        bool reverse = false,
      }) async {
        final pending = ((await call(from, {'op': 'outbox'}))['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final packet in reverse ? pending.reversed : pending) {
          packet.remove('local_created');
          packet.addAll({
            'sender': sender.id,
            'sender_device': sender.deviceId,
          });
          await call(to, {'op': 'receive', 'envelope': packet});
          expect(
            (await call(to, {
              'op': 'receive',
              'envelope': packet,
            }))['duplicate'],
            true,
          );
          await call(from, {
            'op': 'state',
            'id': packet['id'],
            'state': 'accepted',
          });
        }
      }

      Future<List<Map<String, dynamic>>> messages(
        String handle,
        String account,
      ) async =>
          ((await call(handle, {'op': 'history', 'account': account}))['items']
                  as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
      final original = {'id': envelope['id'], 'sender_device': av.deviceId};
      final bobOriginal = {'id': reply['id'], 'sender_device': bv.deviceId};
      await transfer(ah, bh, av);
      await transfer(bh, ah, bv);
      await expectLater(
        call(ah, {
          'op': 'send',
          'account': bv.id,
          'kind': 'reaction',
          'target': original,
          'emoji': '🔥',
        }),
        throwsA(isA<PlatformException>()),
      );
      await call(ah, {'op': 'send', 'account': bv.id, 'kind': 'capabilities'});
      await transfer(ah, bh, av);
      await transfer(bh, ah, bv);
      expect(
        (await call(ah, {'op': 'peer', 'account': bv.id}))['interactions'],
        true,
      );
      expect(
        (await call(bh, {'op': 'peer', 'account': av.id}))['interactions'],
        true,
      );
      expect(
        (await messages(ah, bv.id!)).length,
        2,
        reason: 'Control events must not appear as messages',
      );
      final answered = await call(ah, {
        'op': 'send',
        'account': bv.id,
        'text': 'M4_TEST_NATIVE_answer',
        'reply': bobOriginal,
      });
      await transfer(ah, bh, av);
      final answer = (await messages(
        bh,
        av.id!,
      )).singleWhere((m) => m['id'] == answered['id']);
      expect(answer['reply'], bobOriginal);
      expect(answer['reply_preview']['text'], 'M4_TEST_NATIVE_reply');

      await call(ah, {
        'op': 'send',
        'account': bv.id,
        'kind': 'reaction',
        'target': bobOriginal,
        'emoji': '👍',
      });
      final mutation = Map<String, dynamic>.from(
        ((await call(ah, {'op': 'outbox'}))['items'] as List).single as Map,
      )..addAll({'sender': av.id, 'sender_device': av.deviceId});
      await expectLater(
        call(bh, {
          'op': 'receive',
          'envelope': mutation,
          'fail_before_commit': true,
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(
        ((await messages(
              bh,
              av.id!,
            )).singleWhere((m) => m['id'] == reply['id'])['reactions']
            as List),
        isEmpty,
      );
      expect(
        (await call(bh, {'op': 'outbox'}))['items'],
        isEmpty,
        reason: 'No acknowledgement before commit',
      );
      await transfer(ah, bh, av);
      await transfer(bh, ah, bv);

      await expectLater(
        call(bh, {
          'op': 'send',
          'account': av.id,
          'kind': 'edit',
          'target': original,
          'text': 'M4_TEST_FORGED_EDIT',
        }),
        throwsA(isA<PlatformException>()),
      );
      expect((await call(bh, {'op': 'outbox'}))['items'], isEmpty);
      for (final emoji in ['🔥', '❤️', '']) {
        await call(bh, {
          'op': 'send',
          'account': av.id,
          'kind': 'reaction',
          'target': original,
          'emoji': emoji,
        });
        await transfer(bh, ah, bv);
        await transfer(ah, bh, av);
        final reactions =
            (await messages(
                  ah,
                  bv.id!,
                )).singleWhere((m) => m['id'] == envelope['id'])['reactions']
                as List;
        expect(
          reactions.map((e) => e['emoji']).toList(),
          emoji.isEmpty ? [] : [emoji],
        );
      }
      for (final text in [
        'M4_TEST_NATIVE_edit_one',
        'M4_TEST_NATIVE_edited_Հայերեն',
      ]) {
        await call(ah, {
          'op': 'send',
          'account': bv.id,
          'kind': 'edit',
          'target': original,
          'text': text,
        });
      }
      await messagingChannel.invokeMethod<void>('validationReopen', ah);
      await transfer(ah, bh, av, reverse: true);
      await transfer(bh, ah, bv);
      final edited = (await messages(
        bh,
        av.id!,
      )).singleWhere((m) => m['id'] == envelope['id']);
      expect(edited['text'], 'M4_TEST_NATIVE_edited_Հայերեն');
      expect(edited['edited'], true);
      expect(
        (await messages(
          ah,
          bv.id!,
        )).singleWhere((m) => m['id'] == envelope['id'])['change_state'],
        'applied',
      );
      await call(ah, {
        'op': 'pin',
        'account': bv.id,
        'target': original,
        'value': true,
      });
      await messagingChannel.invokeMethod<void>('validationReopen', ah);
      expect(
        (await call(ah, {'op': 'peer', 'account': bv.id}))['pinned_message'],
        '${av.deviceId}:${envelope['id']}',
      );
      expect(
        (await call(bh, {'op': 'peer', 'account': av.id}))['pinned_message'],
        isNull,
      );
      final around = await call(ah, {
        'op': 'around',
        'account': bv.id,
        'target': original,
      });
      expect((around['items'] as List).first['id'], envelope['id']);
      await call(ah, {
        'op': 'pin',
        'account': bv.id,
        'target': original,
        'value': false,
      });
      final forwarded = await call(ah, {
        'op': 'send',
        'account': bv.id,
        'text': edited['text'],
        'forwarded': true,
      });
      final fresh =
          ((await call(ah, {'op': 'outbox'}))['items'] as List).single;
      expect(fresh['ciphertext'], isNot(envelope['ciphertext']));
      await transfer(ah, bh, av);
      final copied = (await messages(
        bh,
        av.id!,
      )).singleWhere((m) => m['id'] == forwarded['id']);
      expect(copied['forwarded'], true);
      expect(copied.containsKey('forwarded_from'), false);
      await call(bh, {
        'op': 'local_delete',
        'account': av.id,
        'target': original,
      });
      await messagingChannel.invokeMethod<void>('validationReopen', bh);
      expect(
        (await messages(bh, av.id!)).any((m) => m['id'] == envelope['id']),
        false,
      );
      expect(
        (await messages(ah, bv.id!)).any((m) => m['id'] == envelope['id']),
        true,
      );
      final forwardRef = {'id': forwarded['id'], 'sender_device': av.deviceId};
      await expectLater(
        call(bh, {
          'op': 'send',
          'account': av.id,
          'kind': 'delete',
          'target': forwardRef,
        }),
        throwsA(isA<PlatformException>()),
      );
      await call(ah, {
        'op': 'send',
        'account': bv.id,
        'kind': 'delete',
        'target': forwardRef,
      });
      expect(
        (await messages(
          ah,
          bv.id!,
        )).singleWhere((m) => m['id'] == forwarded['id'])['change_state'],
        'queued',
      );
      await transfer(ah, bh, av);
      expect(
        (await messages(
          ah,
          bv.id!,
        )).singleWhere((m) => m['id'] == forwarded['id'])['change_state'],
        'accepted',
      );
      final tombstone = (await messages(
        bh,
        av.id!,
      )).singleWhere((m) => m['id'] == forwarded['id']);
      expect(tombstone['deleted'], true);
      expect(tombstone['text'], '');
      await transfer(bh, ah, bv);
      expect(
        (await messages(
          ah,
          bv.id!,
        )).singleWhere((m) => m['id'] == forwarded['id'])['change_state'],
        'applied',
      );
      await expectLater(
        call(ah, {
          'op': 'send',
          'account': bv.id,
          'kind': 'edit',
          'target': forwardRef,
          'text': 'M4_TEST_RESURRECTION',
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(
        (await call(ah, {
          'op': 'validation_scan',
          'marker': 'M4_TEST_NATIVE_edited_Հայերեն',
        }))['plaintext_found'],
        false,
      );
      debugPrint(
        'UX_NATIVE_INTERACTIONS: capabilities, reply, reaction/change/remove, edit ordering, forward, local pin, local delete, shared delete and durable ack PASS',
      );

      final batch = await call(ah, {
        'op': 'send_many',
        'account': bv.id,
        'items': [
          {'text': 'M4_TEST_BATCH_ONE'},
          {'text': 'M4_TEST_BATCH_TWO'},
        ],
      });
      final batchIds = (batch['items'] as List).map((v) => v['id']).toSet();
      await transfer(ah, bh, av);
      final originals = (await messages(
        ah,
        bv.id!,
      )).where((m) => batchIds.contains(m['id'])).toList();
      final batchTargets = originals
          .map((m) => {'id': m['id'], 'sender_device': m['sender_device']})
          .toList();
      final foreign = (await messages(
        ah,
        bv.id!,
      )).firstWhere((m) => m['sender'] == bv.id);
      final beforeBatch = await call(ah, {'op': 'outbox'});
      await expectLater(
        call(ah, {
          'op': 'send_many',
          'account': bv.id,
          'items': [
            {'kind': 'delete', 'target': batchTargets.first},
            {
              'kind': 'delete',
              'target': {
                'id': foreign['id'],
                'sender_device': foreign['sender_device'],
              },
            },
          ],
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(await call(ah, {'op': 'outbox'}), beforeBatch);
      expect(
        (await messages(ah, bv.id!))
            .where((m) => batchIds.contains(m['id']))
            .every((m) => m['deleted'] != true),
        true,
      );
      await call(ah, {
        'op': 'send_many',
        'account': bv.id,
        'items': batchTargets
            .map((t) => {'kind': 'delete', 'target': t})
            .toList(),
      });
      await transfer(ah, bh, av);
      await transfer(bh, ah, bv);
      expect(
        (await messages(ah, bv.id!))
            .where((m) => batchIds.contains(m['id']))
            .every((m) => m['change_state'] == 'applied'),
        true,
      );
      await call(bh, {
        'op': 'local_delete_many',
        'account': av.id,
        'targets': batchTargets,
      });
      expect(
        (await messages(bh, av.id!)).any((m) => batchIds.contains(m['id'])),
        false,
      );
      await call(ah, {
        'op': 'chat_preferences',
        'account': bv.id,
        'chat_pinned': true,
        'archived': true,
      });
      await messagingChannel.invokeMethod<void>('validationReopen', ah);
      final flags = await call(ah, {'op': 'peer', 'account': bv.id});
      expect(flags['chat_pinned'], true);
      expect(flags['archived'], true);
      await expectLater(
        call(ah, {
          'op': 'delete_chat',
          'account': bv.id,
          'fail_before_commit': true,
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(await messages(ah, bv.id!), isNotEmpty);
      await call(ah, {'op': 'delete_chat', 'account': bv.id});
      await messagingChannel.invokeMethod<void>('validationReopen', ah);
      expect(await messages(ah, bv.id!), isEmpty);
      expect((await call(ah, {'op': 'conversations'}))['items'], isEmpty);
      expect(
        (await call(ah, {'op': 'peer', 'account': bv.id}))['binding'],
        flags['binding'],
      );
      await call(bh, {
        'op': 'send',
        'account': av.id,
        'text': 'M4_TEST_CHAT_REOPENS_SAME_RATCHET',
      });
      await transfer(bh, ah, bv);
      expect(
        (await messages(ah, bv.id!)).single['text'],
        'M4_TEST_CHAT_REOPENS_SAME_RATCHET',
      );
      expect((await call(ah, {'op': 'conversations'}))['items'], hasLength(1));
      debugPrint(
        'UX_CHAT_BATCH: atomic ownership rollback, confirmed batch deletion, local bulk delete, persistent archive/pin, local chat deletion and same-ratchet reopening PASS',
      );

      final changed = {...bb, 'curve': ab['curve']};
      await expectLater(
        call(ah, {'op': 'trust', 'binding': changed}),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'change',
            'identity_changed',
          ),
        ),
      );
      await messagingChannel.invokeMethod<void>('validationReopen', ah);
      expect(
        (await call(ah, {'op': 'peer', 'account': bv.id}))['identity_changed'],
        true,
      );
      for (final attempt in [
        {'op': 'send', 'account': bv.id, 'text': 'M4_TEST_BLOCKED'},
        {'op': 'trust', 'binding': bb},
        {'op': 'verify', 'account': bv.id, 'verified': true},
      ]) {
        await expectLater(
          call(ah, attempt),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'persistent identity-change rejection',
              'identity_changed',
            ),
          ),
        );
      }
      for (final op in ['initialize', 'send', 'receive', 'history']) {
        final samples = timings[op]!;
        final maximum = samples.reduce((a, b) => a > b ? a : b);
        // Timings only: no account identifiers, plaintext, keys or envelopes.
        debugPrint(
          'M4_NATIVE_TIMING $op count=${samples.length} max_us=$maximum',
        );
      }
    },
  );
}
