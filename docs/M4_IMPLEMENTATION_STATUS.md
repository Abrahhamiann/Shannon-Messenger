# M4 implementation status — 2026-10-28

Latest continuation: [premium UI/UX acceptance, 2026-10-29](UI_UX_ACCEPTANCE_2026-10-29.md)
and [encrypted interaction extension](security/M4_INTERACTION_EVENTS.md).
The baseline artifact/results below remain the Oct 28 checkpoint; the newer
isolated UI APK and fresh regression counts are in the continuation. M4 remains
disabled on the existing normal Samsung account.

**Isolated validation passed. M4 is not complete for the existing normal Samsung
account and is not approved for production deployment.** No commit or push.
All prior uncommitted work was preserved and continued in place.

The requested resumption checks have passed: independent real E2EE round trips,
recipient-offline ciphertext across API restart, sender-offline encryption and
cold-start reconnect, local history during a real API/PostgreSQL outage,
PostgreSQL restart durability, replenishment without private-key eviction,
ratchet/history persistence, persistent identity-change rejection, physical
native encrypted storage, final validation APK updates and capture protection.
Detailed passed/fixed/unverified evidence: M4_ANDROID_ACCEPTANCE.md.

## Implementation

- Pinned Apache-2.0 vodozemac 0.11.1, original Rust/JNI adapter, classical Olm v1
  3DH/Double Ratchet. No AGPL wrapper, custom ratchet or authentication-seed
  conversion/reuse as encryption keys. Public binding signatures/verification
  run off the Flutter UI isolate; protocol/storage use a native worker.
- Separate native messaging identity, signed public prekeys, authenticated
  root/device binding, persistent TOFU pins and comparison state. Key-change
  rejection is stored before reporting the error and cannot be cleared by restart,
  directory rollback or the old-fingerprint verification button.
- Keystore AES-GCM wrapping key; encrypted SQLite protocol/trust/message/outbox
  records. State/history/outbox commit atomically. Existing authentication
  namespaces/keys remain untouched. No SQLCipher or hardware-held-ratchet claim.
- Additive public bundle/prekey/opaque queue schema; contact/device authorization,
  bounded quotas, atomic claims, immutable retry IDs, exact durable acknowledgments,
  14-day pending retention and bounded idempotency metadata.
- Authenticated bounded WebSocket hints, expiry/revocation/shutdown, foreground
  reconnect/backoff and retained-session resume after offline cold start.
- Gated real chat list, composer, encrypted history/paging, copy warning, send
  state/retry and identity screen. Plaintext previews are hidden in the chat list;
  private conversations/fingerprints block capture. Native visibility is coupled
  to App Lock and queried before cold-start history access.

## Final verification

- Flutter analysis: clean. Default suite: 117 pass, one enabled-only test skipped.
  Enabled-M4 route/privacy regression: one additional pass.
- Rust library/adapter: 5 pass, including prekey retry/replenishment/retained
  pending private key; release arm64-v8a and x86_64 builds pass.
- Go tests/vet and isolated PostgreSQL suites pass, including WebSocket token
  expiration and device revocation. Three native Android policy tests pass.
- Physical Samsung native storage/adversarial regression passes; detailed timing
  samples and limitations are in the acceptance report.
- Final manual validation build installed with `adb install -r` on both devices.
  Seven real accepted test messages, zero scoped pending envelopes, unchanged
  verified fingerprint. Known plaintext markers absent from pending ciphertext.
- Normal APK hash matches the earlier checkpoint; encrypted normal identity-file
  hashes match before/after resumed tests; no M4 database exists in that package.
  No normal account or database migration/enrollment was performed. No normal
  private keys were read or exposed. Original Samsung power setting restored.

Final validation APK:
`apps/mobile/build/m4-validation/shannon-m4-validation.apk`

SHA-256: `5DCF43DD79EC19F6312D80ABDE685D9183BD1E80CC81DB15FB9026B7048D6C54`.

## Proprietary distribution and readiness

The pinned upstream manifest/license was rechecked. vodozemac 0.11.1 is
Apache-2.0; coder/websocket v1.8.15 is ISC. The locked 102-crate inventory records
permissive selected license choices, including an MIT option for dual-licensed
r-efi; no AGPL wrapper is used. Native third-party notices are bundled in
`assets/licenses/m4-native.txt`. This is an engineering compatibility screen,
not independent legal clearance or security approval of Shannon's integration.

Ready for a controlled normal-app integration **review**, with the isolated
functional checkpoint reproducible. Not yet cleared to activate against the
owner's existing normal account. Required gates before that step:

1. Review the original bridge, key-binding and trust transitions, transactional
   persistence/crash behavior and upstream security limitations/findings.
2. Review the additive migration and normal feature-gated build/install workflow;
   obtain authorization for normal messaging-key enrollment. Preserve the stable
   root/device identity and install only additively.
3. Perform the principal existing normal Samsung account ↔ independent emulator
   acceptance, including App Lock, complete caption/state visual checks and
   identity-preservation evidence. Validation cannot substitute for it.

Classical Olm v1 has 64-bit message authentication tags and no post-quantum claim.
No independent integration audit, production TLS/release/performance acceptance,
full compromise/recovery or crash-at-every-boundary matrix is claimed. One
messaging device/account, no replacement transition/fanout, account recovery,
backup, media, groups or calls. Local row encryption exposes opaque indices,
counts/order and timestamps to a database-file attacker; software/managed-memory
secrets are not guaranteed zeroized. See the threat model and acceptance report.

The retained test database and accounts remain available through
`scripts/Resume-M4Sandbox.ps1`. Test API/PostgreSQL/emulator were stopped after
acceptance and the original isolated HBA configuration restored. Normal API 8080
was already stopped when this resumption began and was not started or changed.
