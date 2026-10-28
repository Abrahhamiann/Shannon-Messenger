# Private contacts and screen/call privacy

Implementation checkpoint: 2026-10-26. This extends M3; it does not implement or certify M4 encryption.

## What works

- Optional case-insensitive ASCII usernames (3–32 characters, initial letter), uniqueness, editing/removal, opt-in exact authenticated lookup. No directory, prefix matching, autocomplete, phone/email, or address-book upload.
- A minimal lookup returns the stable Shannon account ID and current username only. Local nickname/avatar stay local. Changing a username never changes keys or the account ID. A released username may be reassigned: requests include the previewed account ID and the server rejects a changed binding.
- Real pending requests, recipient-only accept/decline, mutual accepted contacts, block/unblock. Blocking deletes the relationship and prevents discovery/request/accept in either direction. Unblocking does not restore previous acceptance. Duplicate or opposite-direction requests do not create duplicate relationships or auto-accept.
- Shared QR/link invitations: random 256-bit capability, SHA-256 hash stored in PostgreSQL, 24-hour expiration, one live invitation per account. Replacement revokes the previous QR/link; revoke works even after the UI loses its locally displayed token. Expired capabilities are rejected immediately and periodically removed.
- QR rendering and camera scanning. Camera is requested only through Start scanning; leaving/backgrounding stops scanning, and resuming requires Start scanning again. Manual paste remains available.
- Android custom deep link `shannon://invite/v1#<capability>`, Copy, and native ACTION_SEND chooser. Opening/scanning only previews; Send request is explicit. Authentication remains mandatory. No private keys, recovery material, or session tokens in the URI.
- Pending requests refresh on entry or explicit refresh. No push notifications, background presence, or pretend real-time delivery.

## API contract

All routes below use `/api/v1/contacts`, existing M3 bearer authentication, no-store responses, bounded JSON bodies, request deadlines, and the existing TLS policy. Local debug transport is the only HTTP exception.

| Method and suffix | Body / result |
|---|---|
| GET `/profile` | Own `{username, discoverable}` |
| PUT `/profile` | `{username, discoverable}`; empty username removes it |
| POST `/lookup` | `{username}` -> `{id, username}` |
| POST `/resolve` | `{invitation}` -> `{id, username}` |
| POST `/invitation` | `{}` -> `{invitation, expires_at}`; rotates old capability |
| DELETE `/invitation` | Revokes current capability |
| POST `/request` | `{username, target}` OR `{invitation, target}`; target is previewed ID |
| POST `/accept`, `/decline`, `/block`, `/unblock` | `{target}` |
| GET (no suffix) | `{items:[{id,username,kind}], next}`; kinds accepted/incoming/outgoing/blocked |
| GET `?after=<next>` | Keyset pagination, at most 100 items per response |

Migration `services/api/migrations/000003_contacts.sql` adds profiles, invitations, canonical pair relationships, directional blocks, and durable account quotas. Earlier migrations are unchanged. Both accounts are locked in sorted order for relationship changes and discovery is rechecked under the lock, serializing acceptance/blocking with rename/hide/revoke operations. Contact requests cannot be submitted using a bare account ID.

Every authenticated contact operation consumes the durable per-account limit (30/minute), including unsuccessful lookups and malformed input. Existing IP/global limits additionally apply (60/minute/IP, 600/minute/process). Missing, hidden, self, expired/revoked invitation, and blocked discovery all return the same generic 404. This reduces enumeration; exact lookup and username availability necessarily reveal some existence information, and cheap account creation remains a Sybil risk. Production deployment needs registration-abuse controls and capacity tuning. There is no claim of complete enumeration prevention or constant-time lookup.

The server learns contact relationships, usernames, discovery settings, invitation ownership, and blocks. These are not E2EE metadata. Nickname/photo, private seeds, and messaging plaintext are not added to this API. No access/request URL or body logging is introduced. Reverse proxies and future telemetry must redact Authorization, invitation bodies and full sensitive links. Custom schemes can be claimed by another Android app; possession of the invite is neither authentication nor real-world identity proof. A verified HTTPS App Link requires an owned domain and assetlinks deployment and is not configured here. OS sharing/clipboard/history may retain a capability; revocation and expiry limit its useful lifetime.

## Screen capture policy

`SensitiveScreen` hides its child until Android acknowledges a FLAG_SECURE lease. `ScreenPrivacyObserver` releases a covered route only after its opaque cover completes; returning to it reacquires protection before exposing content. Native leases are separate identifiers so stale releases cannot clear a newer route's protection. Dialogs and bottom sheets above protected routes retain protection. Protection is held through outgoing route disposal; native clear waits two animation frames. Startup/restoration begins secure, then normal routes clear it; onResume reapplies native state.

The existing `/conversation/:id` route is protected. Welcome, ordinary onboarding, contacts, QR/invites, profile, settings, and list screens are capture-allowed after startup. The current recovery screen contains only an unavailability explanation and no secret; the current call preview is not an active call. Future **group conversations, chat media viewers, active calls, and actual recovery/private-secret screens must use SensitiveScreen with their Navigator's ScreenPrivacyObserver before rendering any content**. Those functional screens do not exist in this build. A nested Navigator needs its own observer; the existing sensitive route is in the root Navigator. Overlays from a protected route inherit window protection; independent secret dialogs opened from public routes must acquire their own gate first.

