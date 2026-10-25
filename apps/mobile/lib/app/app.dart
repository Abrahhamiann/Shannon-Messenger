import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/foundation/presentation/screens.dart' show ConnectionScreen;
import '../features/onboarding/welcome_screen.dart';
import '../features/milestone2/presentation/m2_screens.dart';
import '../features/identity/presentation/identity_screen.dart';
import '../features/identity/presentation/profile_route.dart';
import '../features/identity/presentation/preview_boundary.dart';
import '../features/workspace/hub_screens.dart';
import '../features/workspace/conversation_screen.dart';
import '../features/workspace/connection_screens.dart';
import '../features/workspace/settings_screen.dart';
import 'theme.dart';

class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'shannon_theme_mode';
  @override
  ThemeMode build() {
    Future.microtask(_load);
    return ThemeMode.dark;
  }

  Future<void> _load() async {
    try {
      final value = await SharedPreferencesAsync().getString(_key);
      if (!ref.mounted) return;
      if (value == 'light') state = ThemeMode.light;
      if (value == 'dark') state = ThemeMode.dark;
      if (value == 'system') state = ThemeMode.system;
    } catch (_) {
      // Appearance preference is optional; don't block app startup.
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    Future.microtask(() async {
      try {
        await SharedPreferencesAsync().setString(_key, mode.name);
      } catch (_) {
        // Do not claim that an unavailable storage operation succeeded.
      }
    });
  }
}

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/identity', builder: (_, _) => const IdentityScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileRoute()),
      GoRoute(
        path: '/contacts/add',
        builder: (_, _) => const ContactExchangeScreen(),
      ),
      GoRoute(
        path: '/contacts/requests',
        builder: (_, _) => const ContactExchangeScreen(requests: true),
      ),
      GoRoute(path: '/groups/new', builder: (_, _) => const GroupScreen()),
      GoRoute(
        path: '/calls/preview',
        builder: (_, state) => CallPreviewScreen(
          video: state.uri.queryParameters['video'] == 'true',
        ),
      ),
      GoRoute(
        path: '/settings/:section',
        builder: (_, state) =>
            PreferenceScreen(section: state.pathParameters['section']!),
      ),
      GoRoute(
        path: '/identity/restore',
        builder: (_, _) => const RestoreIdentityScreen(),
      ),
      GoRoute(
        path: '/identity/devices',
        builder: (_, _) => const IdentityDevicesScreen(),
      ),
      GoRoute(path: '/connection', builder: (_, _) => const ConnectionScreen()),
      ShellRoute(
        builder: (_, state, child) =>
            ShannonShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
          GoRoute(path: '/calls', builder: (_, _) => const CallsScreen()),
          GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/conversation/:id',
        builder: (_, _) => const ConversationScreen(),
      ),
      GoRoute(
        path: '/preview/:id',
        builder: (_, state) => IdentityPreviewBoundary(
          section: 'Feature',
          preview: FeaturePreviewPage(id: state.pathParameters['id']!),
        ),
      ),
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
