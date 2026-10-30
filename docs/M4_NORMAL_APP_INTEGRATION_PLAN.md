# M4 normal-app integration plan — preparation only

Status: not authorized for execution. Normal package `dev.shannon.shannon` and
existing personal account must remain unchanged. No approval is inferred from
isolated validation. Current readiness decision is NO pending final acceptance.

Fresh preparation evidence: installed normal APK hash matches its historical
checkpoint; encrypted normal identity-file hashes match before/after testing;
normal and hardened validation APKs verify under the same debug certificate.
No normal install or messaging enrollment occurred. See current acceptance for
the exact validation artifact and outstanding review gates.

## Compatibility and risk assessment

| Area | Plan | Risk / gate |
|---|---|---|
| Existing account | Keep existing root/device signing keys, identity ID, tokens and secure-storage namespace. Existing contacts stay associated with that identity. | Compare encrypted identity-file hashes and public identity IDs before/after. Never print private material. An identity replacement is a failed migration, not recovery. |
| Enrollment | Generate independent messaging keys only after explicit activation approval; sign public messaging binding using existing root/device keys. | First enabled start may initialize native storage and publish keys automatically. Installing/launching an enabled APK crosses the enrollment boundary; it is not a harmless UI trial. |
| Local database | Create `shannon_m4_v1.db` with independent wrapping key; existing stores migrate schema 1→2 transactionally. | Never delete/reset a store on failure. Missing Keystore key, corruption or owner mismatch must stop access and preserve evidence. No universal recovery exists. |
| Server | Apply only checksummed additive migrations with existing runner, after normal DB owner approves scope and backup/restore procedure. Enable transport only on reviewed deployment. | Normal account and validation DB are distinct. An isolated pass does not authorize production schema mutation. Migration 000005 adds tables, not plaintext or private keys. |
| Offline startup | Retain authentication and encrypted local history. Existing sessions can queue offline; first peer establishment requires an online claim. | New enrollment cannot be called complete until authenticated publication succeeds. No account recreation or silent reset on network failure. |
| Server binding continuity | Preserve the exact logical `API_BASE_URL` and `AUTH_AUDIENCE` stored with the existing account. | `_load()` refuses a different server/audience as incompatible configuration. Switching to a new HTTPS hostname is a separately reviewed identity-binding migration, not merely changing a build flag. |
| Peer trust | Preserve existing contacts; resolve public bundle only for authorized accepted contact. Compare full fingerprint out of band. | Messaging is one active device/account today; changed device/key must remain latched. Normal account's new messaging fingerprint differs from isolated Samsung's. |
| Rollback | Treat UI-only and protocol/storage transitions separately. | `adb install -r` preserves package data but proves no old-reader compatibility. Older APK may reject schema 2, lose new controls, or mishandle advanced ratchets. No downgrade after enrollment without proven compatibility. |

## Approval boundary

The owner must explicitly approve the exact normal APK SHA-256, package ID,
signing-certificate digest, backend URL/audience, target device and existing
account public ID, additive server migration scope, and **first normal messaging
key enrollment**. Approval must acknowledge no proven protocol downgrade,
no current history recovery, one-device limit and outstanding independent review.
Do not use a generic installation approval as permission to rotate keys, reset
databases, clear data or restore old ratchet snapshots. Commit/push is separate.

## Procedure after gates and explicit approval

1. Complete fresh isolated acceptance on the exact candidate source/artifact.
   Record source diff, APK hash, signing digest, package ID, API audience and
   native library hashes. Retain the previous APK for diagnosis, not as a proven
   downgrade escape hatch. Check storage capacity and OS/Keystore availability.
2. Read normal package/version/signing certificate, stable public account/device
   identifiers and ciphertext-file hashes. Do not decrypt/export key material.
   Do not start the normal app merely to collect private data. Confirm current
   normal contacts and explicitly authorized test peer through owner review.
3. Review normal backend connection/TLS and additive migrations. Take an approved
   database backup under established access controls; never copy private client
   keys into backend backups. Confirm restore cannot replay authorization epochs.
4. First optionally deploy an M4-disabled UI candidate with correct certificate,
   after separate install approval. Prove normal authentication/contact/lock
   continuity before any enabled build. UI-only rollback still requires testing.
5. Build the approved M4-enabled normal candidate explicitly; verify package,
   signature and hash *before* installing. Do not use an integration-test entry
   point. Never uninstall or use `pm clear`. Stop if signature/version mismatches.
6. Install additively only after approval. Launch while unlocked and online for
   initial independent messaging enrollment. Compare existing account/device
   identities and contact relationships, then verify the new peer fingerprint.
7. Use synthetic data for normal ↔ independent validation peer acceptance: send,
   receive, reactions, reply/edit/delete acknowledgments, offline/restart,
   deduplication, encrypted store durability, lock/capture, session expiration.
   Personal history must not be deleted for testing. Inspect only scoped backend
   test ciphertext for known markers.
8. Stop activation on any invariant failure. Keep all identity/ratchet files.
   Prefer a forward-compatible corrective APK. Disabling server transport can
   stop new network delivery but does not undo enrollment or schema changes.
   Disabling UI must not erase history. Never restore an old ratchet snapshot
   while peers have advanced; it can cause key reuse/replay or undecryptable data.

## Exact preparation commands

From repository root; these **build only** and do not authorize an install:

```powershell
.\scripts\Build-M4Protocol.ps1
.\scripts\Reset-FlutterAndroidAssetCache.ps1
Set-Location .\apps\mobile
$env:SHANNON_VALIDATION_APP = '1'
flutter build apk --debug -t lib/main.dart --dart-define=API_BASE_URL=http://127.0.0.1:18080 --dart-define=SHANNON_M4_MESSAGING=true
```

Before a validation install verify `aapt2 dump badging` returns exactly
`dev.shannon.shannon.validation`, then:

```powershell
$adb = 'C:\Users\Erik\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb -s DEVICE reverse tcp:18080 tcp:18080
& $adb -s DEVICE install -r VERIFIED_VALIDATION_APK
& $adb -s DEVICE shell am start -W -n dev.shannon.shannon.validation/dev.shannon.shannon.MainActivity
```

Normal candidate build template, **do not run until candidate configuration is
approved**; URL and audience placeholders require the exact existing saved
logical binding. A production HTTPS transition requires its own migration review:

```powershell
$env:SHANNON_VALIDATION_APP = $null
& ..\..\scripts\Reset-FlutterAndroidAssetCache.ps1
flutter build apk --debug -t lib/main.dart --dart-define=API_BASE_URL=EXACT_EXISTING_LOGICAL_URL --dart-define=AUTH_AUDIENCE=EXACT_EXISTING_AUDIENCE --dart-define=SHANNON_M4_MESSAGING=true
```

Debug builds are controlled local evaluation artifacts, not release artifacts.
Current release signing uses a debug key and must be replaced before production.
After explicit normal install/enrollment approval, the install command is:

```powershell
& $adb -s APPROVED_DEVICE install -r EXACT_REVIEWED_NORMAL_APK
```

No automatic downgrade, uninstall, data clear, database reset, key deletion or
re-enrollment command is part of this plan. The existing
`scripts/Install-NormalAndroid.ps1` launches/installs immediately and changes
validation package state; do not use it as a preparation-only command.
