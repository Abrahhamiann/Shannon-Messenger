import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shannon/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android launches and navigates to settings', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Open Shannon'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Shannon'));
    await tester.pumpAndSettle();
    expect(
      find.text('UI PREVIEW В· No real accounts or messages'),
      findsOneWidget,
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('APPEARANCE'), findsOneWidget);
  });
}
