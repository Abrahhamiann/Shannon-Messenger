# M4 final source review — 2026-10-30

Decision: **NO for activation now**. The implementation is suitable for continued
isolated validation, but the integration gates below require review and explicit
approval first. Second-device-only checks remain pending; per the owner's latest
instruction, development continues on Samsung without emulator recovery. This is a
development source review, not an independent security audit or certification.

## Repository baseline and scope

- Started on `main`, clean tracked/untracked status. HEAD `f4ed9a6` (`feat:
  implement E2EE messaging, premium chat UI and message actions`); preceding
  commits `f82a637`, `f28b0ae`, `3fdbeea`. Origin is
  `https://github.com/Abrahhamiann/Shannon-Messenger.git`. No remote fetch was
  needed; remote branch equality is not claimed. No repository AGENTS.md found.
- Reviewed M4 implementation/Android acceptance, UI acceptance and reaction/chat
  follow-up reports; security key management, threat model, trust and interaction
  designs; native store/actions/JNI/lock code; Dart controller/verification/UI;
  Go transport/bundle/stream authorization, migration runner and schema; test,
  build, resume and install scripts. Historical passes remain historical.
- Starting source changes: none. Ignored `.local-test` evidence, native libraries
  and build outputs already existed. They were not discarded. New source changes
  are listed below and remain uncommitted. No commit, push, normal install,
  account reset, key rotation or M5 implementation was performed.
- Dart `bool.fromEnvironment('SHANNON_M4_MESSAGING')` defaults false. Backend
  transport requires `SHANNON_M4_TRANSPORT=1`. Gradle uses
  `SHANNON_VALIDATION_APP=1` for `dev.shannon.shannon.validation`; otherwise the
  normal ID is `dev.shannon.shannon`. Non-main normal entrypoints are rejected.
  The normal install script is M4-disabled and is not an M4 activation procedure.

## Findings and fixes

| ID | Finding | Change / evidence |
|---|---|---|
| H1 | A directory lookup was added to `checkedPeers` before it succeeded. A 403/404/409 marked the first queued envelope failed, but a later envelope for the same peer could skip the fresh identity/policy lookup and attempt transport. Server authorization still applied; this was a client defense failure, not proof of plaintext disclosure. | Cache peers only after successful verified lookup and native trust. Three regressions assert zero submissions and two failed states for two same-peer envelopes under each rejection code. |
| H2 | Native receive did not consult the persistent `identity_changed` latch, although send and verification did. Old-session incoming traffic and duplicate acknowledgments could continue after a change was detected. | Reject receive before duplicate lookup, decryption or ratchet mutation. Physical Samsung regression passed: reopen storage and assert `identity_changed` for replay of a previously valid incoming envelope. |
| H3 | Public vulnerability scan found x/text v0.29.0 affected by GO-2026-5970 (normalization loop) and GO-2026-6629 (PRECIS panic). `govulncheck` reported reachable paths from `database.Open` via pgx. | Upgrade x/text to v0.41.0; required x/sync becomes v0.22.0. `go mod tidy` correctly classifies directly imported coder/websocket. Post-update Go tests/vet and govulncheck pass. No crypto engine or wire suite changed. |
| H4 | Flutter target-specific asset stamps reused a shared Android kernel from another entrypoint. Package-only validation allowed a manual APK to be installed for a test, causing the driver to stall; wrong API binding correctly refused identity loading without deleting it. | Invalidate only generated debug asset stamps before script builds; verify expected test filename and integration binding in the APK before install. Physical suite then passed. Normal installer now also invalidates the asset copy cache and explicitly compiles M4=false. It was not executed. |

Regression files: `apps/mobile/test/reaction_latency_test.dart` and
`apps/mobile/integration_test/m4_storage_test.dart`. Runtime changes are limited
to the controller/native trust guard and Go dependency lockfiles. Build script
hardening includes `Reset-FlutterAndroidAssetCache.ps1`, the native test payload
guard, and explicit default-off normal build configuration.

