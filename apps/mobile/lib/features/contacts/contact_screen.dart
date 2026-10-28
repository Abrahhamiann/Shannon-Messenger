import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'dart:async';

import 'invite_state.dart';

import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/screen_privacy.dart';
import '../../app/widgets.dart';
import '../identity/data/identity_repository.dart';
import '../identity/presentation/identity_controller.dart';

String? invitationToken(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'shannon' ||
      uri.host != 'invite' ||
      uri.path != '/v1' ||
      uri.hasQuery ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(uri.fragment)) {
    return null;
  }
  return uri.fragment;
}

String invitationLink(String token) => 'shannon://invite/v1#$token';

String contactFailureMessage(Object failure) {
  if (failure is! IdentityFailure) {
    return 'Could not connect to Shannon. Check your connection and try again.';
  }
  switch (failure.code) {
    case 'own_invitation':
      return 'This is your own invitation. Scan an invitation from someone else.';
    case 'own_contact':
      return 'This is your own account. Search for someone else.';
    case 'invitation_invalid':
      return 'This invitation is invalid or no longer available. Ask for a new QR code or link.';
    case 'invitation_expired':
      return 'This invitation has expired. Ask the sender for a new QR code or link.';
    case 'invitation_revoked':
      return 'This invitation was revoked or replaced. Ask the sender for a new invitation.';
    case 'contact_not_found':
      return 'Contact not found or unavailable for discovery. Check the exact username.';
  }
  if (failure.status == 401 || failure.status == null) {
    return 'Your session is unavailable. Sign in again, then retry.';
  }
  if (failure.status == 426) return failure.message;
  if (failure.status == 429) {
    return 'Too many attempts. Wait one minute before retrying.';
  }
  if (failure.status != null && failure.status! >= 500) {
    return 'The Shannon backend is unavailable. Try again later.';
  }
  if (failure.status == 404) {
    return 'Contact or invitation unavailable. Check the username or ask for a new invitation.';
  }
  if (failure.status == 409) {
    return 'Username unavailable or preview changed. Refresh and try again.';
  }
  return 'Could not complete this action. Refresh and try again.';
}

