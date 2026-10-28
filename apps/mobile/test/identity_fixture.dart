import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:http/http.dart' as http;

class NoIdentityController extends IdentityController {
  @override
  Future<IdentityView> build() async => const IdentityView(IdentityStage.none);
}

class AuthenticatedIdentityController extends IdentityController {
  @override
  Future<IdentityView> build() async =>
      const IdentityView(IdentityStage.authenticated, id: 'test-account');
}

class FixtureRepository extends IdentityRepository {
  FixtureRepository() : super(AndroidKeyStore(), http.Client());
  @override
  Future<Map<String, dynamic>> contactRequest(
    String method,
    String operation, [
    Map<String, dynamic>? body,
  ]) async => {'items': <Map<String, dynamic>>[], 'next': ''};
}