## Security architecture assessment

| Area | Observed protection | Residual risk / failure scenario |
|---|---|---|
| Crypto / JNI | Pinned vodozemac 0.11.1; explicit classical Olm version 1; independent library-generated messaging account; bounded JSON entry; panic caught with generic error; no private state returned to Dart by store operations. | Original JNI/adapter is outside upstream audit scope. Rust/Kotlin/Dart JSON/string copies contain secrets in process memory and are not guaranteed zeroized. JNI OOM/panic/process-death matrices remain incomplete. |
| Account/device binding | Root and device Ed25519 signatures cover audience, account/device IDs, suite, epoch, DH/signing keys; Dart verifies ID derivation/signatures before native trust. Prekeys are signed and canonical sized encodings checked. | TOFU/username lookup does not prevent a malicious directory substituting an unverified first contact. Out-of-band full fingerprint comparison is required. Native trust relies on the trusted Dart verifier; it is not a standalone signature-verifying API. |
| Identity changes | Stored device/root/device-key/DH/signing/epoch comparison latches rejection; rollback to old directory material and ordinary verification cannot clear it. H2 extends latch to receive. | No supported reset/replacement workflow. Do not delete the store to resolve a warning; investigate and design an authorized transition. |
| Prekeys | Persist before publication; publish retry returns existing unpublished keys; mark after success; retained private keys survive replenishment. Server claims transactionally, retains anti-reuse tombstones. | Native private key lifetime bound 5,000; server lifetime inventory 10,000. Exhaustion intentionally fails closed; monitored maintenance/replacement design remains open. |
| Ratchet / local store | Single native worker; SQLite transaction commits ratchet, message/dedup, effects and outbox together. Keystore AES-GCM key wraps rows with record-specific AAD. Existing DB without key fails rather than regenerating. Additive local schema 1→2. | Row encryption leaves IDs, counts, status/order/timestamps visible. Keystore loss makes history unavailable. File rollback plus Keystore survival is not prevented by a monotonic hardware counter. Power-loss/filesystem corruption acceptance remains required. |
| Replay / authentication | Library replay/tamper checks; candidate sessions cloned for trial decryption; durable device+message ID dedup; plaintext routing checked against owner and pinned peer; invalid receives roll back and are not acknowledged. | Dedup shortcut assumes trusted server delivery identity; injected duplicate IDs may suppress delivery but cannot insert new plaintext. Session limits and skipped-key bounds need stress testing. |
| Ordering / effects | Library accepts bounded out-of-order packets; effect revisions and ID ties project deterministically; delete terminal; actor device must own edited/deleted original; targets and acks scoped to peer. | Maximum 256 effects per target; hostile authenticated peer can exhaust interactions. Missing-target/out-of-order control handling is bounded but requires longer fuzz/DoS review. Local chronology is arrival order; timestamps are peer claims, not trusted time. |
| Offline outbox | Ciphertext/state durable before submission; IDs bind immutable envelope digests server-side; directory check gates each peer batch; reconnect/backoff and periodic hints repair missed wakes. | First session needs network/prekey. Four-page receive pass, queue limits and poison events need load tests. Retry/retention expiry are not guaranteed delivery. UI refresh errors after bulk commit need additional adverse-path review for duplicate user retries. |
| Acknowledgments | Exact queue sequences are scoped to recipient; native receive commits before ack. Encrypted control acks reference the local original control in the same conversation; late server acceptance cannot downgrade applied. | Text `accepted` means server acceptance, not read or recipient-confirmed delivery. Peer control ack is not proof of erasure or honest peer behavior. |
| Blocking / revocation | Backend requires accepted relationship and no block; fetch rechecks sender revocation and contacts; stream checks session expiry/revocation; exact ack cannot remove another device's queue. | Authorization is point-in-time; in-flight/already received data cannot be recalled. No completed user-facing multi-device revocation model. |
| Deletion / forwarding | Shared delete and edit require original sender device. Delete-for-me/chat pins/archive are local. Forward encrypts a fresh send. Whole-chat bilateral erasure remains disabled. | Logical redaction leaves possible old encrypted pages/effects, queued envelopes and external copies. No secure flash erase or global recall promise. |
| Lock / logging | Native opaque lock cover/accessibility hiding; FLAG_SECURE on protected/background/locked routes; cold-start visibility query; generic native failures and no message body logging in reviewed transport. Backup/transfer disabled. | UI lock is not cryptographic user-auth binding of every storage operation. Already running work can commit during a lock transition; minimize outstanding plaintext callbacks. OS/root compromise, cameras and managed memory outside guarantees. Fresh full biometric cancellation/timeout/rotation/TalkBack matrix remains open. |

