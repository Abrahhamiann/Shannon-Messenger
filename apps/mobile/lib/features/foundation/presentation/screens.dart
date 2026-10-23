import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app.dart';
import '../../../core/api/health_api.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 96,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
              const Text(
                'Shannon',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
              ),
              Text(
                'Private Messenger',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Real conversations.\nYour privacy. Always.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 36),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.layers_outlined, color: Color(0xFF60A5FA)),
                title: Text('Project foundation'),
                subtitle: Text('Milestone 1 · Development build'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.dns_outlined, color: Color(0xFF60A5FA)),
                title: Text('A real connection'),
                subtitle: Text('Flutter → Go → PostgreSQL'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/chats'),
                child: const Text('Open Shannon'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/connection'),
                child: const Text('Check backend connection'),
              ),
              const SizedBox(height: 20),
              Text(
                'Identity, encryption, messaging, and calls are not implemented yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  static const paths = ['/chats', '/calls', '/contacts', '/settings'];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: paths.indexOf(path).clamp(0, 3),
      onDestinationSelected: (index) => context.go(paths[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'Chats',
        ),
        NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Calls'),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'Contacts',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    ),
  );
}

class PendingScreen extends StatelessWidget {
  const PendingScreen({
    required this.title,
    required this.icon,
    required this.message,
    required this.detail,
    super.key,
  });
  final String title, message, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title == 'Chats' ? 'Shannon' : title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (title == 'Chats') ...[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 18),
                  SizedBox(width: 10),
                  Text('Chats', style: TextStyle(color: Color(0xFF60A5FA))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('S')),
            title: Text('Shannon'),
            subtitle: Text('Foundation build · No identity created'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('Appearance'),
                subtitle: Text('Choose your theme for this session'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 8,
                  children: ThemeMode.values
                      .map(
                        (mode) => ChoiceChip(
                          label: Text(switch (mode) {
                            ThemeMode.system => 'System',
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                          }),
                          selected: ref.watch(themeModeProvider) == mode,
                          onSelected: (_) => ref
                              .read(themeModeProvider.notifier)
                              .setMode(mode),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Backend connection'),
            subtitle: const Text('Check API and database availability'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/connection'),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About Shannon'),
            subtitle: Text('0.1.0 · Milestone 1'),
          ),
        ),
      ],
    ),
  );
}

class ConnectionScreen extends ConsumerWidget {
  const ConnectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(healthProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Backend connection')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: health.when(
                skipLoadingOnRefresh: false,
                data: (_) => const Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF22C55E),
                      size: 40,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Connected to Shannon',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Go API is healthy. PostgreSQL is reachable.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                loading: () => const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Checking API and database…'),
                  ],
                ),
                error: (_, _) => const Column(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 40),
                    SizedBox(height: 16),
                    Text(
                      'Connection unavailable',
                      style: TextStyle(fontSize: 20),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Check the backend, database, and API address, then retry.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SelectableText(apiBaseUrl, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: health.isLoading
                ? null
                : () => ref.invalidate(healthProvider),
            child: const Text('Check again'),
          ),
        ],
      ),
    );
  }
}
