import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shannon/core/api/health_api.dart';

void main() {
  test('health URL and response contract', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://localhost:8080/health');
      return http.Response(
        '{"status":"ok","database":"up","service":"shannon-api"}',
        200,
      );
    });
    addTearDown(client.close);
    await HealthApi(client, 'http://localhost:8080').check();
  });
  for (final body in ['{}', 'not json', '{"status":"ok","database":"down"}']) {
    test('rejects invalid health: $body', () async {
      final client = MockClient((_) async => http.Response(body, 200));
      addTearDown(client.close);
      await expectLater(
        HealthApi(client, 'http://localhost:8080').check(),
        throwsFormatException,
      );
    });
  }
}
