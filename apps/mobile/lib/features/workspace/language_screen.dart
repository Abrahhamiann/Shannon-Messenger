import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/strings.dart';

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    Future.microtask(() async {
      try {
        final saved = await SharedPreferencesAsync().getString(
          'shannon_locale',
        );
        if (ref.mounted && ['en', 'hy', 'ru'].contains(saved)) {
          state = Locale(saved!);
        }
      } catch (_) {
        /* English remains the fallback. */
      }
    });
    return const Locale('en');
  }

  Future<void> select(String code) async {
    if (!['en', 'hy', 'ru'].contains(code)) return;
    await SharedPreferencesAsync().setString('shannon_locale', code);
    if (ref.mounted) state = Locale(code);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(strings(context).language)),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(strings(context).languageNote),
        const SizedBox(height: 24),
        for (final item in [
          ('en', 'English'),
          ('hy', 'Հայերեն'),
          ('ru', 'Русский'),
        ])
          ListTile(
            title: Text(item.$2),
            selected: ref.watch(localeProvider).languageCode == item.$1,
            trailing: ref.watch(localeProvider).languageCode == item.$1
                ? const Icon(Icons.check)
                : null,
            onTap: () async {
              try {
                await ref.read(localeProvider.notifier).select(item.$1);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Language preference could not be saved.'),
                    ),
                  );
                }
              }
            },
          ),
      ],
    ),
  );
}
