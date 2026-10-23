import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/foundation/presentation/screens.dart';
import 'theme.dart';

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;
  void setMode(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/chats',
            builder: (_, _) => const PendingScreen(
              title: 'Chats',
              icon: Icons.chat_bubble_outline,
              message: 'Your conversations will appear here.',
              detail: 'Messaging will be added in a later milestone.',
            ),
          ),
          GoRoute(
            path: '/calls',
            builder: (_, _) => const PendingScreen(
              title: 'Calls',
              icon: Icons.call_outlined,
              message: 'No calls yet',
              detail: 'Calling is not available in this foundation build.',
            ),
          ),
          GoRoute(
            path: '/contacts',
            builder: (_, _) => const PendingScreen(
              title: 'Contacts',
              icon: Icons.people_outline,
              message: 'Your private circle',
              detail: 'QR contacts and invitations are planned for a later milestone.',
            ),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: '/connection', builder: (_, _) => const ConnectionScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class ShannonApp extends ConsumerWidget {
  const ShannonApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Shannon',
    debugShowCheckedModeBanner: false,
    theme: ShannonTheme.light,
    darkTheme: ShannonTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    routerConfig: ref.watch(routerProvider),
  );
}
