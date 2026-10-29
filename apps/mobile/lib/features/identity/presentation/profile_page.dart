import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/icons.dart';

import '../../../app/design_system.dart';
import '../../messaging/messaging_controller.dart' show m4MessagingEnabled;

class ShannonProfilePage extends StatefulWidget {
  const ShannonProfilePage({
    super.key,
    required this.onLogout,
    this.onLocalLogout,
    this.nickname,
    this.publicId,
    this.avatar,
    required this.sessionLabel,
    required this.canLogout,
    required this.onEdit,
    required this.onDevices,
    required this.onSecurity,
    this.onCopy,
    this.onAvatar,
  });

  final Future<void> Function() onLogout;
  final Future<void> Function()? onLocalLogout;
  final String? nickname;
  final String? publicId;
  final Uint8List? avatar;
  final String sessionLabel;
  final bool canLogout;
  final VoidCallback onEdit, onDevices, onSecurity;
  final VoidCallback? onCopy, onAvatar;

  @override
  State<ShannonProfilePage> createState() => _ShannonProfilePageState();
}

class _ShannonProfilePageState extends State<ShannonProfilePage> {
  bool _loggingOut = false;

  Future<void> _confirmLogout() async {
    if (_loggingOut) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(ShannonIconsRegular.signOut, color: Color(0xFFF87171)),
              SizedBox(width: 12),
              Text('Log Out?'),
            ],
          ),
          content: const Text(
            'Your authenticated session will end.\n\n'
            'Your local cryptographic identity will '
            'remain on this device.\n\n'
            'You can authenticate again later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC4444),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);

    try {
      await widget.onLogout();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not complete logout. Please retry.'),
          action: SnackBarAction(label: 'Retry', onPressed: _confirmLogout),
        ),
      );
      if (widget.onLocalLogout != null) {
        final local = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Server logout was not confirmed'),
            content: const Text(
              'You can retry, or sign out only on this device. Local sign-out prevents this app from using its saved session. It does not confirm server revocation. Your account and photo are kept. The next successful sign-in replaces this device’s server session.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Retry later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Sign out on this device'),
              ),
            ],
          ),
        );
        if (local == true && mounted) {
          try {
            await widget.onLocalLogout!();
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Local sign-out could not be saved. Please retry.',
                  ),
                ),
              );
            }
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = colors.surface;
    final primary = colors.primary;

    final secondary = colors.onSurfaceVariant;

    final displayName = widget.nickname?.trim().isNotEmpty == true
        ? widget.nickname!.trim()
        : 'Shannon User';

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), centerTitle: true),
      body: ShannonReveal(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(ShannonSpace.page),
            children: [
              const SizedBox(height: 16),

              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: widget.avatar == null
                        ? Icon(
                            ShannonIconsRegular.user,
                            size: 48,
                            color: primary,
                          )
                        : Image.memory(widget.avatar!, fit: BoxFit.cover),
                  ),
                ),
              ),

              TextButton.icon(
                onPressed: widget.onAvatar,
                icon: const Icon(ShannonIconsRegular.cameraPlus),
                label: const Text('Change photo'),
              ),
              const SizedBox(height: 16),

              Text(
                displayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.sessionLabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondary),
              ),

              const Text(
                'Your nickname and photo stay on this device. Profile sharing is not enabled.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      ShannonIconsRegular.shieldCheck,
                      color: primary,
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Identity',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.publicId == null
                                ? 'Identity details unavailable'
                                : widget.publicId!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: secondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              TextButton.icon(
                onPressed: widget.onCopy,
                icon: const Icon(ShannonIconsRegular.copy),
                label: const Text('Copy public ID'),
              ),
              const SizedBox(height: 28),

              Text(
                'ACCOUNT',
                style: TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 12),

              Material(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: ShannonIconsRegular.userCircle,
                      title: 'Nickname',
                      subtitle: 'Saved only on this device',
                      onTap: widget.onEdit,
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    _ProfileTile(
                      icon: ShannonIconsRegular.devices,
                      title: 'Linked Devices',
                      subtitle: 'View registration and revoke this device',
                      onTap: widget.onDevices,
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    _ProfileTile(
                      icon: ShannonIconsRegular.lockKey,
                      title: 'Security',
                      subtitle: 'Identity, authentication and recovery status',
                      onTap: widget.onSecurity,
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    _ProfileTile(
                      icon: ShannonIconsRegular.shieldCheck,
                      title: 'Privacy',
                      subtitle: 'How this build handles your data',
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Your data on this device'),
                          content: const SingleChildScrollView(
                            child: Text(
                              'Your nickname and selected avatar are stored locally using encrypted app storage. They are not uploaded or synchronized. '
                              'The saved avatar contains pixels only; the system picker may retain a temporary source copy in app cache.\n\n'
                              'Android backup is disabled. Sensitive screens block capture; profile and settings allow it. '
                              '${m4MessagingEnabled ? 'Encrypted one-to-one text uses separate messaging keys and encrypted local history. Recovery and chat backup are unavailable. ' : 'Recovery and encrypted messaging are not available yet. '}'
                              'Device revocation is separate from logout and is permanent for this device key.',
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
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'SESSION',
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 12),

              Material(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _loggingOut || !widget.canLogout
                      ? null
                      : _confirmLogout,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          ShannonIconsRegular.signOut,
                          color: Color(0xFFF87171),
                          size: 25,
                        ),

                        const SizedBox(width: 16),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Color(0xFFF87171),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'End your authenticated session',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                        if (_loggingOut)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            ShannonIconsRegular.caretRight,
                            color: secondary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Logging out does not delete your local '
                'cryptographic identity.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: secondary, height: 1.5),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(ShannonIconsRegular.caretRight, size: 20),
      onTap: onTap,
    );
  }
}
