# M4 production security gates — 2026-10-30

Not production-ready. Isolated functional acceptance is not security approval.
Each unchecked gate needs an owner, evidence and an explicit release decision.

- [ ] Independent review of original JNI/JSON adapter, Olm session selection,
  account/device/prekey proofs, TOFU/fingerprint UX and identity-change recovery.
- [ ] Independently reviewed encrypted event authorization, ordering, missing
  targets, replay, revisions, capability downgrade and recipient acknowledgments.
- [ ] Crash-at-each-commit-boundary, low-storage, Keystore loss, corrupted rows,
  backup restoration and rollback tests. Prove no silent identity regeneration,
  ratchet reuse or ack before durable commit.
- [ ] Resolve stale/compromised device policy and revocation races, including
  session/stream invalidation and in-flight messages. No multi-device claim yet.
- [ ] Complete current-source retained two-device acceptance and authorized
  existing-normal-account integration. Keep identity/hash preservation evidence.
- [ ] Deployment HTTPS/WSS, certificate/host validation, audience binding,
  reverse-proxy limits, timeout/quota sizing and logging redaction. Loopback HTTP
  authorization escape and temporary test HBA must be absent in production.
- [ ] Release signing configuration, protected signing keys, rotation/update
  policy, reproducible candidate provenance, ABI/library checks and SBOM.
  Current Gradle release build signs with debug credentials and is blocked.
- [ ] Full locked dependency inventory including Maven/Gradle/NDK/toolchains;
  dispose graph-only x/mod advisories; scheduled advisory monitoring. Re-run
  reachability scan for each backend release. Version scans are not audits.
- [ ] Disposition Olm v1 64-bit authentication tags, classical-only security and
  memory lifetime limits; never claim Signal interoperability or post-quantum.
- [ ] Recoverability disclosures: account keys/Keystore loss currently may be
  permanent. No history restoration without a reviewed encrypted backup protocol.
- [ ] Metadata/retention operations: routing, contacts, counts/order/timestamps,
  IP/rate-limit records, queue expiry and receipt cleanup. Verify cleanup across
  restart and sustained traffic without deleting necessary replay tombstones.
- [ ] Privacy/lock cancellation, lockout, timeout, foreground/background, cold
  start, accessibility tree, recents, screenshots, clipboard and Android-version
  matrix. Human biometric/PIN acceptance cannot be inferred from policy tests.
- [ ] Complete Armenian/Russian/English localization of M4/native lock/actions,
  large fonts, contrast, TalkBack, keyboard/insets and navigation acceptance.
  Several current M4 strings are hardcoded English.
- [ ] Long-history performance, memory/DoS bounds, session/prekey/effect lifetime
  exhaustion, flaky networks, reconnect storms, battery and foreground polling.
- [ ] Document incident response, forward-fix deployment, service suspension,
  key compromise warnings and recovery boundaries. No unproven old-APK rollback.

Completed development evidence: atomic row-encrypted store design, pinned
classical engine, additive server/local migrations, default-off normal feature
gate, isolated package guard, source fixes H1/H2 and patched x/text. Fresh run
details are in [acceptance](M4_FINAL_ACCEPTANCE.md); these are not substitutes
for the unchecked gates.
