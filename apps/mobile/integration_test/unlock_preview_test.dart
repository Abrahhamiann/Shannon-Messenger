import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shannon/features/messaging/messaging_controller.dart';

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('render isolated static native unlock component previews',(tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Text('Isolated native component preview'))));
    for(final dark in [true,false]) {
      final path=await messagingChannel.invokeMethod<String>('validationRenderUnlock',{'dark':dark});
      expect(path,endsWith('ux-unlock-${dark?'dark':'light'}.png'));
    }
  });
}
