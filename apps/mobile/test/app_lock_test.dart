import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/screen_privacy.dart';
import 'package:shannon/features/workspace/app_lock_screen.dart';
import 'package:shannon/l10n/app_localizations.dart';

void main() {
  for (final code in ['en', 'hy', 'ru']) {
    testWidgets(
      'App Lock $code authenticates settings and retains policy on cancellation',
      (tester) async {
        var enabled = false;
        var seconds = 0;
        var cancel = false;
        final calls = <String>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(privacyChannel, (call) async {
              calls.add(call.method);
              if (call.method == 'configureAppLock') {
                if (cancel) throw PlatformException(code: 'cancelled');
                enabled = call.arguments['enabled'] as bool;
                seconds = call.arguments['seconds'] as int;
              }
              return {
                'enabled': enabled,
                'seconds': seconds,
                'available': true,
              };
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(privacyChannel, null),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(code),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const AppLockScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(enabled, true);
        expect(tester.widget<Switch>(find.byType(Switch)).value, true);
        cancel = true;
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(enabled, true);
        expect(tester.widget<Switch>(find.byType(Switch)).value, true);
        expect(calls.where((c) => c == 'configureAppLock').length, 2);
      },
    );
  }
}