/// Real server state only. No seed data, local acceptance, or E2EE claims.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({this.section = 'contacts', this.invitation, super.key});
  final String section;
  final String? invitation;
  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final input = TextEditingController();
  final username = TextEditingController();
  bool busy = false, discoverable = false;
  String? error, notice, generated, expiry;
  String next = '';
  Map<String, dynamic>? preview, discovery;
  List<Map<String, dynamic>> items = [];
  bool loaded = false;
  Timer? expiryTimer;
  bool get expired =>
      expiry != null && !DateTime.parse(expiry!).isAfter(DateTime.now());
  @override
  void initState() {
    super.initState();
    if (widget.invitation != null) {
      input.text = invitationLink(widget.invitation!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await load();
      if (mounted &&
          widget.invitation != null &&
          ref.read(identityControllerProvider).asData?.value.stage ==
              IdentityStage.authenticated) {
        await lookup();
      }
    });
  }

  @override
  void dispose() {
    input.dispose();
    username.dispose();
    expiryTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>> api(
    String method,
    String op, [
    Map<String, dynamic>? body,
  ]) => ref.read(identityRepositoryProvider).contactRequest(method, op, body);
  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(() => error = contactFailureMessage(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() => run(() async {
    // Do not access secure platform storage until the identity provider is ready.
    final identity = await ref.read(identityControllerProvider.future);
    if (identity.id == null) return;
    if (widget.section == 'privacy') {
      final data = await api('GET', '/profile');
      if (!mounted) return;
      username.text = data['username'] as String;
      setState(() {
        discoverable = data['discoverable'] == true;
        loaded = true;
      });
    } else if (['contacts', 'requests', 'blocked'].contains(widget.section)) {
      await fetchItems(false);
    }
  });
  Future<void> fetchItems(bool more) async {
    final data = await api(
      'GET',
      more ? '?after=${Uri.encodeQueryComponent(next)}' : '',
    );
    if (!mounted) return;
    setState(() {
      final page = (data['items'] as List).cast<Map<String, dynamic>>();
      items = more ? [...items, ...page] : page;
      next = data['next'] as String;
      loaded = true;
    });
  }

  Future<void> lookup() => run(() async {
    setState(() {
      preview = null;
      discovery = null;
    });
    final token = invitationToken(input.text);
    if (input.text.contains('://') && token == null) {
      setState(() => error = 'This is not a valid Shannon invitation.');
      return;
    }
    final query = <String, dynamic>{
      if (token != null) 'invitation': token else 'username': input.text.trim(),
    };
    final result = await api(
      'POST',
      token == null ? '/lookup' : '/resolve',
      query,
    );
    if (mounted) {
      setState(() {
        preview = result;
        discovery = query;
      });
      ref.read(pendingInvitationProvider.notifier).save(null);
    }
  });
  Future<void> act(String action, String id) => run(() async {
    await api('POST', '/$action', {'target': id});
    await fetchItems(false);
    if (mounted) {
      setState(
        () => notice = action == 'accept'
            ? 'Contact accepted. Messaging is not available yet.'
            : 'Contact updated.',
      );
    }
  });
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(identityControllerProvider).asData?.value;
    final titles = {
      'contacts': 'Contacts',
      'add': 'Add contact',
      'requests': 'Pending requests',
      'qr': 'My QR & invite',
      'privacy': 'Contact privacy',
      'blocked': 'Blocked contacts',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[widget.section] ?? 'Contacts'),
        actions: [
          if (widget.section == 'contacts')
            IconButton(
              tooltip: 'Add contact',
              onPressed: () => context.push('/contacts/add'),
              icon: const Icon(ShannonIconsRegular.userPlus),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: busy ? null : load,
            icon: const Icon(ShannonIconsRegular.arrowCounterClockwise),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(notice!),
            ),
          if (id?.id == null || id?.stage != IdentityStage.authenticated)
            ShannonPanel(
              child: FeatureRow(
                icon: ShannonIconsRegular.key,
                title: 'Authenticate to connect',
                subtitle: 'Your local keys remain on this device.',
                onTap: () async {
                  await context.push('/account');
                  if (mounted) await load();
                },
              ),
            ),
          if (widget.section == 'add') ...[
            const SectionHeading('Find someone you know'),
            const Text(
              'Enter an exact @username or a private invite link. No directory, suggestions, or address-book upload.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '@username or invite link',
              ),
              onChanged: (_) => setState(() {
                preview = null;
                discovery = null;
              }),
              onSubmitted: (_) {
                if (!busy) lookup();
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : lookup,
              icon: const Icon(ShannonIconsRegular.magnifyingGlass),
              label: const Text('Find exact match'),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final link = await context.push<String>('/contacts/scan');
                      if (link != null && mounted) {
                        input.text = link;
                        await lookup();
                      }
                    },
              icon: const Icon(ShannonIconsRegular.qrCode),
              label: const Text('Scan QR code'),
            ),
            TextButton(
              onPressed: () => context.push('/contacts/qr'),
              child: const Text('My QR & private invite'),
            ),
            if (preview != null)
              ShannonReveal(
                child: ShannonPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview!['username'] == ''
                              ? 'Private account'
                              : '@${preview!['username']}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SelectableText(preview!['id'] as String),
                        const SizedBox(height: 12),
                        const Text(
                          'This identifies a Shannon account, not a verified person. Confirm identity through a trusted channel. Encryption sessions are not available yet.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  await api('POST', '/request', {
                                    ...discovery!,
                                    'target': preview!['id'],
                                  });
                                  if (mounted) {
                                    setState(() {
                                      notice = 'Request submitted. Check Pending requests for its current status.';
                                      preview = null;
                                      discovery = null;
                                    });
                                  }
                                }),
                          child: const Text('Send request'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          if (widget.section == 'privacy') ...[
            const SectionHeading('Your optional username'),
            const Text(
              '3–32 ASCII letters, digits, or underscores; start with a letter. Case-insensitive. Changing this never changes your cryptographic account ID. Released names may be claimed by others.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: username,
              enabled: loaded && !busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '@username (optional)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow exact username discovery'),
              subtitle: const Text(
                'Off by default. Anyone signed in who knows your exact username can find your account when enabled.',
              ),
              value: discoverable,
              onChanged: !loaded || busy
                  ? null
                  : (v) => setState(() => discoverable = v),
            ),
            FilledButton(
              onPressed: !loaded || busy
                  ? null
                  : () => run(() async {
                      final value = await api('PUT', '/profile', {
                        'username': username.text,
                        'discoverable': discoverable,
                      });
                      if (mounted) {
                        setState(() {
                          username.text = value['username'] as String;
                          discoverable = value['discoverable'] == true;
                          notice = 'Contact privacy saved.';
                        });
                      }
                    }),
              child: const Text('Save username & privacy'),
            ),
            TextButton(
              onPressed: () => context.push('/contacts/blocked'),
              child: const Text('Blocked contacts'),
            ),
            const Text(
              'Invites work independently of username discovery until they expire or you revoke them. The server stores contact relationships and blocks; this metadata is not end-to-end encrypted.',
            ),
          ],
          if (widget.section == 'qr') ...[
            const SectionHeading('An invitation, just for your people'),
            const Text(
              'Valid for 24 hours. A new invite revokes the previous QR and link. Anyone with it can preview your account and send a request. Share it privately.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final value = await api('POST', '/invitation', {});
                      if (mounted) {
                        setState(() {
                          generated = invitationLink(
                            value['invitation'] as String,
                          );
                          expiry = value['expires_at'] as String;
                        });
                        expiryTimer?.cancel();
                        expiryTimer = Timer(
                          DateTime.parse(expiry!).difference(DateTime.now()),
                          () {
                            if (mounted) setState(() {});
                          },
                        );
                      }
                    }),
              child: Text(
                generated == null
                    ? 'Generate private invite'
                    : 'Replace invitation',
              ),
            ),
            if (generated != null && expired)
              const Text(
                'This invitation has expired. Generate a replacement.',
              ),
            if (generated != null && !expired) ...[
              Center(
                child: Semantics(
                  label: 'Shannon invitation QR code',
                  child: QrImageView(
                    data: generated!,
                    size: 280,
                    padding: const EdgeInsets.all(36),
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              Text('Expires: ${DateTime.parse(expiry!).toLocal()}'),
              const Text(
                'QR codes do not verify someone’s real-world identity.',
              ),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: () => run(() async {
                      await Clipboard.setData(ClipboardData(text: generated!));
                      if (mounted) {
                        setState(
                          () => notice = 'Invitation copied. Your system clipboard may retain it.',
                        );
                      }
                    }),
                    child: const Text('Copy link'),
                  ),
                  TextButton(
                    onPressed: () => run(() async {
                      await privacyChannel.invokeMethod<void>(
                        'shareInvite',
                        generated,
                      );
                    }),
                    child: const Text('Share via Android'),
                  ),
                ],
              ),
            ],
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await api('DELETE', '/invitation');
                      if (mounted) {
                        setState(() {
                          generated = null;
                          notice = 'All current invitations revoked.';
                        });
                      }
                    }),
              child: const Text('Revoke current invitation'),
            ),
          ],
          if (['contacts', 'requests', 'blocked'].contains(widget.section)) ...[
            if (widget.section == 'contacts') ...[
              ShannonPanel(
                child: Column(
                  children: [
                    FeatureRow(
                      icon: ShannonIconsRegular.userPlus,
                      title: 'Pending requests',
                      subtitle: 'Accept, decline, or block',
                      onTap: () => context.push('/contacts/requests'),
                    ),
                    FeatureRow(
                      icon: ShannonIconsRegular.qrCode,
                      title: 'My QR & invite',
                      subtitle: 'Private, expiring contact exchange',
                      onTap: () => context.push('/contacts/qr'),
                    ),
                    FeatureRow(
                      icon: ShannonIconsRegular.shieldCheck,
                      title: 'Contact privacy',
                      subtitle: 'Username discovery and blocked accounts',
                      onTap: () => context.push('/contacts/privacy'),
                    ),
                  ],
                ),
              ),
              const SectionHeading('Your contacts'),
            ],
            for (final item in items.where(
              (e) => widget.section == 'contacts'
                  ? e['kind'] == 'accepted'
                  : widget.section == 'blocked'
                  ? e['kind'] == 'blocked'
                  : ['incoming', 'outgoing'].contains(e['kind']),
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ShannonPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['username'] == ''
                              ? 'Private account'
                              : '@${item['username']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          item['kind'] == 'accepted'
                              ? 'Contact · messaging not available'
                              : item['kind'] as String,
                        ),
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Contact profile'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(item['id'] as String),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Stable Shannon account identifier. No real-world identity or M4 messaging-key verification has been performed.',
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('View account identity'),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (item['kind'] == 'incoming') ...[
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () => act('accept', item['id'] as String),
                                child: const Text('Accept'),
                              ),
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () =>
                                          act('decline', item['id'] as String),
                                child: const Text('Decline'),
                              ),
                            ],
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => act(
                                      item['kind'] == 'blocked'
                                          ? 'unblock'
                                          : 'block',
                                      item['id'] as String,
                                    ),
                              child: Text(
                                item['kind'] == 'blocked' ? 'Unblock' : 'Block',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (loaded &&
                items
                    .where(
                      (e) => widget.section == 'contacts'
                          ? e['kind'] == 'accepted'
                          : widget.section == 'blocked'
                          ? e['kind'] == 'blocked'
                          : ['incoming', 'outgoing'].contains(e['kind']),
                    )
                    .isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No entries on this page.'),
              ),
            if (next.isNotEmpty)
              OutlinedButton(
                onPressed: busy ? null : () => run(() => fetchItems(true)),
                child: const Text('Load more'),
              ),
            if (widget.section == 'requests')
              const Text(
                'Requests are fetched when you open or refresh this screen. Push notifications and encrypted messaging are not implemented.',
              ),
          ],
        ],
      ),
    );
  }
}

