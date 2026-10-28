import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shannon/features/identity/data/identity_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/theme.dart';
import 'package:shannon/app/app.dart';
import 'package:shannon/features/onboarding/welcome_screen.dart';
import 'package:shannon/features/onboarding/account_screen.dart';
import 'package:shannon/features/onboarding/security_screen.dart';
import 'package:shannon/features/identity/presentation/identity_controller.dart';
import 'package:shannon/features/identity/presentation/identity_screen.dart';
import 'package:shannon/features/workspace/hub_screens.dart';
import 'package:shannon/features/workspace/conversation_screen.dart';
import 'package:shannon/features/workspace/connection_screens.dart';
import 'package:shannon/features/workspace/settings_screen.dart';

import 'identity_fixture.dart';
import 'identity_test.dart' show MemoryStore;

class _FixedTheme extends ThemeController {
  _FixedTheme(this.mode);
  final ThemeMode mode;
  @override
  ThemeMode build() => mode;
}

void main() {
  for (final dark in [true, false]) {
    for (final screen in <String, Widget>{
      'welcome': const WelcomeScreen(),
      'signup': const SignupScreen(),
      'created': const AccountCreatedScreen(),
      'secure-account': const AccountSecurityScreen(),
      'recovery-phrase-info': const RecoveryPhraseInfoScreen(),
      'identity': const IdentityScreen(),
      'recovery': const RestoreIdentityScreen(),
      'chats': const ChatsScreen(),
      'contacts': const ContactsScreen(),
      'calls': const CallsScreen(),
      'conversation': const ConversationScreen(),
      'settings': const SettingsScreen(),
      'add-contact': const ContactExchangeScreen(),
      'group': const GroupScreen(),
      'call-preview': const CallPreviewScreen(),
      'privacy': const PreferenceScreen(section: 'privacy'),
    }.entries) {
      testWidgets(
        '${screen.key} ${dark ? 'dark' : 'light'} phone layout contains no fabricated account activity',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
            for (final font in {
              'Manrope': 'fonts/Manrope[wght].ttf',
              'NotoSansArmenian': 'fonts/NotoSansArmenian[wdth,wght].ttf',
              'ShannonPhosphorRegular': 'icons/Phosphor-Regular.ttf',
            }.entries) {
              await (FontLoader(
                font.key,
              )..addFont(rootBundle.load('assets/${font.value}'))).load();
            }
          });
          final capture = GlobalKey();
          final previewClient = http.Client();
          addTearDown(previewClient.close);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                identityRepositoryProvider.overrideWithValue(
                  IdentityRepository(MemoryStore(), previewClient),
                ),
                themeModeProvider.overrideWith(
                  () => _FixedTheme(dark ? ThemeMode.dark : ThemeMode.light),
                ),
                identityControllerProvider.overrideWith(
                  NoIdentityController.new,
                ),
              ],
              child: RepaintBoundary(
                key: capture,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? ShannonTheme.dark : ShannonTheme.light,
                  builder: (_, child) => MediaQuery(
                    data: const MediaQueryData(
                      size: Size(390, 844),
                      disableAnimations: true,
                    ),
                    child: child!,
                  ),
                  home: screen.value,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/branding/shannon_ribbon.png'),
              tester.element(find.byType(MaterialApp)),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Maya'), findsNothing);
          expect(find.text('online'), findsNothing);
          if (const bool.fromEnvironment('EXPORT_UI_PREVIEWS')) {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final output = File(
                  '../../docs/ui/onboarding-2026-10-27/${screen.key}-${dark ? 'dark' : 'light'}.png',
                );
                await output.parent.create(recursive: true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
        },
      );
    }
  }
}
