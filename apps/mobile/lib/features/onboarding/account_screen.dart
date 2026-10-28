import '../../app/premium.dart';
import '../../l10n/strings.dart';

import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/design_system.dart';
import '../../app/widgets.dart';
import '../identity/data/identity_repository.dart';
import '../identity/data/avatar_repository.dart';
import '../identity/presentation/identity_controller.dart';
import '../identity/presentation/profile_route.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  Future<void> connect() async {
    await ref.read(identityControllerProvider.notifier).run((r) => r.connect());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityControllerProvider);
    final view = state.asData?.value;
    final avatar = view?.id == null
        ? null
        : ref.watch(profileAvatarProvider).asData?.value;
    final canContinue =
        view?.id != null &&
        ![
          IdentityStage.revoked,
          IdentityStage.storageUnavailable,
        ].contains(view?.stage);
    return Scaffold(
      appBar: AppBar(title: Text(strings(context).yourAccount)),
      body: ListView(
        padding: EdgeInsets.all(24),
        children: [
          ShannonMark(size: 80),
          SizedBox(height: 24),
          if (canContinue) ...[
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage: avatar == null ? null : MemoryImage(avatar),
                child: avatar == null
                    ? Icon(Icons.person_outline, size: 36)
                    : null,
              ),
            ),
            SizedBox(height: 12),
            Text(
              view!.nickname.isEmpty ? 'Your saved account' : view.nickname,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 24),
          ],
          Text(switch (view?.stage) {
            IdentityStage.revoked => 'This device can no longer sign in',
            IdentityStage.storageUnavailable =>
              'Account storage is unavailable',
            IdentityStage.offline => 'You’re offline',
            _ =>
              canContinue
                  ? strings(context).welcomeBack
                  : 'Already have an account?',
          }, style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 16),
          if (state.isLoading) LinearProgressIndicator(),
          if (view?.message != null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(view!.message!),
            ),
          if (canContinue)
            ShannonPrimaryButton(
              onPressed: state.isLoading ? null : connect,
              child: Text(strings(context).continueAccount),
            ),
          if (view?.stage == IdentityStage.offline)
            TextButton(
              onPressed: () => context.go('/chats'),
              child: Text('View locally available chats'),
            ),
          if (view?.stage == IdentityStage.revoked ||
              view?.stage == IdentityStage.storageUnavailable)
            Text(
              'Your saved data has not been erased. Do not uninstall or clear app data.',
            ),
          if (!canContinue && !state.isLoading)
            Text(
              'There is no usable saved account on this device. We cannot transfer or recover an account yet.',
            ),
          SizedBox(height: 24),
          OutlinedButton(
            onPressed: null,
            child: Text('Link with an existing device · unavailable'),
          ),
          OutlinedButton(
            onPressed: null,
            child: Text('Recover account · unavailable'),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push('/connection'),
            child: Text(strings(context).checkConnection),
          ),
          if (view?.stage == IdentityStage.none)
            TextButton(
              onPressed: () => context.go('/'),
              child: Text('Back to welcome'),
            ),
        ],
      ),
    );
  }
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final name = TextEditingController();
  final username = TextEditingController();
  Uint8List? photo;
  bool consent = false, busy = false, loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final repo = ref.read(identityRepositoryProvider);
      final view = await ref.read(identityControllerProvider.future);
      final raw = await repo.store.read(IdentityRepository.registrationKey);
      if (mounted) {
        name.text = view.nickname;
        if (raw != null) {
          final draft = jsonDecode(raw) as Map<String, dynamic>;
          name.text = draft['nickname'] as String;
          username.text = draft['username'] as String;
        }
        if (view.id != null) photo = await AvatarRepository(repo.store).read();
      }
    } catch (_) {
      /* Existing storage errors stay visible in authentication state. */
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file != null) {
        if (await file.length() > 8 * 1024 * 1024) throw StateError('large');
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => photo = bytes);
      }
    } catch (_) {
      if (mounted) setState(() => error = strings(context).photoUnavailable);
    }
  }

  Future<void> create() async {
    if (busy || loading || !consent) return;
    if (name.text.trim().isEmpty) {
      setState(() => error = strings(context).nicknameRequired);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final success = await ref.read(identityControllerProvider.notifier).run((
      r,
    ) async {
      final result = await r.signup(name.text, username.text);
      if (photo != null) await AvatarRepository(r.store).save(photo!);
      return result;
    });
    if (mounted) {
      setState(() {
        busy = false;
        if (!success) {
          error = ref.read(identityControllerProvider).asData?.value.message ?? 'Registration was not confirmed. Your saved account is preserved. Retry when connected.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(strings(context).signUp)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: EdgeInsets.all(24),
            children: [
              LinearProgressIndicator(value: 0.33, minHeight: 3),
              SizedBox(height: 28),
              Text(
                strings(context).createAccount,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 8),
              Text(strings(context).createSubtitle),
              SizedBox(height: 24),
              TextField(
                controller: name,
                onChanged: (_) => setState(() {}),
                enabled: !busy && !loading,
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: strings(context).nickname,
                  prefixIcon: Icon(Icons.person_outline),
                  filled: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 12),
              TextField(
                controller: username,
                enabled: !busy && !loading,
                maxLength: 32,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: strings(context).username,
                  prefixIcon: Icon(Icons.alternate_email),
                  filled: true,
                  helperText: strings(context).usernameHelp,
                  helperMaxLines: 2,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: photo == null ? null : MemoryImage(photo!),
                    child: photo == null ? Icon(Icons.person_outline) : null,
                  ),
                  SizedBox(width: 12),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: busy || loading ? null : pick,
                      icon: Icon(Icons.add),
                      label: Text(strings(context).choosePhoto),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ShannonPanel(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(strings(context).localProfile),
                ),
              ),
              SizedBox(height: 16),
              Text(strings(context).recoveryWarning),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: consent,
                onChanged: busy
                    ? null
                    : (v) => setState(() => consent = v ?? false),
                title: Text(strings(context).consent),
              ),
              if (error != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (busy || loading) LinearProgressIndicator(),
              SizedBox(height: 16),
              ShannonPrimaryButton(
                onPressed:
                    busy || loading || !consent || name.text.trim().isEmpty
                    ? null
                    : create,
                child: Text(
                  busy
                      ? strings(context).connecting
                      : strings(context).createAction,
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => context.push('/connection'),
                child: Text(strings(context).checkConnection),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
