import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class HealthFailure implements Exception {
  const HealthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Explicit USB development transport only. Keep the stored account/server
/// binding unchanged; adb reverse reaches that same local development backend.
Uri apiTransportUri(Uri logical) {
  if (kDebugMode &&
      const bool.fromEnvironment('ANDROID_ADB_REVERSE') &&
      logical.scheme == 'http' &&
      logical.host == '10.0.2.2') {
    return logical.replace(host: '127.0.0.1');
  }
  return logical;
}

class HealthApi {
  HealthApi(this.client, this.baseUrl);
  final http.Client client;
  final String baseUrl;
  Future<void> check() async {
    final base = apiTransportUri(Uri.parse(baseUrl));
    if (!base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        (kReleaseMode && base.scheme != 'https')) {
      throw const FormatException(
        'Valid API URL required; release builds require HTTPS.',
      );
    }
    late http.Response response;
    try {
      response = await client
          .get(base.resolve('/health'))
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      throw const HealthFailure(
        'The server did not respond in time. Retry when the connection improves.',
      );
    } on http.ClientException {
      throw const HealthFailure(
        'The backend cannot be reached. Check your connection and development port forwarding.',
      );
    }
    if (response.statusCode == 503) {
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map &&
            payload['service'] == 'shannon-api' &&
            payload['database'] == 'down') {
          throw const HealthFailure(
            'Shannon is reachable, but its database is unavailable.',
          );
        }
      } on FormatException {
        /* Fall through to sanitized status. */
      }
    }
    if (response.statusCode != 200) {
      throw HealthFailure(
        response.statusCode == 401 || response.statusCode == 403
            ? 'The server rejected access. This is not a network failure.'
            : 'The backend returned an error. Please retry.',
      );
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['status'] != 'ok' ||
        data['database'] != 'up' ||
        data['service'] != 'shannon-api') {
      throw const FormatException('Unexpected health response.');
    }
  }
}

final healthApiProvider = Provider<HealthApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return HealthApi(client, apiBaseUrl);
});
// No background polling or automatic retry.
final healthProvider = FutureProvider.autoDispose<void>(
  (ref) => ref.watch(healthApiProvider).check(),
  retry: (_, _) => null,
);
