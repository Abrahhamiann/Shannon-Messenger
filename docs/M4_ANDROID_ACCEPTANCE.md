# M4 Android acceptance — 2026-10-28

Continuation: [premium UI/UX acceptance, 2026-10-29](UI_UX_ACCEPTANCE_2026-10-29.md).
This document preserves the original M4 checkpoint; the newer report records
encrypted interactions, native unlock refinement, final APK and fresh tests.

Status: requested isolated two-device acceptance passed; normal-account acceptance
and production security review remain pending. No normal application was
installed, launched for testing, cleared or enrolled in M4.

Environment: physical Samsung SM-A546E and Medium_Phone_API_37.0 emulator,
`dev.shannon.shannon.validation`, manual `lib/main.dart`, explicit
`SHANNON_M4_MESSAGING=true`, arm64-v8a/x86_64. Existing independent test accounts
`m4_sam_a` and `m4_emu_b` use the retained isolated PostgreSQL cluster and API
127.0.0.1:18080 through ADB reverse. Normal API/database 8080 was not used or
migrated during these tests. It was stopped at resumption and was left untouched.

## Passed

| Check | Observed evidence |
|---|---|
| Independent accounts and keys | Exact-username request/accept succeeded. Database inspector reports two distinct account roots, device IDs, messaging DH keys and messaging signing keys. |
| Actual E2EE round trip | Samsung sent `Hello from Shannon E2EE test`; emulator decrypted it. Emulator sent `Encrypted reply received`; Samsung decrypted it. One local copy of each. |
| Recipient offline | Emulator was force-stopped and its reverse connection removed. Samsung submitted `M4 offline test`; one server ciphertext remained pending. |
| API restart with pending message | Same isolated PostgreSQL database retained the pending envelope across API rebuild/restart. Emulator reconnect decrypted one copy and acknowledged it; pending test count returned to zero. |
| Client process restart | Both validation processes were cold-started; encrypted histories and matching full fingerprint persisted. |
| Prekey replenishment | Authenticated inventory returned 50 unused prekeys on both devices after previous claims; identities unchanged. Rust regression verifies publication retry stability, retention of pending private prekeys and no surplus when inventory is full. |
| Sender offline | Emulator encrypted `M4 sender offline test` without transport; server receipt count stayed at 3. The message survived emulator cold start and local history reopening. |
| Automatic reconnect after offline cold start | Restoring emulator reverse forwarding, without a login tap or process restart, advanced test receipts to 4 and pending ciphertext to 1 while Samsung Validation was stopped. |
| API and PostgreSQL outage | Both isolated processes were stopped. Existing encrypted chat history reopened and `M4 outage history test` was encrypted locally. |
| PostgreSQL restart durability | Resuming the same cluster preserved the prior pending ciphertext; automatic sender resync advanced receipts to 5 and pending test envelopes to 2. |
| Backend plaintext inspection | While real messages were pending, SQL inspection found zero occurrences of all five known plaintext test markers in stored ciphertext. API/schema review found public bundles, opaque ciphertext and routing/idempotency metadata; no private-key or plaintext message fields or body logging. |
| Trust comparison | Both devices displayed the same complete Shannon fingerprint, `EC27 70B3 71D9 2AA6 A4F4 B62B B87D 02C6 A28D 0AE2 6A34 AC9E 355B 1AC1 FB27 9260`; explicit verification survived restart. |
| Native encrypted storage on Samsung | Real native encryption/decryption, Armenian/Russian/Unicode, duplicate rejection, transaction rollback before commit, history/session reopen, plaintext marker absent from SQLite/journals. |
| Persistent identity-change rejection | Physical native test detected changed keys, reopened storage, and rejected send, original-directory-bundle rollback and verification-button bypass with `identity_changed`. Temporary stores only. |
| Screen capture | Emulator fingerprint screen and final physical Samsung conversation capture produced black protected app content, while UI inspection confirmed real messages/screens. Chat-list plaintext previews are hidden. |
| Native Android tests | Three LockPolicy tests pass. |
| Flutter | Clean final analysis; 117 default unit/widget tests pass (one enabled-only test is skipped in that configuration). The additional enabled-M4 route/privacy test passes separately with the feature flag true. |
| Go/PostgreSQL | `go test ./...`, `go vet ./...`, and isolated PostgreSQL suites pass, including auth, signed prekeys/exhaustion/no resurrection, dedup, cursor concurrency, blocks/revocation/expiry, WebSocket hints/shutdown and stream token-expiry/revocation. |
| Rust/native build | Five upstream-library/adapter tests pass; locked release builds for arm64-v8a and x86_64 pass. |
| Original phone power setting | Saved original `stay_on_while_plugged_in=0` restored and read back. No new keep-awake override was needed during resumed tests. |

Final APK installed with `adb install -r` in both validation packages: PASS.
Both previously pending messages appeared once in Samsung history: PASS.
A fresh final-build message/reply (`M4 final build check` / `M4 final build reply`)
was encrypted, submitted and decrypted on both endpoints: PASS. Final scoped
inspector result: 7 real test receipts, 0 pending two-device ciphertexts, 2 distinct
roots/devices/DH/signing keys, both prekey inventories 50. Nine remaining global
queue rows belong to isolated opaque transport fixtures, not the two-device flow.
The five original known markers were checked while real ciphertext was pending;
zero matches were found. This is scoped evidence, not a proof about arbitrary
future content or malicious endpoints.