class ContactScanner extends StatefulWidget {
  const ContactScanner({super.key});
  @override
  State<ContactScanner> createState() => _ContactScannerState();
}

class _ContactScannerState extends State<ContactScanner> {
  bool busy = false;
  String? error;
  Future<void> scan() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await privacyChannel.invokeMethod<String>('scanInvite');
      if (!mounted) return;
      if (result == null) {
        setState(
          () => error =
              'Scanning canceled. You can try again or paste an invite link.',
        );
      } else if (invitationToken(result) == null) {
        setState(
          () => error =
              'This QR is not a supported Shannon invitation. Try again.',
        );
      } else {
        context.pop(result);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'permission_denied'
              ? 'Camera permission was denied. Allow it in Android settings, then try again.'
              : 'Camera unavailable. Close other camera apps and retry, or paste an invite link.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Scanner unavailable. You can paste an invite link instead.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan QR Code')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(ShannonIconsRegular.qrCode, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Scan a private invitation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start scanning opens the camera and asks for permission if needed. Decoding stays on this device. A scan never sends a contact request automatically.',
          ),
          const SizedBox(height: 24),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(error!),
            ),
          FilledButton(
            onPressed: busy ? null : scan,
            child: Text(busy ? 'Camera is open…' : 'Start scanning'),
          ),
          if (error != null)
            TextButton(
              onPressed: () async {
                try {
                  await privacyChannel.invokeMethod<void>('openAppSettings');
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => error = 'Open Android Settings → Apps → Shannon → Permissions → Camera.',
                    );
                  }
                }
              },
              child: const Text('Open app settings'),
            ),
          TextButton(
            onPressed: busy ? null : () => context.pop(),
            child: const Text('Use an invite link instead'),
          ),
        ],
      ),
    ),
  );
}