## Dependencies and license review

Pinned Rust engine 0.11.1 has `default-features=false`, only
`precomputed-tables`; no `fuzzing` feature requested or present in the fresh
resolved feature tree. Bundled native notices and
locked license inventory exist; vodozemac declares Apache-2.0 and websocket ISC.
This is an engineering notice check, not legal clearance.

An OSV version scan queried 216 public package/version records across Cargo,
hosted Pub packages and the Go module graph. It found the two fixed x/text
issues and GO-2026-6179/6180 in graph-only x/mod v0.27.0. Go's reachability scan
reported only x/text as affected; after patch it reports no vulnerabilities.
The graph-only x/mod findings require build-tool inventory disposition; this
does not certify every Gradle/Maven/native OS dependency. Fourteen newer Flutter
packages fall outside existing constraints; availability alone is not a reason
to perform a broad compatibility upgrade.

Primary sources checked on 2026-10-30:

- [x/text normalization advisory](https://pkg.go.dev/vuln/GO-2026-5970),
  [PRECIS advisory](https://pkg.go.dev/vuln/GO-2026-6629).
- [x/mod log verification](https://pkg.go.dev/vuln/GO-2026-6179) and
  [lookup advisory](https://pkg.go.dev/vuln/GO-2026-6180).
- [Upstream base64 advisory](https://github.com/matrix-org/vodozemac/security/advisories/GHSA-j8cm-g7r6-hfpq)
  affects <0.7.0; [zeroization advisory](https://github.com/matrix-org/vodozemac/security/advisories/GHSA-c3hm-hxwf-g5c6)
  affects 0.5.0/0.5.1. Those ranges exclude 0.11.1.
- [Matrix security team's February analysis](https://matrix.org/blog/2026/02/analysis-of-reported-issues-in-vodozemac/)
  discusses low-order DH inputs and 64-bit tags. Shannon's pinned-source low-order
  regression passes, but that is not an exhaustive proof. Olm v1's 64-bit tags
  remain an explicit accepted-design-risk decision for a reviewer.

No Signal wire compatibility, post-quantum encryption, completed independent
audit, key recovery or automatic history restoration is claimed.

## Fresh verification and remaining gates

See [current acceptance](M4_FINAL_ACCEPTANCE.md) for actual runs, failures and
unverified observations; ignored logs use `.local-test/m4-review-*`.

Priority order before any normal-account activation:

1. Physical native regression and scoped final manual smoke passed. Complete the
   remaining manual acceptance matrix, including human biometric/PIN cancel,
   timeout/lockout, accessibility and prolonged adverse-condition checks.
2. Keep real two-device checks pending until a second independent device is
   available. No further emulator investigation, identity recreation or key copy.
3. Review H1/H2, JNI/binding, event authorization and crash consistency with an
   independent qualified reviewer; explicitly disposition remaining risk.
4. Follow [normal integration plan](M4_NORMAL_APP_INTEGRATION_PLAN.md): approve
   exact APK/backend/account scope and enrollment separately from UI deployment.
5. Complete localization/accessibility, failure recovery and production gates in
   [production checklist](M4_PRODUCTION_READINESS.md).

M5 is design-only in [architecture plan](M5_ARCHITECTURE_PLAN.md).
