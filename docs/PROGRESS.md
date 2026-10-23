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
