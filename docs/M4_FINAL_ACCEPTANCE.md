# Fresh M4 acceptance — 2026-10-30

This report distinguishes fresh execution from the historical Oct 28–29 reports.
No normal-account M4 activation, normal APK replacement or identity recreation.

## Host verification

| Check | Current result | Evidence |
|---|---|---|
| Flutter pub get | PASS; 14 newer versions outside constraints | `.local-test/m4-review-pub.log` |
| Flutter analyze | PASS; no issues | `m4-review-analysis.log` |
| Default Flutter tests | PASS 139; one gated test skipped, not counted as pass | `m4-review-flutter.log` |
| Enabled-M4 tests | PASS 6 executions: route/privacy, chat-list actions and four local-queue/directory regressions | `m4-review-enabled.log`; some also run in default suite |
| Rust protocol/adapter | PASS 5 tests, no ignored tests | `.local-test/m4-final-rust.log` |
| Go tests/vet | PASS, including after x/text update | Fresh commands; DB-disabled cases are not counted as DB passes |
| Real isolated PostgreSQL | PASS including repeat with patched dependency graph | `m4-review-postgres-fixed.log`, `m4-review-native-final.log` |
| Go vulnerability reachability | Initial FAIL: two x/text issues; patched PASS, no vulnerabilities found | `m4-review-govulncheck.log`, `m4-review-govulncheck-fixed.log` |
| Android policy unit tests | PASS 3 tests, zero skipped/failures; initial overlapping build failed at asset copy | `m4-review-android-retry.log`, JUnit XML |
| Samsung native encrypted-storage suite | PASS: one substantive test plus framework teardown; includes new persistent receive-latch rejection | `m4-review-native-final.log` |

The initial sandboxed Flutter/DB attempts stalled in SDK/tool subprocesses.
Host-permission runs produced the reported results. An overlapping Gradle asset
copy failed; that failure is not a native unit-test assertion result.

Native physical execution used independent temporary native handles and in-memory
account identities, not the manual Samsung account. It exercised capabilities,
reply, reaction/change/remove, reversed edit delivery, fresh forwarding, local
pin/delete, shared delete/ack, batch ownership rollback, atomic bulk operations,
archive/pin reopen, local chat hide/reopen, identity latch persistence and
encrypted-at-rest marker scans. Counts: 57 receive, 27 history, 13 send, 3 initialize
calls. Maximum samples were about 250/216/225/208 ms respectively; these are test
call timings, not a UI frame-time or sustained performance benchmark.

Two initial driver attempts could not run the test: stale cross-entrypoint
Flutter assets packaged the manual entrypoint. Invalidating only generated asset
stamps fixed the payload; the script now verifies the integration binding and
expected test filename before installation. Earlier failed attempts are not passes.

## Real devices and premium UI

Samsung SM-A546E connected at user-provided wireless endpoint. Launched only
`dev.shannon.shannon.validation`; API restored at `127.0.0.1:18080` with the
existing retained isolated PostgreSQL cluster. No DB initialization/reset.

Fresh physical UI hierarchy observations on the pre-hardening retained APK:
compact Conversations/search area, All/Pinned/Archived chips, fallback recipient
avatar and saved name `Test`, persisted history, reactions and existing shared
deletion tombstones; message composer and bottom navigation present. These are
actual Android observations, not widget-test claims. They do not prove a new
encrypted round trip or validate the final hardened artifact.

Final hardened manual APK observations on the physical Samsung:

- Retained `M4-Samsung` identity and `Test` conversation reopened; old history,
  tombstones and reactions remained present. Light and dark Chats/Calls were
  captured and visually inspected. No placeholder card, plaintext chat preview
  or simulated calling. Original Light appearance was restored afterward.
- Floating menu shows the emoji bar, select/reply/copy/forward/local pin/edit/
  delete controls. Recipient fallback/name and keyboard/composer remained usable.
- With validation ADB reverse removed, synthetic
  `M4_FINAL_SAMSUNG_20261030` encrypted locally. Backend receipts remained 66 for
  the retained pair with zero scoped pending messages while offline.
- Validation process was cold-started. After transport restoration the retained
  session automatically resumed without a login tap; the one synthetic message
  reappeared once and backend pair receipts increased to 67, scoped pending to 1.
  This proves sender persistence/submission, not recipient delivery.
- The one pending ciphertext record survived both real isolated API and
  PostgreSQL restarts with the same scoped checksum. A nonempty scoped SQL scan
  found zero occurrences of the synthetic plaintext marker (result `1|0`).
- Public validation identity-binding aggregate remained unchanged. Physical
  fingerprint still matched the historical full fingerprint
  `EC27 70B3 71D9 2AA6 A4F4 B62B B87D 02C6 A28D 0AE2 6A34 AC9E 355B 1AC1 FB27 9260`,
  with the existing verified-by-comparison state. No re-verification/reset.

Actual final Samsung captures:
[light Chats](previews/m4-final-2026-10-30/chats.png),
[dark Chats](previews/m4-final-2026-10-30/chats-dark.png),
[light Calls](previews/m4-final-2026-10-30/calls.png),
[dark Calls](previews/m4-final-2026-10-30/calls-dark.png).

