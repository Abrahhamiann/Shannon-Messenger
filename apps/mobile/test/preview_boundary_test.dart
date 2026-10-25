import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/identity/presentation/preview_boundary.dart';

class _Controller extends IdentityController {
  _Controller(this.stage);
  final IdentityStage stage;
  @override
  Future<IdentityView> build() async => IdentityView(stage);
}

void main() {
  for (final stage in IdentityStage.values) {
    testWidgets('sample content only when no identity exists: ${stage.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityControllerProvider.overrideWith(() => _Controller(stage)),
          ],
          child: const MaterialApp(
            home: IdentityPreviewBoundary(
              section: 'Chats',
              preview: Text('SAMPLE CONVERSATION'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('SAMPLE CONVERSATION'),
        stage == IdentityStage.none ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