FLAG_SECURE protects task previews and ordinary OS screenshots/recordings where Android honors it. It cannot stop an external camera, a compromised/rooted OS, every OEM capture path, or another participant recording their own endpoint. This is not an accessibility-blocking implementation: no overlay blacklist, no accessibility disablement, no broad permissions. Android documents limitations, especially on older devices: https://developer.android.com/security/fraud-prevention/activities . Full frame-by-frame transition, process-death restoration, predictive-back and Samsung acceptance remain device tests, not guarantees inferred from a unit test.

## Future call privacy

No call recording feature or audio-file export exists. The manifest disables audio playback capture; Android 10+ applies AudioManager ALLOW_CAPTURE_BY_NONE before any future audio playback. This is stricter than the manifest alone, which may still permit system capture. Android combines the most restrictive applicable player/process/manifest policies; an existing track must be recreated if its capture policy changes: https://developer.android.com/media/platform/av-capture .

Upstream WebRTC Android WebRtcAudioTrack defaults to USAGE_VOICE_COMMUNICATION (source reviewed 2026-10-26, blob 58f2743d16c9863ce47c8a5d5abca445bc229400): https://webrtc.googlesource.com/src/+/refs/heads/main/sdk/android/src/java/org/webrtc/audio/WebRtcAudioTrack.java . Standard AudioPlaybackCapture is restricted to eligible media/game/unknown usages. Before enabling actual calls, pin and test the selected WebRTC build, preserve VOICE_COMMUNICATION usage, set per-track ALLOW_CAPTURE_BY_NONE where available, verify speaker/earpiece/Bluetooth routing and reconnects, and ensure no raw-audio callbacks, debug PCM dumps, file writers, or external plaintext streams are exposed. Audio must necessarily be decrypted in endpoint memory for playback; claiming that no endpoint plaintext exists would be false. The application must not export it.

Call transport, peer authentication, media-key binding, and M4 reviewed E2EE remain unimplemented. FLAG_SECURE and audio policy do not substitute for any of those. No claim that active calls are secure or third-party recording is impossible is made.

## Run on Windows PowerShell

From `C:\Users\Erik\OneDrive\Desktop\Shannon`:

```powershell
# Uses independent temporary PostgreSQL; does not use your database password.
.\scripts\Test-M3Database.ps1
.\scripts\Test-M3Database.ps1 -AndroidDevice emulator-5554

# Optional second terminal during Android validation; synthetic test content only.
.\scripts\Observe-PrivacyValidation.ps1 -AndroidDevice emulator-5554

Set-Location .\apps\mobile
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat analyze
C:\src\flutter\bin\flutter.bat test
C:\src\flutter\bin\flutter.bat build apk --debug --target lib/main.dart
```

For the user's development server, retain the existing local PostgreSQL credential configuration; do not paste credentials into commands or chat. In `services/api`, run `go run ./cmd/migrate`, then `go run ./cmd/api` with the existing environment configuration in README. For an emulator, use `adb reverse tcp:8080 tcp:8080` (adjust to HTTP_ADDR) and `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080`; local auth requires `SHANNON_ALLOW_INSECURE_LOCAL_AUTH=1` on the backend. Release deployments require HTTPS. The test runner installs **dev.shannon.shannon.validation**, not the user's app; rebuild the normal APK after it because both builds use app-debug.apk as output.

Acceptance to perform on a connected Samsung: allow screenshots on each public route; block content in conversation screenshots/recordings and recents; cover/pop sensitive routes, dialogs, app background/resume, cold deep-link start; verify camera permission denial/grant and QR against a second phone; verify OS share and link handoff. No physical device was connected during development.

## Verification evidence (2026-10-26)

- Full Flutter suite: 75 passing tests, including existing M3 regressions, explicit username lookup (no request while typing), accept action, all six contact sections in dark/light mode at 1.5x text scale, strict invite parsing, native acquire failure, opaque route cover/pop and dialog protection.
- Go tests and vet with real isolated PostgreSQL passed. Coverage includes uniqueness, opt-in discovery, case normalization, minimal result fields, stable ID after rename, stale preview binding, duplicate requests, sender authorization, decline/accept, mutual state, block/invite bypass, revocation, expiration, account quota including misses, and block/accept concurrency. A small-pool contention issue was found during review and fixed by releasing the initial authentication transaction before independently committing the quota, then re-authenticating for the operation; a concurrent-read regression test was added.
- Android emulator (API 37): separate validation package, two newly created isolated identities, real signed M3 authentication, request/accept/block through Go/PostgreSQL, native protected/unprotected window state, existing avatar/key/session regressions all passed.
- Actual emulator adb screenshots and screen recordings collected with synthetic content. The protected screenshot is blank except OS chrome; public test text is visible. Decoded recorded content regions: protected maximum pixel value 0, public maximum 255. Static recordings produced one protected encoded frame and two public frames; this is a steady-state capture check, not exhaustive transition leakage analysis. Evidence is in ignored `.local-test/capture-validation/`.
- Physical Samsung tests and future WebRTC audio-path tests remain outstanding. There is no connected physical device and no implemented call engine.
- Cold and warm Android custom-link launches were checked against the real validation UI using synthetic capabilities; both populated Add Contact correctly without sending a request. Camera permission remained denied before and after opening Scan QR; Android prompted only after Start scanning. Denial displayed a recoverable error. The scanner's built-in automatic resume was disabled so background/resume does not silently restart it; final analysis and the 16 focused contact/privacy tests passed after this correction. A successful live-camera QR decode on two physical devices and OS share-recipient handoff remain manual acceptance checks.
- Final Flutter analysis: no issues. Normal `lib/main.dart` debug APK rebuilt; application ID `dev.shannon.shannon` is distinct from the validation app. Existing user app data was not cleared, no real account was revoked, no user database password was requested/read, and no commit/push was made.
