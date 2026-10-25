import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'identity_controller.dart';
import '../data/identity_repository.dart';
import '../data/avatar_repository.dart';
import 'profile_page.dart';

/// The avatar is local metadata, kept separately from identity key material.
final profileAvatarProvider = FutureProvider<Uint8List?>(
  (ref) => AvatarRepository(ref.watch(identityRepositoryProvider).store).read(),
);

class ProfileRoute extends ConsumerStatefulWidget {
  const ProfileRoute({super.key});
  @override
  ConsumerState<ProfileRoute> createState() => _ProfileRouteState();
}

class _ProfileRouteState extends ConsumerState<ProfileRoute> {
  bool _saving = false;
  IdentityView? _lastView;

  @override
  void initState() {
    super.initState();
    // Android can recreate the activity while the system picker is open.
    _recoverPicker();
  }

  Future<void> _recoverPicker() async {
    try {
      final result = await ImagePicker().retrieveLostData();
      if (mounted && result.files?.isNotEmpty == true) {
        await _saveAvatar(result.files!.first);
      }
    } catch (_) {
      if (mounted) {
        _notice('The photo could not be recovered. Please choose it again.');
      }
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveAvatar(XFile file) async {
    if (_saving) return;
    _saving = true;
    try {
      final repository = ref.read(identityRepositoryProvider);
      final identity = await ref.read(identityControllerProvider.future);
      if (!mounted) return;
      if (identity.id == null ||
          await repository.store.read(IdentityRepository.identityKey) == null) {
        throw StateError('Identity unavailable');
      }
      if (await file.length() > 8 * 1024 * 1024) {
        throw StateError('Photo too large');
      }
      await AvatarRepository(repository.store).save(await file.readAsBytes());
      if (mounted) ref.invalidate(profileAvatarProvider);
    } catch (_) {
      if (mounted) {
        _notice('Photo was not saved. Choose a smaller image and retry.');
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _pickAvatar() async {
    if (_saving) return;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file != null && mounted) await _saveAvatar(file);
    } catch (_) {
      if (mounted) {
        _notice('Photo picker unavailable. Your current photo is unchanged.');
      }
    }
  }

  Future<void> _editName(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your nickname'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Saved only on this device. You can change it at any time.',
            ),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 64,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Wait for the dialog's reverse transition before disposing its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (name == null || !mounted) return;
    final success = await ref.read(identityControllerProvider.notifier).run((
      repository,
    ) async {
      await repository.updateNickname(name);
      return repository.resume();
    });
    if (mounted) {
      _notice(
        success
            ? 'Nickname saved on this device.'
            : 'Nickname was not saved. Please retry.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identityControllerProvider);
    _lastView = state.asData?.value ?? _lastView;
    final view = _lastView;
    if (view == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ShannonProfilePage(
      nickname: view.nickname,
      publicId: view.id,
      avatar: ref.watch(profileAvatarProvider).asData?.value,
      sessionLabel: switch (view.stage) {
        IdentityStage.authenticated => 'Session verified',
        IdentityStage.local => 'Saved on this device · signed out',
        IdentityStage.offline => 'Offline · session unverified',
        IdentityStage.expired => 'Session needs verification',
        IdentityStage.revoked => 'This device was revoked',
        IdentityStage.storageUnavailable => 'Secure storage unavailable',
        IdentityStage.none => 'No identity on this device',
      },
      canLogout: !state.isLoading && view.stage == IdentityStage.authenticated,
      onEdit: view.id == null
          ? () => context.push('/identity')
          : () => _editName(view.nickname),
      onAvatar: view.id == null ? null : _pickAvatar,
      onCopy: view.id == null
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: view.id!));
              if (mounted) _notice('Public identity ID copied.');
            },
      onDevices: () => context.push('/identity/devices'),
      onSecurity: () => context.push('/identity'),
      onLogout: () async {
        final success = await ref
            .read(identityControllerProvider.notifier)
            .run((r) => r.logout());
        if (!success) throw StateError('Logout failed');
        if (context.mounted) context.go('/identity');
      },
    );
  }
}
