# Milestone 3 delivery report

Root: C:\Users\Erik\OneDrive\Desktop\Shannon
Date: 2026-10-24
Status: working development identity/authentication foundation; NOT full M3
completion, because recovery and other security review gates remain unresolved.
Existing uncommitted M2 changes and m2-backup-20261023-225425 were preserved.
No Git commit, push, or changes to the connected Samsung device were made.

## Functional
Explicitly consented Android local identity creation; independent root/device
Ed25519 keys; Keystore-protected persistence; local-only optional nickname;
public ID display/copy; signed first-device registration and login; opaque
hashed sessions; refresh rotation; authenticated identity/device listing;
server logout and irreversible self-device revocation; restart repository load;
offline preservation; UI expiry and foreground revalidation.
M2 themes/floating navigation and /health remain available.

## Libraries and algorithms
- cryptography 2.9.0 (Dart, Apache-2.0): RFC 8032 Ed25519 and SHA-256.
- flutter_secure_storage 11.2.0 (BSD-3-Clause): Android Keystore wrapping and
  AES-GCM encrypted storage, resetOnError disabled. No hardware-backed Ed25519 claim.
- Go standard crypto/ed25519, crypto/rand, crypto/sha256.
- filippo.io/edwards25519 v1.2.0: public-point decoding and low-order rejection.
- RFC 7515 compact JWS, RFC 9864 Ed25519 algorithm identifier, RFC 7638/8037 JWK thumbprints.
- No deterministic key derivation, custom primitive, BIP39, X25519 or encryption
  protocol implementation was added.
See security/M3_IDENTITY_DESIGN.md for canonical encoding, lifetimes and sources.

## Database and APIs
Forward migration: services/api/migrations/000002_identity.sql.
Tables: identities, devices, auth_challenges, auth_sessions.
Revocation uses devices.revoked_at rather than an unnecessary extra table.
Sessions contain hashes only; expired challenge/session cleanup runs each minute.
The server retains public keys, account/device relationships and timestamps.

| Endpoint | Behavior |
| --- | --- |
| POST /api/v1/auth/challenge | Fresh key-, audience-, purpose-bound challenge |
| POST /api/v1/identities/register | Requires root and device JWS proofs |
| POST /api/v1/auth/verify | Device-signed login for an existing unrevoked device |
| GET /api/v1/identities/me | Authenticated public identity/device IDs |
| POST /api/v1/auth/refresh | Atomic access/refresh rotation |
| POST /api/v1/auth/logout | Revoke current server session |
| GET /api/v1/devices | List only authenticated account's devices |
| DELETE /api/v1/devices/{id} | Irreversible self-revocation only |
| POST /api/v1/devices/link | Authenticated 501 unavailable, never fake enrollment |
| GET /health | Existing database-aware health endpoint |

Auth HTTP errors: 400 malformed, 401 invalid/expired credentials, 403 forbidden
device operation, 426 TLS required, 429 rate limited, 503 temporary failure.
TLS_CERT_FILE and TLS_KEY_FILE enable native HTTPS. HTTP development authentication
requires SHANNON_ALLOW_INSECURE_LOCAL_AUTH=1 and a loopback peer. Never expose this
exception through an unreviewed proxy. Audience must be unique per real deployment
and match Flutter AUTH_AUDIENCE.

## Deliberately deferred
Recovery phrase generation/confirmation/restoration, X25519 protocol keys, QR
sharing/linking, multiple-device enrollment, cross-device revocation, root rotation,
image avatars, cloud backup and message encryption. BIP39 specifies mnemonic
encoding and seed derivation, not a reviewed messenger recovery protocol.
Do not put wallet phrases into Shannon. Losing app data can lose this test identity.

## Validation
See PROGRESS.md for final command results. PostgreSQL migrations and auth tests
ran against fresh isolated PostgreSQL 17 clusters with ephemeral credentials;
shannon_dev was not modified because this execution environment lacks its password.
Android integration uses a separate encrypted namespace, not the user's identity.
It exercises Android → Go → real PostgreSQL registration, session verification,
repository reload, logout, login, listing and revocation.
Repository reload is not proof of OS process-death recovery.

## Windows / Samsung instructions

Use your existing authenticated PostgreSQL shell. Do not paste a password into
chat or commit it. Terminal 1:

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
$env:SHANNON_ALLOW_INSECURE_LOCAL_AUTH = '1'
$env:SHANNON_AUTH_AUDIENCE = 'shannon.local'
.\scripts\Start-Api.ps1
```

Terminal 2; enable USB debugging on Samsung and accept its USB prompt:

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices
# Replace YOUR_DEVICE_ID with the Samsung ID shown above.
& $adb -s YOUR_DEVICE_ID reverse tcp:8080 tcp:8080
Push-Location apps/mobile
flutter pub get
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://127.0.0.1:8080 --dart-define=AUTH_AUDIENCE=shannon.local
Pop-Location
```

