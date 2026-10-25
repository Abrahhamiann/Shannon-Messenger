import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/icons.dart';
import '../../app/widgets.dart';

class ContactExchangeScreen extends StatelessWidget {
  const ContactExchangeScreen({this.requests = false, super.key});
  final bool requests;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(requests ? 'Contact requests' : 'Add a private contact'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FeatureNotice(
          icon: requests
              ? ShannonIconsRegular.userPlus
              : ShannonIconsRegular.qrCode,
          title: requests
              ? 'An invitation, not a discovery feed.'
              : 'Connect with someone you know.',
          message: 'Private invitations, QR exchange and contact verification are not available yet. No invitation will be created or sent.',
        ),
        const ShannonPanel(
          child: Column(
            children: [
              FeatureRow(
                icon: ShannonIconsRegular.qrCode,
                title: 'Scan an invitation',
                subtitle: 'Unavailable · camera stays off',
              ),
              Divider(height: 1),
              FeatureRow(
                icon: ShannonIconsRegular.shieldCheck,
                title: 'Verify a contact',
                subtitle: 'Fingerprint comparison requires a reviewed contact protocol',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.push('/profile'),
          child: const Text('View my public identifier'),
        ),
        const SizedBox(height: 12),
        const Text(
          'A public identifier alone is not a trusted invitation. Do not treat copying one as contact verification.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your group space')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const FeatureNotice(
          icon: ShannonIconsRegular.usersThree,
          title: 'Room for your people.',
          message: 'Group creation and group conversations are disabled until a secure group protocol is implemented.',
        ),
        const SectionHeading('Group details'),
        const ShannonPanel(
          child: Column(
            children: [
              FeatureRow(
                icon: ShannonIconsRegular.usersThree,
                title: 'Group name & photo',
                subtitle: 'Not available · no group has been created',
              ),
              Divider(height: 1),
              FeatureRow(
                icon: ShannonIconsRegular.userPlus,
                title: 'Members & invitations',
                subtitle: 'Requires authenticated private contacts',
              ),
              Divider(height: 1),
              FeatureRow(
                icon: ShannonIconsRegular.shieldCheck,
                title: 'Membership changes',
                subtitle:
                    'Key rotation and member removal must be reviewed first',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const FilledButton(
          onPressed: null,
          child: Text('Create group · unavailable'),
        ),
      ],
    ),
  );
}

class CallPreviewScreen extends StatelessWidget {
  const CallPreviewScreen({this.video = false, super.key});
  final bool video;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(video ? 'Video call preview' : 'Voice call preview'),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Chip(label: Text('Interface preview · no active call')),
                  ShannonReveal(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(36),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: .25),
                                width: 2,
                              ),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: const Icon(
                              ShannonIconsRegular.user,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Calling is not available yet',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No recipient, timer or connection state is simulated. Your microphone and camera remain off.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: null,
                            tooltip: 'Microphone unavailable',
                            icon: Icon(ShannonIconsRegular.microphone),
                          ),
                          IconButton.filledTonal(
                            onPressed: null,
                            tooltip: 'Camera unavailable',
                            icon: Icon(ShannonIconsRegular.videoCamera),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Close preview'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
