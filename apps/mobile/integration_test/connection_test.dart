import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shannon/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android connects to Go and PostgreSQL', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Check backend connection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check backend connection'));
    for (
      var i = 0;
      i < 40 && find.text('Connected to Shannon').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Connected to Shannon'), findsOneWidget);
  });
}
