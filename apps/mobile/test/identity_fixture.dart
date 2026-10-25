import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';

class NoIdentityController extends IdentityController {
  @override
  Future<IdentityView> build() async => const IdentityView(IdentityStage.none);
}
