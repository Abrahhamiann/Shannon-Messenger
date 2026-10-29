import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/foundation/presentation/screens.dart' show ConnectionScreen;
import '../features/onboarding/welcome_screen.dart';
import '../features/onboarding/account_screen.dart';
import '../features/onboarding/security_screen.dart';
import '../features/identity/data/identity_repository.dart';
import '../features/identity/presentation/identity_controller.dart';
import '../features/milestone2/presentation/m2_screens.dart';
import '../features/identity/presentation/identity_screen.dart';
import '../features/identity/presentation/profile_route.dart';
import '../features/identity/presentation/preview_boundary.dart';
import '../features/workspace/hub_screens.dart';
import '../features/workspace/conversation_screen.dart';
import '../features/workspace/connection_screens.dart';
import '../features/workspace/settings_screen.dart';
import 'theme.dart';
import '../features/workspace/app_lock_screen.dart';
import '../features/workspace/language_screen.dart';
import '../features/workspace/notification_privacy_screen.dart';
import '../l10n/app_localizations.dart';
import 'screen_privacy.dart';
import '../features/contacts/contact_screen.dart';
import '../features/contacts/invite_state.dart';
import '../features/messaging/messaging_controller.dart';
import '../features/messaging/messaging_screens.dart';

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
  final privacyObserver = ScreenPrivacyObserver();
  final refresh = ValueNotifier<int>(0);
  IdentityView? stable = ref.read(identityControllerProvider).asData?.value;
  ref.listen(identityControllerProvider, (_, next) {
    stable = next.asData?.value ?? stable;
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (_, state) {
      final auth = ref.read(identityControllerProvider);
      final view = auth.asData?.value ?? stable;
      final path = state.uri.path;
      if (auth.hasError && path != '/account' && path != '/connection') {
        return '/account';
      }
      if (auth.isLoading) {
        if (['/', '/signup', '/account', '/contacts/add'].contains(path)) {
          return null;
        }
        if ([
          IdentityStage.authenticated,
          IdentityStage.offline,
        ].contains(view?.stage)) {
          return null;
        }
        return view == null ? '/' : '/account';
      }
      final stage = view?.stage ?? IdentityStage.storageUnavailable;
      if (stage == IdentityStage.registrationInterrupted &&
          path != '/signup' &&
          path != '/connection') {
        return '/signup';
      }
      final signedIn = stage == IdentityStage.authenticated;
      if (signedIn && ['/', '/signup', '/account'].contains(path)) {
        if (path == '/signup') return '/onboarding/success';
        return ref.read(pendingInvitationProvider) == null
            ? '/chats'
            : '/contacts/add';
      }
      if (path == '/' && stage != IdentityStage.none) return '/account';
      if (path == '/profile' &&
          stage == IdentityStage.expired &&
          view?.id != null) {
        return null;
      }
      if ([
        '/',
        '/signup',
        '/account',
        '/connection',
        '/contacts/add',
      ].contains(path)) {
        return null;
      }
      if (signedIn || (stage == IdentityStage.offline && view?.id != null)) {
        return null;
      }
      return '/account';
    },
    observers: [privacyObserver],
    routes: [
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/onboarding/success',
        builder: (_, _) => const AccountCreatedScreen(),
      ),
      GoRoute(
        path: '/onboarding/security',
        builder: (_, _) => const AccountSecurityScreen(),
      ),
      GoRoute(
        path: '/onboarding/recovery-phrase',
        builder: (_, _) => const RecoveryPhraseInfoScreen(),
      ),
      GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
      GoRoute(path: '/identity', builder: (_, _) => const IdentityScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileRoute()),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const NotificationPrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/language',
        builder: (_, _) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/settings/app-lock',
        builder: (_, _) => const AppLockScreen(),
      ),
      GoRoute(
        path: '/contacts/add',
        builder: (_, state) => ContactScreen(
          section: 'add',
          invitation:
              state.extra as String? ?? ref.read(pendingInvitationProvider),
        ),
      ),
      GoRoute(
        path: '/contacts/requests',
        builder: (_, _) => const ContactScreen(section: 'requests'),
      ),
      GoRoute(
        path: '/contacts/qr',
        builder: (_, _) => const ContactScreen(section: 'qr'),
      ),
      GoRoute(
        path: '/contacts/scan',
        builder: (_, _) => const ContactScanner(),
      ),
      GoRoute(
        path: '/contacts/privacy',
        builder: (_, _) => const ContactScreen(section: 'privacy'),
      ),
      GoRoute(
        path: '/contacts/blocked',
        builder: (_, _) => const ContactScreen(section: 'blocked'),
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
          GoRoute(path: '/contacts', builder: (_, _) => const ContactScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/conversation/:id/security',
        builder: (_, state) => SensitiveScreen(
          observer: privacyObserver,
          child: MessagingSecurityScreen(account: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/conversation/:id',
        builder: (_, state) => SensitiveScreen(
          observer: privacyObserver,
          child: m4MessagingEnabled
              ? PrivateConversationScreen(account: state.pathParameters['id']!)
              : const ConversationScreen(),
        ),
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

class ShannonApp extends ConsumerStatefulWidget {
  const ShannonApp({super.key});
  @override
  ConsumerState<ShannonApp> createState() => _ShannonAppState();
}

class _ShannonAppState extends ConsumerState<ShannonApp> {
  Brightness? _lockAppearance;
  @override
  void initState() {
    super.initState();
    if (nativePrivacy) {
      privacyChannel.setMethodCallHandler((call) async {
        if (call.method == 'invite' && mounted && call.arguments is String) {
          ref
              .read(pendingInvitationProvider.notifier)
              .save(call.arguments as String);
          ref
              .read(routerProvider)
              .push('/contacts/add', extra: call.arguments as String);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await privacyChannel.invokeMethod<void>('ready');
          final token = await privacyChannel.invokeMethod<String>(
            'initialInvite',
          );
          if (token != null && mounted) {
            ref.read(pendingInvitationProvider.notifier).save(token);
            ref.read(routerProvider).push('/contacts/add', extra: token);
          }
        } catch (_) {
          /* Native startup protection remains closed on failure. */
        }
      });
    }
  }

  @override
  void dispose() {
    if (nativePrivacy) privacyChannel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (m4MessagingEnabled) ref.watch(messagingProvider);
    final mode = ref.watch(themeModeProvider);
    final appearance = mode == ThemeMode.dark
        ? Brightness.dark
        : mode == ThemeMode.light
        ? Brightness.light
        : WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (nativePrivacy && appearance != _lockAppearance) {
      _lockAppearance = appearance;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await privacyChannel.invokeMethod<void>(
            'appearance',
            appearance.name,
          );
        } catch (_) {
          /* Keep the opaque native fallback. */
        }
      });
    }
    return MaterialApp.router(
      title: 'Shannon',
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ShannonTheme.light,
      darkTheme: ShannonTheme.dark,
      themeMode: mode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
