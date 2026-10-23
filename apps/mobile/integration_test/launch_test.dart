import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shannon/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android launches and navigates to settings', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open Shannon'));
    await tester.tap(find.text('Open Shannon'));
    await tester.pumpAndSettle();
    expect(find.text('Your conversations will appear here.'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });
}