Both final builds retained the exact verified fingerprint quoted above. Normal
APK SHA-256 remains `07D34CB1A7C9ED278C1DA58FD59E6B772F054C20B0C6388FDC3A5BF569342AFB`.
Read-only hashes of three encrypted normal identity/key-storage files match
before/after the resumed validation. Normal storage has no `shannon_m4_v1.db`.
No normal install, clear, key operation, account migration or database operation
was performed. This establishes no change during these checks; it is not a new
cryptographic challenge against the normal account or a pre-M4 byte-for-byte
private-key audit, for which no earlier private-file hash baseline was captured.

Final normal-app biometric/caption visual acceptance remains unverified. A native
App Lock cover was observed on Samsung Validation and subsequent unlocked controls
responded, but no new complete timeout/enable/disable biometric matrix was claimed.

Final validation APK SHA-256:
`5DCF43DD79EC19F6312D80ABDE685D9183BD1E80CC81DB15FB9026B7048D6C54`.
Location: `apps/mobile/build/m4-validation/shannon-m4-validation.apk`.
It uses the validation application ID, manual main entry, and no integration-test
binding. Both native protocol ABIs and bundled notices are included.

## Failures found and fixed

- An app cold-started offline did not schedule session resumption/reconnect.
  Fixed bounded foreground retries for retained authenticated/offline sessions;
  no signup, logout reversal or key regeneration.
- An outage could show a misleading sign-in error. Added transport-specific
  queued/history-preserved wording and distinct messaging authorization errors.
- Identity-change rejection was only latched in memory. Persisted it natively
  before rejection; restart and old-directory rollback cannot clear it.
- App Lock could cover Flutter before a lifecycle notification arrived. Added
  native visibility query and operation gating while locked/backgrounded.
- A new capture wrapper caused blank chat lists on the final smoke test. It was
  removed; plaintext previews are hidden in the chat list instead. Conversations
  and fingerprints retain route capture protection. The enabled-feature routing
  regression and final physical/emulator smoke checks pass after this correction.

One earlier native run ended with Android `remove task`, not a native crash.
Subsequent native runs, including the final adversarial regression, passed.
No unresolved crash was observed in completed tests.

## Measured native debug timings

Final physical Samsung run: initialization max 182.541 ms (3 calls), send max
90.826 ms (2), receive max 74.820 ms (3), history max 25.156 ms (4). These are
channel + native worker/storage call samples under debug, not end-to-end network
latency percentiles or a smooth-frame/battery benchmark. Messaging authorization
signatures and public-bundle verification run in worker isolates; protocol
crypto/storage run on the native serialized worker.

## Unverified or gated

- Existing normal Samsung account ↔ emulator M4 acceptance. No normal APK
  upgrade or messaging-key enrollment is authorized for this test scope.
- Independent review of the original JNI bridge, identity-binding/application
  protocol, persistence/fault model and dependency/security findings. An upstream
  historical audit does not cover Shannon.
- Production TLS/WSS deployment and release signing, production performance,
  full crash-at-every-boundary and large/concurrent adversarial traffic matrix.
- Full physical biometric App Lock enable/timeout/unlock/disable matrix against this final M4 build;
  prior M3 manual results and native policy regressions are separate evidence.
- Manual visual confirmation of caption timestamps/send-state labels on the physical protected screen; automated checks and actual queue/receipt transitions are separate evidence.
- Long-duration retention clock/battery testing, full forward-secrecy and
  post-compromise integration assurance, future key-rotation transition.
- Multi-device fanout, key replacement, post-quantum encryption, recovery,
  backups, groups, media and calls are unsupported and are not claimed.

Raw local test evidence remains under ignored `.local-test/m4-*.xml`,
`.local-test/m4-native-final.log`, Flutter build test log and Gradle JUnit XML.
Do not publish these local device/test artifacts as production telemetry.
## Cleanup and resume

Samsung original keep-awake value is restored. Samsung Validation is left on
Chats. The owned emulator and isolated API/PostgreSQL processes were stopped;
the existing test accounts/database files were retained. The temporary loopback
HBA exception used to resume process-only test credentials was restored to the
original file. Normal PostgreSQL credentials and configuration were not changed.

To resume these same isolated test accounts from the repository root:

```powershell
.\scripts\Resume-M4Sandbox.ps1
```

The script deliberately does not initialize or delete the retained cluster.
It temporarily permits only the isolated `shannon_test` role/database on loopback
and restores its original HBA on exit; this is not a production configuration.
Start the existing emulator with `-no-snapshot-save` and no wipe, then configure
`adb -s DEVICE reverse tcp:18080 tcp:18080` and open Validation. Install updates
only with `adb -s DEVICE install -r` after verifying the validation package ID.
The normal installer currently builds with M4 disabled; do not present it as an
authorized M4 normal-account deployment workflow.