The retained emulator AVD `Medium_Phone_API_37.0` initially loaded an Oct 24
`default_boot` snapshot. That snapshot had only `dev.shannon.shannon` installed.
A cold boot with no snapshot load/save also showed only normal Shannon. No
Validation package/retained validation identity was available in this AVD state.
No replacement account was created, no private keys copied, and no data wipe
performed. Prior reports of two-device passes are not fresh passes.

Current two-device acceptance status: **PENDING / NOT REPEATED**. All requested
bidirectional send/reaction/reply/forward/edit/delete, both offline directions,
API/DB restart with pending ciphertext, ratchet/fingerprint continuity and scoped
plaintext inspection remain unverified on the final hardened two-device pair.
Native independent-handle tests are complementary and cannot substitute for it.
The owner explicitly directed on 2026-10-30 to stop emulator work and continue
physical Samsung/native/backend testing. The emulator started for this review
was stopped. No further search/recovery is planned under this task.

Premium UI remaining: complete contact actions/QR, search/filter/order and
long-history scrolling matrix, native biometric/PIN
success/cancel/background, Armenian/Russian strings, text scaling and TalkBack.
Source has hardcoded English M4 strings, so multilingual completion is not
claimed. Existing widget suite checks several layouts; no simulated calls added.

## Preservation and commands

Hardened Samsung manual artifact:
`apps/mobile/build/m4-final-review/shannon-validation.apk`.
SHA-256 `E9F6B0DB93326F60D6FF3A05E8314B953C55B80CBBBA8442DDFDEA4BB212BFDC`.
Debug ARM64, `lib/main.dart`, M4=true, validation package, original validation
API `http://127.0.0.1:18080`. Package ID and absence of test binding verified
before installation. Existing historical APK artifacts were retained.
After installation, the device APK SHA-256 matched this artifact exactly.
The current validation process had zero matches for inactive-render/deactivated
widget errors, unhandled exceptions or Flutter caught-exception headers in the
scoped log sample. This is a smoke observation, not a long-duration guarantee.

Normal encrypted identity-file hashes and APK path recorded before test installs
under `.local-test/m4-review-normal-before.txt` and
`m4-review-normal-apk-before.txt`. The three encrypted identity/config/key-wrapper
file hashes matched after native execution. Installed normal APK SHA-256 remains
`07D34CB1A7C9ED278C1DA58FD59E6B772F054C20B0C6388FDC3A5BF569342AFB`,
matching the prior checkpoint.
The normal database had no M4 store in the scoped initial file inventory.
No private keys, account bearer tokens or recovery secrets were printed,
decrypted or uploaded.

Retained isolated backend inspection: two distinct accounts, roots, devices,
messaging DH and signing keys; 50 unused prekeys each. Before the synthetic test,
66 two-account submission receipts and zero scoped pending envelopes; afterward,
67 receipts and one scoped pending envelope, retained for the offline recipient.
No peer acknowledgment or remote deletion was fabricated. Known historical
markers and the new synthetic marker had zero ciphertext hits; only the latter
scan against the one new pending record is a fresh non-vacuous message check.

Public APK signature verification passed for both installed normal and final
validation APKs; signing certificates match (debug certificate). This establishes
one update prerequisite, not normal-install authorization or release signing.
Final normal encrypted identity-file hashes matched the initial hashes again.

Runtime: emulator stopped per owner instruction. Final manual Validation is
enabled on Samsung, original Light appearance, Chats open. Retained validation
API/PostgreSQL at 18080 remains running for physical testing; it uses the existing
resume script's scoped temporary loopback test-role HBA rule. Stop that sandbox
and restore its original HBA without deleting data using:

```powershell
'{"operation":"stop"}' | Set-Content .local-test/m4-control.json
```

Resume later with `scripts/Resume-M4Sandbox.ps1`; do not initialize/reset it.
Normal app and normal backend configuration were not changed.

Run host checks from their respective directories:

```powershell
# apps/mobile
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter test --dart-define=SHANNON_M4_MESSAGING=true test/messaging_enabled_navigation_test.dart test/reaction_latency_test.dart test/chat_list_actions_test.dart
# services/api
go test -count=1 ./...
go vet ./...
go run golang.org/x/vuln/cmd/govulncheck@v1.9.0 ./...
# repository root
.\scripts\Test-M4Protocol.ps1
.\scripts\Test-M3Database.ps1
.\scripts\Test-M3Database.ps1 -AndroidDevice 192.168.0.130:33101 -M4StorageValidation -TestApiPort 18081
```

Native script uses a fresh disposable DB and unique native test stores. It
installs a test entrypoint only in Validation, then disables it on exit. Restore
the final **manual** validation main-entry APK additively after the suite and
verify package ID first. Never run a test installer against normal Shannon.
Serialize Flutter/Gradle builds sharing the same output directory.

Build/install preparation and exact approval boundary are in
[normal integration plan](M4_NORMAL_APP_INTEGRATION_PLAN.md).