1. Open Create Private Identity. Read and acknowledge that recovery is unavailable.
2. Optionally enter a nickname, then Generate local identity. This does not
   register the account or send the nickname to the backend.
3. Select Connect and authenticate. Expect Authenticated with Shannon and a public ID.
4. View registered devices. Expect this device only.
5. Restart/open the identity page and verify the session. Stop the backend and
   check that a retry preserves your public ID and does not pretend success.
6. Sign out, then reconnect. The device proves possession again.
7. Only for a disposable identity: revoke this device and confirm the warning.
   It cannot authenticate again. With recovery unavailable this is irreversible.
8. Restore Identity explains the blocker and offers no misleading phrase input.

Debug HTTP is only for local adb reverse. Use HTTPS for other deployments.
Keep API_BASE_URL/AUTH_AUDIENCE stable for an existing identity: stored keys are
bound to that configuration and the app refuses silent migration.

Tests:

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
# No shannon_dev password needed: creates and removes an isolated local cluster.
.\scripts\Test-M3Database.ps1
# Only use a disposable emulator for the integration runner:
.\scripts\Test-M3Database.ps1 -AndroidDevice emulator-5554
Push-Location apps/mobile
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:8080
Pop-Location
```

The isolated runner requires PostgreSQL binaries at C:\Program Files\PostgreSQL\17\bin,
uses temporary port allocation for PostgreSQL and port 18080 for the test API,
and cleans up its processes/data. Free port 18080 before running.
Normal APK: apps/mobile/build/app/outputs/flutter-apk/app-debug.apk.

## Changed/new files in this work
Repository-relative paths below are all beneath the root stated above.

Backend:
- services/api/internal/identity/crypto.go
- services/api/internal/identity/http.go
- services/api/internal/identity/crypto_test.go
- services/api/internal/identity/integration_test.go
- services/api/migrations/000002_identity.sql
- services/api/internal/httpapi/server.go
- services/api/cmd/api/main.go
- services/api/go.mod and go.sum

Flutter:
- apps/mobile/lib/features/identity/data/identity_repository.dart
- apps/mobile/lib/features/identity/presentation/identity_controller.dart
- apps/mobile/lib/features/identity/presentation/identity_screen.dart
- apps/mobile/lib/app/app.dart (existing M2 routes preserved)
- apps/mobile/lib/features/foundation/presentation/screens.dart
- apps/mobile/lib/features/milestone2/presentation/m2_screens.dart (identity entry links)
- apps/mobile/pubspec.yaml and pubspec.lock
- apps/mobile/test/identity_test.dart
- apps/mobile/test/identity_widget_test.dart
- apps/mobile/test/widget_test.dart and milestone2_ui_test.dart (navigation regression updates)
- apps/mobile/integration_test/identity_test.dart
- apps/mobile/integration_test/launch_test.dart (scroll-to-entry regression update)

Android:
- apps/mobile/android/app/src/main/AndroidManifest.xml
- apps/mobile/android/app/src/main/kotlin/dev/shannon/shannon/MainActivity.kt
- apps/mobile/android/app/src/main/res/xml/backup_rules.xml
- apps/mobile/android/app/src/main/res/xml/data_extraction_rules.xml

Tooling/docs:
- scripts/Test-M3Database.ps1
- .env.example and .gitignore
- README.md
- docs/PROGRESS.md, ROADMAP.md, SECURITY.md, API.md, ARCHITECTURE.md, DEPENDENCIES.md
- docs/security/M3_IDENTITY_DESIGN.md
- docs/security/M3_THREAT_MODEL.md
- docs/security/M3_SECURITY_REVIEW.md
- docs/M3_REPORT.md

## Recommended M4 plan (not started)
1. Close M3 security gates: independent review, recovery/root rotation and
   authenticated linking selection; validate Samsung data-loss/backup scenarios.
2. Implement reviewed recovery and device enrollment with interoperability and
   adversarial tests. Do not retrofit a 12-word phrase onto an unreviewed scheme.
3. Design private one-time invitations and contact authorization with rate limits,
   expiration and identity verification. Keep public directories absent.
4. Select reviewed 1:1/group protocol libraries and audit licensing/platform
   support before adding X25519 prekeys, Double Ratchet or MLS credentials.
