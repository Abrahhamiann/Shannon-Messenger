import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

import '../identity/data/identity_repository.dart';

String messagingBinding(String audience, Map<String, dynamic> b) => [
  'shannon-messaging-key-v1',
  audience,
  b['account'],
  b['device'],
  b['suite'],
  b['epoch'].toString(),
  b['curve'],
  b['signing'],
].join('\n');
String messagingPrekey(Map<String, dynamic> b, Map<String, dynamic> p) => [
  'shannon-messaging-prekey-v1',
  b['account'],
  b['device'],
  b['epoch'].toString(),
  b['curve'],
  b['signing'],
  p['id'],
  p['key'],
].join('\n');
List<int> _bytes(Object? value, int size) {
  if (value is! String) {
    throw const IdentityFailure('Invalid messaging identity.');
  }
  final bytes = decode64(value);
  if (bytes.length != size || encode64(bytes) != value) {
    throw const IdentityFailure('Invalid messaging identity.');
  }
  return bytes;
}

Future<void> verifyMessagingBundle(
  Map<String, dynamic> bundle,
  String account,
  String audience,
) => Isolate.run(() => _verifyMessagingBundle(bundle, account, audience));

Future<void> _verifyMessagingBundle(
  Map<String, dynamic> bundle,
  String account,
  String audience,
) async {
  try {
    final root = _bytes(bundle['root_key'], 32),
        device = _bytes(bundle['device_key'], 32);
    _bytes(bundle['curve'], 32);
    final signing = _bytes(bundle['signing'], 32);
    if (bundle['account'] != account ||
        bundle['suite'] != 'olm.v1' ||
        bundle['epoch'] != 1 ||
        await publicID(root, 'shn1_') != account ||
        await publicID(device, 'dev1_') != bundle['device']) {
      throw const IdentityFailure('Messaging identity binding was rejected.');
    }
    final transcript = utf8.encode(messagingBinding(audience, bundle));
    for (final pair in [('account_proof', root), ('device_proof', device)]) {
      if (!await Ed25519().verify(
        transcript,
        signature: Signature(
          _bytes(bundle[pair.$1], 64),
          publicKey: SimplePublicKey(pair.$2, type: KeyPairType.ed25519),
        ),
      )) {
        throw const IdentityFailure(
          'Messaging identity authorization was rejected.',
        );
      }
    }
    final keys = bundle['prekeys'];
    if (keys is! List || keys.length > 50) {
      throw const IdentityFailure('Invalid prekey bundle.');
    }
    final seen = <String>{};
    for (final raw in keys) {
      final p = Map<String, dynamic>.from(raw as Map);
      _bytes(p['key'], 32);
      if (p['id'] != p['key'] ||
          !seen.add(p['id'] as String) ||
          !await Ed25519().verify(
            utf8.encode(messagingPrekey(bundle, p)),
            signature: Signature(
              _bytes(p['signature'], 64),
              publicKey: SimplePublicKey(signing, type: KeyPairType.ed25519),
            ),
          )) {
        throw const IdentityFailure('Recipient prekey signature was rejected.');
      }
    }
  } on IdentityFailure {
    rethrow;
  } catch (_) {
    throw const IdentityFailure('Invalid messaging identity or prekey.');
  }
}

/// Symmetric, versioned full-transcript fingerprint; not a Signal safety number.
Future<String> messagingFingerprint(
  Map<String, dynamic> own,
  Map<String, dynamic> peer,
  String audience,
) async {
  final sides = [
    messagingBinding(audience, own),
    messagingBinding(audience, peer),
  ]..sort();
  final digest = await Sha256().hash(
    utf8.encode('shannon-verify-v1\n${sides[0]}\n${sides[1]}'),
  );
  final hex = digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return List.generate(16, (i) => hex.substring(i * 4, i * 4 + 4)).join(' ');
}
