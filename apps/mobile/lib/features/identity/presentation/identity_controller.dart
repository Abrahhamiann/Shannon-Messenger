import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/identity_repository.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  final client = http.Client();

  ref.onDispose(client.close);

  return IdentityRepository(AndroidKeyStore(), client);
});

final identityControllerProvider =
    AsyncNotifierProvider<IdentityController, IdentityView>(
      IdentityController.new,
    );

class IdentityController extends AsyncNotifier<IdentityView> {
  bool _busy = false;
  Timer? _expiry;

  @override
  Future<IdentityView> build() async {
    ref.onDispose(() => _expiry?.cancel());

    final view = await ref.watch(identityRepositoryProvider).resume();

    _scheduleExpiry(view);

    return view;
  }

  void _scheduleExpiry(IdentityView view) {
    _expiry?.cancel();

    if (!ref.mounted ||
        view.stage != IdentityStage.authenticated ||
        view.validUntil == null) {
      return;
    }

    final remaining = view.validUntil!.difference(DateTime.now());

    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!ref.mounted) {
        return;
      }

      state = AsyncData(
        IdentityView(
          IdentityStage.expired,
          id: view.id,
          deviceId: view.deviceId,
          nickname: view.nickname,
          message: 'Session needs verification. Check the session or authenticate again.',
        ),
      );
    });
  }

  Future<bool> run(
    Future<IdentityView> Function(IdentityRepository) operation,
  ) async {
    if (_busy) {
      return false;
    }

    _busy = true;
    _expiry?.cancel();

    final repository = ref.read(identityRepositoryProvider);

    state = const AsyncLoading();

    try {
      final view = await operation(repository);

      _scheduleExpiry(view);

      if (ref.mounted) {
        state = AsyncData(view);
      }
      return true;
    } catch (_) {
      // Never render raw platform/network exceptions:
      // they may contain secrets.

      if (!ref.mounted) {
        return false;
      }

      final restored = await repository.resume();

      _scheduleExpiry(restored);

      if (!ref.mounted) {
        return false;
      }

      state = AsyncData(
        IdentityView(
          restored.stage,
          id: restored.id,
          deviceId: restored.deviceId,
          nickname: restored.nickname,
          validUntil: restored.validUntil,
          message: 'Operation did not complete. Local identity was not deleted. Check storage and connectivity, then retry.',
        ),
      );
      return false;
    } finally {
      _busy = false;
    }
  }
}
