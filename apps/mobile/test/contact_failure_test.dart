import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shannon/features/contacts/contact_screen.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';

import 'identity_test.dart' show MemoryStore;

void main() {
  test(
    'contact failures distinguish invitation lifecycle and connectivity',
    () {
      final expected = {
        'own_invitation': 'your own invitation',
        'invitation_invalid': 'invalid or no longer available',
        'invitation_expired': 'has expired',
        'invitation_revoked': 'revoked or replaced',
        'contact_not_found': 'Contact not found',
      };
      for (final item in expected.entries) {
        expect(
          contactFailureMessage(IdentityFailure('ignored', 404, item.key)),
          contains(item.value),
        );
      }
      expect(
        contactFailureMessage(http.ClientException('private transport detail')),
        contains('Could not connect'),
      );
      expect(
        contactFailureMessage(const IdentityFailure('ignored', 503)),
        contains('backend is unavailable'),
      );
      expect(
        contactFailureMessage(const IdentityFailure('ignored', 401)),
        contains('Sign in again'),
      );
    },
  );
  test('only allowlisted server codes cross into presentation', () async {
    for (final code in ['own_invitation', 'untrusted server text']) {
      final client = MockClient(
        (_) async => http.Response(
          '{"code":"$code","error":"sensitive raw error"}',
          404,
        ),
      );
      final repo = IdentityRepository(MemoryStore(), client);
      await repo.create('Saved');
      await expectLater(
        repo.connect(),
        throwsA(
          isA<IdentityFailure>()
              .having(
                (e) => e.code,
                'code',
                code == 'own_invitation' ? code : null,
              )
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('sensitive')),
              ),
        ),
      );
      client.close();
    }
  });
}
