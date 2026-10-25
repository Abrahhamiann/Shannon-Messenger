# Shannon resumed development report — 2026-10-25

## Scope and checkpoint

Continued the existing uncommitted tree. No reset, clone, commit, push, app data
clear, user-app uninstall, development-database reset or real-device revocation.
The rejected validation command from the interrupted session was not assumed to
have run. Its outstanding Flutter process was recovered: 33 tests had passed.

Already present: the M3 Go authentication implementation, isolated PostgreSQL
tests, encrypted Android key storage, profile/nickname/logout integration,
system-picker UI, fonts, Phosphor assets, motion tokens and initial account guards.

## Implemented in this resumed pass

- New welcome with original native-drawn Shannon mark, compact local-identity
  explanation and real navigation. Native Android splash uses matching navy and
  a vector mark, without an artificial startup delay.
- Redesigned identity creation, authentication feedback and recovery-unavailable
  information. Consent still gates real key generation. Success depends on the
  repository response; animation cannot authenticate an account.
- Chats with local search/filter controls and truthful empty states; contacts
  with People/Groups, private-exchange information and requests availability;
  calls with empty history and explicitly labelled voice/video interface previews.
- Conversation layout with disabled composer/send and an attachment availability
  sheet. It displays no invented messages or delivery state.
- Dedicated contact-exchange, group-information, call-preview and privacy pages.
- Grouped Settings: actual profile navigation and persistent appearance, plus
  privacy, security, registered devices, recovery, notifications, storage,
  language, about/licenses and real service diagnostics.
- Reusable panels, section headings, feature rows, empty-state presentation and
  original mark; local icon mapping expanded. Existing fonts retained. No new
  animation library, asset CDN, tracking SDK, camera or microphone permission.
- Extracted AvatarRepository, with bounded image input, square center crop,
  256px PNG re-encoding and encrypted local persistence separate from key records.
  Tests discovered premature image-descriptor disposal; fixed by retaining the
  descriptor until decoding completes. Invalid images preserve the saved avatar.
- Picker recovery waits for identity initialization. Test runner tolerates an
  absent startup PID; normal Shannon is never used as the validation package.

## What is real and what remains unavailable

Working: local key generation, signed registration/authentication, session
verification/expiry, local nickname and avatar persistence, public-ID copy,
registered-device retrieval, real logout, own-device revocation, theme preference
and Go/PostgreSQL health checks. Revocation is separate from logout.

Unavailable: encrypted messages, private contact exchange, QR verification,
invitations, group creation/communication, voice/video calling, recovery and
additional-device enrollment. Search/filter controls have only empty local views
until data exists. Call and attachment interfaces cannot initiate their actions.
Language strings remain English; Armenian/Cyrillic font coverage is not translation.

M3 is implemented and tested within its single-device development scope, not
independently audited or production-ready. M4 is NOT implemented or complete.
No two devices have exchanged E2EE messages. libsignal remains a candidate;
distribution terms, pinned native bridge compatibility, identity binding and
transactional ratchet storage still need validation before protocol integration.
No custom or fake encryption was substituted. Required pending-envelope maximum
retention is fourteen days; read receipts/activity status remain excluded.

## Executed validation

| Check | Result |
|---|---|
| flutter pub get | Passed for the bundled asset/dependency setup |
| flutter analyze | No issues |
| Entire flutter test suite | 59 passed |
| Avatar unit checks | Reload, 256px output, rejected invalid replacement, unchanged identity record passed |
| UI fixtures | Twelve screens × dark/light plus profile fixtures rendered; no layout exceptions at tested phone sizes |
| go test -count=1 ./... | Passed against isolated real PostgreSQL |
| go vet ./... | Passed |
| Android isolated integration | Passed; real Keystore → Go → PostgreSQL, nickname/avatar reload, logout/login and test-device revocation |
| Normal flutter build apk --debug -t lib/main.dart | Passed; see final build verification below |

The integration test's “restart” is a repository reload, not OS process death.
The system photo-picker gesture and process-kill recovery are not yet manually
accepted. A physical Android device was not used in this resumed pass. No claim
of complete TalkBack, large-text matrix or frame-time/battery validation.

## Important paths

All paths below are relative to `C:\Users\Erik\OneDrive\Desktop\Shannon`.

- `apps/mobile/lib/features/onboarding/welcome_screen.dart`
- `apps/mobile/lib/features/workspace/hub_screens.dart`
- `apps/mobile/lib/features/workspace/conversation_screen.dart`
- `apps/mobile/lib/features/workspace/connection_screens.dart`
- `apps/mobile/lib/features/workspace/settings_screen.dart`
- `apps/mobile/lib/app/widgets.dart`, `icons.dart`, `app.dart`
- `apps/mobile/lib/features/identity/data/avatar_repository.dart`
- `apps/mobile/lib/features/identity/presentation/profile_route.dart`, `identity_screen.dart`
- `apps/mobile/android/app/src/main/res/drawable/shannon_mark.xml`
- `apps/mobile/android/app/src/main/res/{drawable,drawable-v21}/launch_background.xml`
- `apps/mobile/android/app/src/main/res/{values-v31,values-night-v31}/styles.xml`
- `apps/mobile/test/avatar_test.dart`, `workspace_visual_test.dart`, navigation tests
- `apps/mobile/integration_test/identity_test.dart`
- `scripts/Test-M3Database.ps1`
- `docs/ui/*-dark.png`, `*-light.png` (non-personal Flutter fixture renders)

Inherited M3/M2 changes and staged user files remain intact. Updated progress,
roadmap, security, UI report and M4 privacy constraints alongside this report.

## Windows commands

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon\apps\mobile'
flutter pub get
flutter analyze
flutter test
flutter build apk --debug -t lib/main.dart

# Export review images with synthetic fixtures, not personal account data:
flutter test --dart-define=EXPORT_UI_PREVIEWS=true

Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
.\scripts\Test-M3Database.ps1
# With the emulator already running:
.\scripts\Test-M3Database.ps1 -AndroidDevice emulator-5554
```

The Android test command builds a separate validation APK at the usual Flutter
output path. After running it, rebuild `-t lib/main.dart` without
SHANNON_VALIDATION_APP=1 before distributing the normal APK. The runner restores
the environment. It verifies the validation application ID before additive
installation, uses a fresh storage namespace and never calls uninstall/clear.

## Exact continuation

1. Manually accept system photo picking, process recreation, TalkBack, large text,
   and the new layouts on a physical device; retain existing identity data.
2. Complete message-bubble/reply/action/voice presentation against real messaging
   models; do not populate real accounts with preview conversations. Incoming/
   outgoing call and contact verification behavior remain future functionality.
3. Run a pinned libsignal Android compatibility/license spike and upstream vectors.
   Review separate messaging-key binding and atomic local ratchet/outbox storage.
4. Only after that gate, implement authenticated prekeys, bounded encrypted queues,
   WebSocket delivery and two-independent-device E2EE acceptance tests.

The current pass is a buildable UI and M3 validation checkpoint, not final
acceptance of the full premium messenger or completion of Milestone 4.

Final build verification: normal application ID dev.shannon.shannon, version 0.1.0+1; final APK 176,864,588 bytes. Native day/night splash resources compiled successfully. Bundled asset SHA-256 records match. Debug APK only; no release-size/performance claim.
