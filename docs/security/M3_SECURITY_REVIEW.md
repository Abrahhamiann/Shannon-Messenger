# M3 engineering security review — 2026-10-24

This is an implementation self-review, NOT an independent cryptographic audit.
Decision: development authentication foundation may be exercised with test
identities. M3 is NOT fully complete or approved for production because recovery,
linking authorization, key rotation and independent review remain unresolved.

| Gate | Evidence / result |
| --- | --- |
| Design before crypto | M3_IDENTITY_DESIGN.md and M3_THREAT_MODEL.md written first |
| No custom primitives | Go crypto/ed25519, crypto/rand, crypto/sha256; Dart cryptography; maintained Edwards point decoder |
| Standard proof format | Narrow RFC 7515 JWS profile; RFC 9864 Ed25519 header, no algorithm negotiation; server-issued exact payload |
| Key separation | Independent CSPRNG root and device seeds; RFC 7638 public IDs; no signing/encryption key reuse |
| Enrollment authority | Both signatures; existing root cannot add another device through registration; ownership verified from DB |
| Freshness/replay | 256-bit nonce, 120-second expiry, DELETE RETURNING inside transaction; concurrent replay test permits one success |
| Session lifecycle | Hash-only bearer storage, 15-minute access, absolute seven-day refresh, atomic rotation, logout and self-revocation |
| Concurrent revocation | Device/session row locks; DB tests verify no session survives successful revocation |
| Secure persistence | Android plugin resetOnError=false; encrypted record; native test exercises write/read with separate namespace |
| Recovery after loss | NOT IMPLEMENTED; account loss explicitly disclosed before creation; no mnemonic generated |
| Transport | Auth requires native TLS, or explicit loopback-only debug exception; untrusted forwarding headers ignored |
| Data minimization | Public keys, associations, creation/revocation/expiry times; no nickname or secrets uploaded |
| Secret leakage | Request allowlists and tests exclude seeds/mnemonics; no auth body/token logging; UI masks raw exceptions |
| Android backup/screens | Cloud and device-transfer exclusions, allowBackup=false, FLAG_SECURE; OEM physical behavior unverified |
| Migration safety | New forward-only 000002; previous migration unchanged; apply-twice integration test on isolated PostgreSQL |
| Regression | Existing health and M2 navigation/theme tests retained and passing in validation runs |
| Independent audit | NOT DONE |

## Findings resolved during implementation
- Disabled plugin's destructive automatic reset behavior.
- Explicit local-creation acknowledgement because no reviewed recovery exists.
- Fixed application protocol header to fully specified Ed25519 (RFC 9864).
- Bounded HTTP bodies (8 KiB server, 64 KiB client) and cancellable client deadline.
- Prevented redirects from forwarding tokens.
- Refused caller-selected algorithms, mismatched key/purpose/audience bindings,
  noncanonical/low-order public keys, and trailing/unknown JSON fields.
- Allowed 30 seconds of upper-bound client clock skew after the real Android
  test failed the original tight check; server expiry remains exactly 120 seconds.
- Added local session expiry state and foreground revalidation.
- Kept test storage and databases separate from user data; repaired Windows
  child-process handling in the isolated test harness.

## Residual risks and limitations
1. No independent audit of this integration or verified audit coverage for the
   exact Dart/plugin versions. Standards compliance is not sufficient assurance.
2. Root and device keys are exportable software keys; Keystore protects storage,
   not compromised-process memory. Hardware backing is device-dependent.
3. Dart strings/GC do not provide reliable zeroization. No biometric app lock.
4. Root remains on the first device; compromise of that device compromises both
   authorities. Future recovery/rotation design must address this explicitly.
5. No recovery, mnemonic confirmation, root rotation, remote lost-device
   revocation, QR linking, cloud backup, or encrypted message history.
6. Refresh rotation has no token-family reuse detection. Lost refresh responses
   require signed login. One active session per device is intentional.
7. Rate limiting is per-process, not distributed. A malicious server can deny
   service and correlate identities/devices; metadata privacy is limited.
8. A repository reload was tested on Android, not process death/reboot/Keystore
   invalidation or every OEM's backup implementation. Physical Samsung tests
   and hardware attestation have not been performed.
9. Native TLS support is provided, but public TLS deployment, certificate
   management, reverse-proxy policy and operational log retention are not validated.
10. No X3DH/Double Ratchet or MLS integration yet; these auth keys must not be
    silently repurposed for encryption.
11. Optional image avatar selection and identity QR sharing are deferred;
    nickname is local-only. Existing messenger tabs remain labeled UI previews.
12. Debug builds are not release-signed, audited, optimized or approved for
    confidential communications. No absolute anonymity claim is made.

## Next review gates
Commission independent review of enrollment/session policy and storage integration.
Select reviewed recovery and device-linking designs; define compromise/rotation
semantics before implementing phrases or enrolling real users. Validate process
death, backup exclusion, locked-device access and Keystore loss on Samsung hardware.
