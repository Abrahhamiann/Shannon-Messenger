import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

class HealthApi {
  HealthApi(this.client, this.baseUrl);
  final http.Client client;
  final String baseUrl;
  Future<void> check() async {
    final base = Uri.parse(baseUrl);
    if (!base.hasAuthority ||
        !['http', 'https'].contains(base.scheme) ||
        (kReleaseMode && base.scheme != 'https')) {
      throw const FormatException(
        'Valid API URL required; release builds require HTTPS.',
      );
    }
    final response = await client
        .get(base.resolve('/health'))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('Backend is not ready.');
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
