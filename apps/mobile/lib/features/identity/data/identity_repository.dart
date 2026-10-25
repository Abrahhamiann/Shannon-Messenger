import 'dart:convert';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/health_api.dart';

const authAudience = String.fromEnvironment(
  'AUTH_AUDIENCE',
  defaultValue: 'shannon.local',
);
const jwsHeader = '{"alg":"Ed25519","typ":"shannon-auth-v1"}';
String encode64(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');
List<int> decode64(String text) => base64Url.decode(base64Url.normalize(text));

abstract interface class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class AndroidKeyStore implements SecureKeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: false,
      storageNamespace: 'shannon_identity_v1',
    ),
  );
  void _supported() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const IdentityFailure(
        'Identity storage is currently supported on Android only.',
      );
    }
  }

  @override
  Future<String?> read(String key) {
    _supported();
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    _supported();
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    _supported();
    return _storage.delete(key: key);
  }
}

class IdentityFailure implements Exception {
  const IdentityFailure(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

enum IdentityStage {
  none,
  local,
  authenticated,
  expired,
  offline,
  storageUnavailable,
  revoked,
}

class IdentityView {
  const IdentityView(
    this.stage, {
    this.id,
    this.deviceId,
    this.nickname = '',
    this.message,
    this.validUntil,
  });
  final IdentityStage stage;
  final String? id, deviceId, message;
  final String nickname;
  final DateTime? validUntil;
}

class DeviceView {
  const DeviceView(this.id, this.revoked);
  final String id;
  final bool revoked;
}

Future<String> publicID(List<int> publicKey, String prefix) async {
  final canonical =
      '{"crv":"Ed25519","kty":"OKP","x":"${encode64(publicKey)}"}';
  final digest = await Sha256().hash(utf8.encode(canonical));
  return '$prefix${encode64(digest.bytes)}';
}

/// Seeds and bearer tokens are confined to this service and encrypted storage.
/// No seed, token, or mnemonic is returned to presentation providers.
class IdentityRepository {
  IdentityRepository(
    this.store,
    this.client, {
    this.baseUrl = apiBaseUrl,
    this.audience = authAudience,
  });
  final SecureKeyStore store;
  final http.Client client;
  final String baseUrl, audience;
  final _algorithm = Ed25519();
  static const identityKey = 'identity_v1';
  static const sessionKey = 'session_v1';
  SimpleKeyPairData? _root, _device;
  String _nickname = '';
  bool _registered = false, _revoked = false;

  Future<IdentityView> _view(IdentityStage stage, [String? message]) async {
    if (_root == null || _device == null) {
      return IdentityView(stage, message: message);
    }
    return IdentityView(
      stage,
      id: await publicID(_root!.publicKey.bytes, 'shn1_'),
      deviceId: await publicID(_device!.publicKey.bytes, 'dev1_'),
      nickname: _nickname,
      message: message,
    );
  }

  Future<bool> _load() async {
    final raw = await store.read(identityKey);
    if (raw == null) {
      _root = null;
      _device = null;
      return false;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['audience'] != audience ||
        data['server'] != baseUrl) {
      throw const IdentityFailure(
        'Stored identity belongs to a different configuration. No data was changed.',
      );
    }
    final rootSeed = decode64(data['root_seed'] as String);
    final deviceSeed = decode64(data['device_seed'] as String);
    if (rootSeed.length != 32 ||
        deviceSeed.length != 32 ||
        listEquals(rootSeed, deviceSeed)) {
      throw const IdentityFailure(
        'Identity storage is invalid. No data was changed.',
      );
    }
    _root = await (await _algorithm.newKeyPairFromSeed(rootSeed)).extract();
    _device = await (await _algorithm.newKeyPairFromSeed(deviceSeed)).extract();
    _registered = data['registered'] == true;
    _revoked = data['revoked'] == true;
    _nickname = data['nickname'] as String? ?? '';
    return true;
  }

  Future<void> _persist() => store.write(
    identityKey,
    jsonEncode({
      'version': 1,
      'audience': audience,
      'server': baseUrl,
      'root_seed': encode64(_root!.bytes),
      'device_seed': encode64(_device!.bytes),
      'registered': _registered,
      'revoked': _revoked,
      'nickname': _nickname,
    }),
  );
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final base = Uri.parse(baseUrl);
    final local = ['127.0.0.1', 'localhost', '10.0.2.2'].contains(base.host);
    if (!base.hasAuthority ||
        base.userInfo.isNotEmpty ||
        (base.scheme != 'https' &&
            !(kDebugMode && base.scheme == 'http' && local))) {
      throw const IdentityFailure(
        'Authentication requires HTTPS (local debug transport only is excepted).',
      );
    }
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      method,
      base.resolve(path),
      abortTrigger: abort.future,
    );
    request.followRedirects = false; // Never forward credentials to a redirect.
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final deadline = Timer(const Duration(seconds: 10), () => abort.complete());
    late http.Response response;
    try {
      response = await (() async {
        final stream = await client.send(request);
        final bytes = <int>[];
        await for (final chunk in stream.stream) {
          if (bytes.length + chunk.length > 65536) {
            throw const IdentityFailure(
              'Authentication response exceeded its size limit.',
            );
          }
          bytes.addAll(chunk);
        }
        return http.Response.bytes(
          bytes,
          stream.statusCode,
          headers: stream.headers,
        );
      })().timeout(const Duration(seconds: 10));
    } finally {
      deadline.cancel();
      if (!abort.isCompleted) abort.complete();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IdentityFailure(
        response.statusCode == 401
            ? 'Authentication expired or device unavailable.'
            : 'Server did not accept the operation. Local identity is preserved.',
        response.statusCode,
      );
    }
    if (response.statusCode == 204) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<IdentityView> create(String nickname) async {
    // Recheck persistent state; a second create never overwrites an existing key.
    if (await _load()) {
      throw const IdentityFailure('An identity already exists on this device.');
    }
    final validatedName = _validateNickname(nickname);
    _root = await (await _algorithm.newKeyPair()).extract();
    _device = await (await _algorithm.newKeyPair()).extract();
    _nickname = validatedName;
    _registered = false;
    _revoked = false;
    await _persist();
    if (!await _load()) {
      throw const IdentityFailure('Identity storage could not be verified.');
    }
    return _view(
      IdentityStage.local,
      'Identity saved locally. Connect to register this device.',
    );
  }

  /// Local profile metadata only. Never changes keys or contacts the server.
  Future<void> updateNickname(String nickname) async {
    final value = _validateNickname(nickname);
    if (!await _load()) {
      throw const IdentityFailure(
        'Create an identity before editing a profile.',
      );
    }
    final previous = _nickname;
    _nickname = value;
    try {
      await _persist();
    } catch (_) {
      _nickname = previous;
      rethrow;
    }
  }

  String _validateNickname(String nickname) {
    final value = nickname.trim();
    if (value.runes.length > 64 ||
        RegExp(r'[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]')
            .hasMatch(value)) {
      throw const IdentityFailure(
        'Use at most 64 characters without control characters.',
      );
    }
    return value;
  }

  Future<String> _proof(String payload, SimpleKeyPairData key) async {
    final input =
        '${encode64(utf8.encode(jwsHeader))}.${encode64(utf8.encode(payload))}';
    final signature = await _algorithm.sign(utf8.encode(input), keyPair: key);
    return '$input.${encode64(signature.bytes)}';
  }

  Future<IdentityView> connect() async {
    if (!await _load()) {
      throw const IdentityFailure('Create a local identity first.');
    }
    if (_revoked) return _view(IdentityStage.revoked);
    final purpose = _registered ? 'login' : 'register';
    final rootKey = encode64(_root!.publicKey.bytes),
        deviceKey = encode64(_device!.publicKey.bytes);
    final challenge = await _request(
      'POST',
      '/api/v1/auth/challenge',
      body: {'purpose': purpose, 'root_key': rootKey, 'device_key': deviceKey},
    );
    final raw = challenge['payload'] as String;
    final p = jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final checks = <String, bool>{
      'format': p.length == 7 && p['version'] == 1,
      'audience': p['audience'] == audience,
      'purpose': p['purpose'] == purpose,
      'account binding': p['root_key'] == rootKey,
      'device binding': p['device_key'] == deviceKey,
      'nonce':
          p['nonce'] is String &&
          p['nonce'] == challenge['nonce'] &&
          decode64(p['nonce'] as String).length == 32,
      // Server enforces a strict 120-second lifetime. Allow up to 30 seconds
      // of client/server clock skew when checking the upper bound locally.
      'expiry (check device clock)':
          p['exp'] is int &&
          (p['exp'] as int) > now &&
          (p['exp'] as int) <= now + 150,
    };
    for (final check in checks.entries) {
      if (!check.value) {
        throw IdentityFailure(
          'Rejected authentication challenge: ${check.key}.',
        );
      }
    }
    final response = await _request(
      'POST',
      purpose == 'register'
          ? '/api/v1/identities/register'
          : '/api/v1/auth/verify',
      body: {
        'nonce': challenge['nonce'],
        'device_proof': await _proof(raw, _device!),
        if (purpose == 'register') 'root_proof': await _proof(raw, _root!),
      },
    );
    await _acceptSession(response);
    _registered = true;
    await _persist();
    return _verifySession();
  }

  Future<void> _acceptSession(Map<String, dynamic> data) async {
    final view = await _view(IdentityStage.local);
    if (data['identity_id'] != view.id ||
        data['device_id'] != view.deviceId ||
        decode64(data['access_token'] as String).length != 32 ||
        decode64(data['refresh_token'] as String).length != 32 ||
        !DateTime.parse(data['expires_at'] as String).isAfter(DateTime.now())) {
      throw const IdentityFailure('Invalid session response.');
    }
    await store.write(sessionKey, jsonEncode(data));
  }

  Future<IdentityView> _verifySession() async {
    final raw = await store.read(sessionKey);
    if (raw == null) return _view(IdentityStage.local);
    var session = jsonDecode(raw) as Map<String, dynamic>;
    Map<String, dynamic> me;
    try {
      me = await _request(
        'GET',
        '/api/v1/identities/me',
        token: session['access_token'] as String,
      );
    } on IdentityFailure catch (e) {
      if (e.status != 401) rethrow;
      session = await _request(
        'POST',
        '/api/v1/auth/refresh',
        body: {'refresh_token': session['refresh_token']},
      );
      await _acceptSession(session);
      me = await _request(
        'GET',
        '/api/v1/identities/me',
        token: session['access_token'] as String,
      );
    }
    final view = await _view(IdentityStage.local);
    if (me['identity_id'] != view.id || me['device_id'] != view.deviceId) {
      throw const IdentityFailure('Server returned a different identity.');
    }
    final verified = await _view(IdentityStage.authenticated);
    return IdentityView(
      IdentityStage.authenticated,
      id: verified.id,
      deviceId: verified.deviceId,
      nickname: verified.nickname,
      validUntil: DateTime.parse(session['access_expires_at'] as String),
    );
  }

  Future<IdentityView> resume() async {
    try {
      if (!await _load()) return const IdentityView(IdentityStage.none);
    } catch (_) {
      return const IdentityView(
        IdentityStage.storageUnavailable,
        message: 'Secure storage is unavailable or invalid. No keys were erased. Do not uninstall or clear app data.',
      );
    }
    if (_revoked) return _view(IdentityStage.revoked);
    try {
      return await _verifySession();
    } on IdentityFailure catch (e) {
      return _view(
        e.status == 401 ? IdentityStage.expired : IdentityStage.offline,
        e.message,
      );
    } catch (_) {
      return _view(
        IdentityStage.offline,
        'Connection or session storage unavailable. Local identity is preserved.',
      );
    }
  }

  Future<String> _access() async {
    final view = await resume();
    if (view.stage != IdentityStage.authenticated) {
      throw const IdentityFailure('Sign in before continuing.');
    }
    final session =
        jsonDecode((await store.read(sessionKey))!) as Map<String, dynamic>;
    return session['access_token'] as String;
  }

  Future<List<DeviceView>> devices() async {
    final result = await _request(
      'GET',
      '/api/v1/devices',
      token: await _access(),
    );
    return (result['devices'] as List)
        .map((e) => DeviceView(e['id'] as String, e['revoked_at'] != null))
        .toList();
  }

  Future<IdentityView> logout() async {
    await _request('POST', '/api/v1/auth/logout', token: await _access());
    await store.delete(sessionKey);
    return _view(
      IdentityStage.local,
      'Session revoked. Local identity remains on this device.',
    );
  }

  Future<IdentityView> revokeThisDevice() async {
    final token = await _access();
    final view = await _view(IdentityStage.local);
    await _request('DELETE', '/api/v1/devices/${view.deviceId}', token: token);
    _revoked = true;
    await _persist();
    await store.delete(sessionKey);
    return _view(IdentityStage.revoked);
  }
}
