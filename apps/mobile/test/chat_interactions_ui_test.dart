import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/app/theme.dart';
import 'package:shannon/features/messaging/chat_components.dart';

Map<String, dynamic> message(String text) => {
  'id': 'preview',
  'sender': 'preview-owner',
  'sender_device': 'preview-device',
  'text': text,
  'timestamp': DateTime(2026, 10, 28, 14, 32).millisecondsSinceEpoch,
  'state': 'accepted',
  'reactions': [],
};

void main() {
  testWidgets(
    'short bubble is compact; long multilingual text scales without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      Widget bubble(String text, double scale) => MaterialApp(
        theme: ShannonTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: CompactMessageBubble(
                anchorKey: key,
                message: message(text),
                own: true,
                contactName: 'Preview',
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(bubble('Hello 👋', 1));
      expect(tester.getSize(find.byKey(key)).height, lessThan(75));
      expect(tester.getSize(find.byKey(key)).width, lessThan(190));
      final long = 'Հայերեն · Русский · English 👋 ' * 18;
      await tester.pumpWidget(bubble(long, 2));
      await tester.pumpAndSettle();
      expect(find.text(long), findsOneWidget);
      expect(
        tester.getSize(find.byKey(key)).width,
        lessThanOrEqualTo(390 * .82),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'menu survives tapped element deactivation and a later overlay layout',
    (tester) async {
      final key = GlobalKey();
      late StateSetter change;
      bool visible = true;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Scaffold(
                body: visible
                    ? TextButton(
                        key: key,
                        onPressed: () {
                          showShannonActions(
                            context,
                            anchor: key,
                            reactions: true,
                            reactionsEnabled: true,
                            actions: const [
                              FloatingActionItem('copy', 'Copy', Icons.copy),
                            ],
                          );
                          setState(() => visible = false);
                        },
                        child: const Text('Transient message'),
                      )
                    : const Text('History updated'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Transient message'));
      await tester.pumpAndSettle();
      change(() => visible = false);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final bottom in [0.0, 260.0]) {
    testWidgets(
      'anchored action panel stays onscreen with keyboard inset $bottom and Back dismisses',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final anchor = GlobalKey();
        MessageChoice? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ShannonTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(viewInsets: EdgeInsets.only(bottom: bottom)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      right: 10,
                      bottom: 80,
                      child: TextButton(
                        key: anchor,
                        onPressed: () async {
                          result = await showShannonActions(
                            context,
                            anchor: anchor,
                            reactions: true,
                            reactionsEnabled: true,
                            selectedReaction: '👍',
                            actions: const [
                              FloatingActionItem('reply', 'Reply', Icons.reply),
                              FloatingActionItem(
                                'edit',
                                'Edit',
                                Icons.edit_outlined,
                              ),
                              FloatingActionItem(
                                'copy',
                                'Copy',
                                Icons.copy_outlined,
                              ),
                              FloatingActionItem(
                                'pin',
                                'Pin',
                                Icons.push_pin_outlined,
                              ),
                              FloatingActionItem(
                                'forward',
                                'Forward',
                                Icons.shortcut_outlined,
                              ),
                              FloatingActionItem(
                                'delete',
                                'Delete',
                                Icons.delete_outline,
                              ),
                            ],
                          );
                        },
                        child: const Text('Selected message'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Selected message'));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.text('Delete'));
        expect(rect.bottom, lessThanOrEqualTo(844 - bottom));
        expect(rect.right, lessThanOrEqualTo(390));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Reply'), findsNothing);
        await tester.tap(find.text('Selected message'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('👍'));
        await tester.pumpAndSettle();
        expect(result?.action, 'reaction');
        expect(result?.value, '');
        await tester.tap(find.text('Selected message'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.text('Reply'), findsNothing);
      },
    );
  }
  testWidgets(
    'delete checkboxes are mutually exclusive and exactly one scope is required',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<DeleteScope>(
                  context: context,
                  builder: (_) =>
                      const DeleteConfirmation(canDeleteEveryone: true),
                ),
                child: const Text('Open deletion'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open deletion'));
      await tester.pumpAndSettle();
      FilledButton confirm() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(confirm().onPressed, isNull);
      await tester.tap(find.text('Delete for me'));
      await tester.pumpAndSettle();
      var checks = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(checks.map((e) => e.value), [true, false]);
      expect(confirm().onPressed, isNotNull);
      await tester.tap(find.text('Delete for everyone'));
      await tester.pumpAndSettle();
      checks = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(checks.map((e) => e.value), [false, true]);
      await tester.tap(find.text('Delete for everyone'));
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNull);
    },
  );
  testWidgets('unsupported shared deletion is visibly disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const DeleteConfirmation(canDeleteEveryone: false),
        ),
      ),
    );
    final everyone = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .last;
    expect(everyone.onChanged, isNull);
    expect(
      find.text('Only the sender can request shared deletion.'),
      findsOneWidget,
    );
  });
  for (final dark in [true, false]) {
    testWidgets('real component preview ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await (FontLoader('ShannonPhosphorRegular')
              ..addFont(rootBundle.load('assets/icons/Phosphor-Regular.ttf')))
            .load();
        if (Platform.isWindows &&
            await File('C:/Windows/Fonts/seguiemj.ttf').exists()) {
          final bytes = await File('C:/Windows/Fonts/seguiemj.ttf')
              .readAsBytes();
          await (FontLoader(
            'Noto Color Emoji',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        }
        for (final font in {
          'Manrope': 'Manrope[wght].ttf',
          'NotoSansArmenian': 'NotoSansArmenian[wdth,wght].ttf',
        }.entries) {
          await (FontLoader(
            font.key,
          )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
        }
      });
      final capture = GlobalKey(), anchor = GlobalKey();
      debugDisableShadows = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? ShannonTheme.dark : ShannonTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  leading: const BackButton(),
                  title: ConversationIdentityHeader(
                    name: 'Preview contact',
                    onTap: () {},
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 95),
                      CompactMessageBubble(
                        message: message('Բարև 👋'),
                        own: false,
                        contactName: 'Preview contact',
                        onTap: () {},
                        onLongPress: () {},
                      ),
                      const SizedBox(height: 6),
                      CompactMessageBubble(
                        anchorKey: anchor,
                        message: message(
                          'A little more room for the conversation.',
                        ),
                        own: true,
                        contactName: 'Preview contact',
                        onTap: () => showShannonActions(
                          context,
                          anchor: anchor,
                          reactions: true,
                          reactionsEnabled: true,
                          actions: const [
                            FloatingActionItem(
                              'reply',
                              'Reply',
                              Icons.reply_rounded,
                            ),
                            FloatingActionItem(
                              'edit',
                              'Edit',
                              Icons.edit_outlined,
                            ),
                            FloatingActionItem(
                              'copy',
                              'Copy',
                              Icons.copy_outlined,
                            ),
                            FloatingActionItem(
                              'pin',
                              'Pin',
                              Icons.push_pin_outlined,
                            ),
                            FloatingActionItem(
                              'forward',
                              'Forward',
                              Icons.shortcut_outlined,
                            ),
                            FloatingActionItem(
                              'delete',
                              'Delete',
                              Icons.delete_outline,
                            ),
                          ],
                        ),
                        onLongPress: () {},
                      ),
                      const Spacer(),
                      const Text(
                        'Component preview · synthetic text',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A little more room for the conversation.'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('EXPORT_UI_PREVIEWS')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          try {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '../../.local-test/ux-previews/message-menu-${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      debugDisableShadows = true;
    });
  }
}
