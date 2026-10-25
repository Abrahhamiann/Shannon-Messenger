import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/theme.dart';
import 'package:shannon/features/identity/presentation/profile_page.dart';

void main() {
  for (final dark in [true, false]) {
    testWidgets(
      'profile supports ${dark ? 'dark' : 'light'} theme and multilingual text',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await (FontLoader('ShannonPhosphorRegular')
                ..addFont(rootBundle.load('assets/icons/Phosphor-Regular.ttf')))
              .load();
          for (final entry in {
            'Manrope': 'Manrope[wght].ttf',
            'NotoSansArmenian': 'NotoSansArmenian[wdth,wght].ttf',
          }.entries) {
            await (FontLoader(
              entry.key,
            )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
          }
        });
        final capture = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? ShannonTheme.dark : ShannonTheme.light,
              home: ShannonProfilePage(
                nickname: 'Շենոն · Шеннон',
                publicId: 'shn1_public_visual_test_fixture',
                sessionLabel: 'Saved on this device · signed out',
                canLogout: false,
                onLogout: () async {},
                onEdit: () {},
                onDevices: () {},
                onSecurity: () {},
                onAvatar: () {},
                onCopy: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
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
                '../../docs/ui/profile-${dark ? 'dark' : 'light'}.png',
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
