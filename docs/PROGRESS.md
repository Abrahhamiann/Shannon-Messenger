# Resume checkpoint — 2026-10-25

The historical M1 notes below are superseded by this checkpoint.

Implemented before resuming: M3 identity/session backend, profile route, nickname
editing, photo picker, real logout, local fonts/icons, reduced-motion primitives,
and guards excluding sample activity from real accounts.

Implemented in the resumed pass:
- New welcome and identity-creation presentation with concise recovery warnings.
- New chats, contacts, calls, conversation composer/attachment availability UI,
  contact-exchange, group, call-preview and grouped-settings screens.
- Real appearance controls, profile navigation, privacy/storage/language/about
  information and existing device/session routes. No new fake messaging actions.
- Extracted AvatarRepository; tests caught and fixed premature image-descriptor
  disposal. Saves crop/resize to 256px, re-encode pixels and preserve key records.
- Picker recovery waits for identity initialization rather than rejecting a photo
  while storage/session initialization is still pending.
- Fixed isolated Android runner startup polling for absent process IDs.
- Added avatar and dark/light screen regression tests and local review images.

Validation: latest full Flutter run has 59 passing tests; analysis is clean.
Go tests and vet passed with real isolated PostgreSQL. Android validation passed
including avatar persistence, nickname reload, registration, logout, reauthentication
and test-device revocation. The normal final APK build result is recorded in
RESUME_REPORT.md. No shannon_dev credentials were accessed or requested.

M3 is implemented and integration-tested for the supported single-device scope;
it is not production/audit complete. Recovery and device linking remain unavailable.
M4 remains unimplemented: no messaging keys, prekeys, ratchet, encrypted queues,
WebSocket delivery or two-device encrypted exchange exists.

Remaining UI work: functional message bubbles/replies/actions/voice controls must
be connected to real M4 data; contact verification and incoming/outgoing call
states are not simulated. The current no-data views are honest early-access UI,
not proof that the full requested messenger experience is complete. Native picker
interaction, process-death recovery, TalkBack, large text and performance still
need device-level acceptance. No commit/push or app-data clearing was performed.

Exact continuation: review RESUME_REPORT.md, finish the outstanding UX acceptance
and M4 native-protocol compatibility spike before implementing transport/storage.

---
# Milestone 1 validation — 2026-10-23

Status: implemented; Android launch validated. Final acceptance is pending live
database credentials in the execution environment. No next milestone started.

Implemented: monorepo, Flutter entry point, dark/light/system themes, welcome,
four-tab navigation, settings, real health diagnostics, Go HTTP server, pgx pool,
environment configuration, transactional/checksummed migrations, tests, and
Windows PowerShell instructions. No fake identity, encryption, or messaging.

Verified:
- Flutter 3.47.7, Dart 3.13.5, Go 1.27.3, Git, Docker CLI.
- PostgreSQL 17 service running and TCP port 5432 reachable.
- User reports successful local shannon_app → shannon_dev authentication.
- Agent's noninteractive psql attempt reached PostgreSQL but returned
  "no password supplied". No password was requested or displayed.
- go test ./... and go vet ./... pass. Database integration test explicitly
  skips without SHANNON_INTEGRATION=1; it is not counted as live DB validation.
- flutter analyze: no issues.
- flutter test: six tests pass (API contract, invalid responses, navigation,
  light theme, connection failure and retry).
- Configured Android API 37 emulator boots successfully.
- Android debug build succeeds; launch_test.dart passes on emulator-5554:
  app installed, launched, and navigated to Settings (one on-device test).
- Both Go command binaries compile successfully.
- Normal (non-test) debug APK built and installed successfully. Welcome screen
  visually inspected; screenshot saved at docs/ui/m1-android-welcome.png.
- Headless test emulator shut down after verification; start it normally using
  the README command for interactive development.
- Generated build output, local.properties, and .env excluded from Git.

Pending acceptance:
1. Run scripts/Start-Api.ps1 in the configured local credential environment.
2. Verify GET /health returns status=ok and database=up.
3. Run scripts/Test-Foundation.ps1 -Integration.
4. Run the Android connection integration test described in README.md.

The original Gradle download stalled. The official 9.3.1 distribution was
downloaded in bounded ranges from downloads.gradle.org and its full SHA-256
verified before use. The SDK-manager compatibility wrapper failed to install
NDK 28.2.13676358. Installed it with the direct Android CLI identifier
ndk/28.2.13676358, then the build installed SDK Platform 36 automatically.
Android build and on-device launch/navigation validation subsequently passed.

The full reference ribbon logo and all messenger screens are future design
work. Theme selection is session-only. Performance and security audit targets
have not been validated. This is not a production release.

## 2026-10-26 contact/capture update

Implemented the private-contact backend migration/endpoints and Flutter flows (username discovery, requests, acceptance, block/unblock, QR scanner/renderer, private link generation/revocation/sharing/deep links), plus route privacy leases and Android capture policies. See CONTACTS_AND_CAPTURE_PRIVACY.md. This supersedes the previous statement that contact exchange is entirely unavailable. M3 key/session behavior remains in place; M4 messaging and actual calls remain unavailable. No user identity reset or development-database reset was performed.
