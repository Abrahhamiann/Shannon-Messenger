# Shannon UI/UX redesign — checkpoint, 2026-10-25

This is an incremental implementation, not the finished messenger experience.
The mandatory reference remains the user's Shannon Private Messenger UI Showcase.
Retained direction: near-black blue surfaces, restrained blue actions, generous
profile avatar, compact grouped settings, clear separators and a floating tab bar.

## Implemented

- Real `/profile` route from Settings, connected to the existing identity provider.
- Local nickname editing (64 Unicode scalar values maximum), public-ID copy,
  selected local avatar, actual device list and identity/security routes.
- Explicit privacy explanation: no profile upload or synchronization.
- Logout confirmation, loading state and failure reporting. Keys are retained.
- Manrope primary font (Latin/Cyrillic) and Noto Sans Armenian fallback, bundled
  locally. This adds script coverage, not translated application strings.
- Phosphor Regular/Fill assets in navigation; Regular in profile and account
  unavailable states. Existing M2 preview screens still contain Material icons.
- Shared spacing, radii, control sizes and motion primitives in `lib/app/design_system.dart`.
- Profile entrance motion and tab transitions honor reduced motion.
- Sample conversations/calls/contacts are blocked once an identity exists.
  Loading, offline, expired, revoked and unreadable-storage states fail closed.
  Old M2 demos are preserved for the explicitly labelled pre-identity preview.

## Research and choices

The in-app browser was used to inspect [Manrope](https://fonts.google.com/specimen/Manrope)
and [Phosphor](https://phosphoricons.com/), including its icon search. Edge was not
available to the browser tool. Manrope's open shapes and geometric rhythm work
with the reference's restrained dark surfaces; Noto supplies Armenian coverage.
Phosphor's rounded Regular outlines and corresponding Fill selection states
provide consistent navigation without glow or decorative gradients.

[Flutter's animation documentation](https://docs.flutter.dev/ui/animations/overview)
supports using native implicit animation for these short transitions. Native
motion avoids a new rendering runtime for simple opacity/position changes.

[Rive Marketplace](https://rive.app/marketplace/) was inspected as a candidate;
no individual animation's redistribution license was established, so no asset
was imported. [LottieFiles licensing](https://lottiefiles.com/page/license) was
reviewed, but no animation was selected. [Lordicon](https://lordicon.com/licenses)
has attribution and other license conditions; none of its assets are included.
[Mobbin](https://mobbin.com/) was reviewed as an inspiration source, not an asset
license. No proprietary screenshots, illustrations or brand marks were copied.
No account was created, subscription purchased or external runtime asset URL added.

## Visual checks

`docs/ui/profile-dark.png` and `profile-light.png` are Flutter-rendered fixtures,
not screenshots of the user's identity. They exercise English, Cyrillic and
Armenian in a 412 × 915 viewport. They do not establish full accessibility or
device-level photo-picker acceptance.

## Exact remaining scope

Phase E is not complete. Onboarding, conversation composition, contacts/groups,
calls and the complete settings experience still need the coordinated redesign.
The new unavailable states prevent false functionality but are not claimed as
the final design. The complete Telegram/WhatsApp/Signal/Keet interaction study,
screen-reader checks, large text matrix, selected-photo visual checks, animation
performance profiling and all-screen icon migration remain outstanding.

Next work: finish the design study, then apply this shared system to onboarding
and all main sections together. Preserve the account/demo boundary throughout.

## Resumed implementation, 2026-10-25

The checkpoint above describes the earlier pass. The resumed pass now routes
the main app to new welcome, identity creation/recovery, chats, contacts, calls,
conversation availability/composer, contact-exchange, group, call-preview and
grouped-settings screens. These use the bundled typography, local Phosphor
mapping, shared panels, feature rows, notices and short native entrance motion.
The original M2 source remains preserved but its sample lists are no longer the
main tab destinations, even before identity creation. Legacy feature-preview
routes remain guarded against real identities.

Search/filter controls affect the local empty views; there is no public search.
Appearance is persistent and functional. Profile, device list, authentication,
logout and health checks use real existing implementations. Messaging compose,
attachments, invitations, QR verification, groups and calls remain unavailable.
Call previews request no camera/microphone permission and simulate no connection.

Dark/light fixtures for twelve screens plus profile are in docs/ui. They passed
phone-layout tests. Remaining work includes live-data message presentation,
reply/actions/voice behavior, verified contact UX, incoming/outgoing calls, full
large-text/TalkBack/performance acceptance and system-picker interaction testing.
No E2EE or final commercial-design acceptance is claimed.
