# Account recovery design

Status: proposal, not implemented, not independently reviewed. No recovery
credentials are generated or accepted by the application. No old messages exist
in this build. This document is a review input, not a security approval.

## Threat model and boundaries

Protect an existing account when its last device is lost without giving the
server a reusable recovery secret. Consider stolen phones, copied recovery
material, database theft, malicious registration clients, replay, concurrent
recovery, rollback, phishing, denial of service, compromised servers and endpoint
malware. Device unlock is not recovery authorization. A compromised OS can read
software keys after unlock; App Lock is not an additional cryptographic vault.
Transport must be authenticated TLS. An attacker controlling the server can
deny service and substitute directory answers; this design alone cannot prevent
that. No identity-proofing or human support override is proposed.

## Existing account continuity

Current shn1 identifiers are hashes of the account Ed25519 public key. They must
remain stable when devices are replaced. Do not derive a new account identifier
from a replacement device or recovery key. Retain the original account key as
the immutable identifier anchor. Introduce an independently authorized recovery
verification key and monotonic authorization epoch in a new migration. Existing
accounts are unenrolled until they explicitly enroll from an authenticated,
unrevoked device with the current root authorization. No automatic enrollment.

## Key hierarchy and credential representation

- Existing root identity key: account anchor and initial enrollment authorization.
- Independent device signing keys: one fresh pair per device; never share seeds.
- Independent messaging keys: future protocol-specific keys, never derived from
  Ed25519 identity or recovery credentials.
- Recovery signing seed: proposed 256 random bits from the platform CSPRNG,
  scoped to account recovery and generated client-side.
- Recovery verification key: server-held public key, bound to account, epoch,
  protocol version, purpose and authorization policy.

Use a reviewed deterministic derivation with explicit domain separation only if
multiple recovery subkeys are necessary. Otherwise use the seed directly with
the reviewed signing library. Do not invent a KDF or convert signing keys into
message-encryption keys. A key file must encode version, account identifier,
server binding, seed and checksum. Mnemonic encoding must preserve the selected
entropy; 256-bit material normally requires more than twelve words. Twelve words
are not an automatic requirement or a recovery protocol. Encoding choice,
checksum, supported wordlists and test vectors are review decisions.

## Proposed data flow

1. An unlocked, authenticated existing device explicitly enrolls recovery.
2. Client creates the recovery seed and derives the public verification key.
3. Server issues a short-lived, single-use enrollment challenge bound to the
   account, current device, recovery key, current epoch and server audience.
4. Root and device authorize the exact challenge; recovery key proves possession.
5. Server commits the public key and next epoch transactionally. No seed, phrase,
   encrypted seed backup or plaintext recovery file is sent to the server.
6. Client displays/export material only through a capture-protected route, with
   no logs, analytics, clipboard by default or screenshots. Require a real local
   confirmation of retained material before presenting enrollment as complete.
7. A replacement device generates independent keys. It reads the recovery
   material locally, verifies account/server binding, obtains a new challenge
   and signs it with the recovery key and replacement device key.
8. Server verifies both proofs and atomically enrolls the replacement device,
   consumes the nonce and updates the authorization epoch. A recovery operation
   identifier makes a lost successful response safely queryable/retryable without
   authorizing a second device. Idempotency is bound to the same signed keys.

The challenge includes action, version, account ID, audience, recovery epoch,
new device key, nonce, expiration, and explicit revocation policy. Canonical
encoding and exact-byte signature verification need published test vectors.
Reject unknown fields/algorithms and cross-purpose proofs. Never sign arbitrary
server bytes before validating every expected binding.

## Server authorization and concurrency

Store public verifier and epoch, never the plaintext recovery secret. Verification
does not depend on a low-entropy password hash. Rate-limit challenge issuance and
proof submission per account, IP and deployment-wide budget, without exposing a
public recovery/account directory. Bound payload sizes, outstanding challenges,
lifetimes and retained attempts. Rate limits mitigate service abuse; entropy is
the primary defense against offline guessing after database theft.

Serialize enrollment, recovery, rotation and revocation on the account row.
Consume challenges in the same transaction as the authorized mutation. Check the
current epoch after taking the lock. Replays, stale epochs, foreign account keys,
expired challenges and different-device retries must fail. Preserve monotonic
epochs across backup restoration and disaster recovery; rollback resistance is
an unresolved operational requirement.

## Replacement, rotation and compromise

The UI must explicitly state whether recovery revokes all old devices and their
sessions. Default policy proposed: replace lost-device access, revoke all old
devices, and require new recovery material before finishing. Multi-device users
need a reviewed selective-retention policy; no implicit retention or silent
revocation. Sessions are invalidated in the same transaction as device revocation.

Rotation requires current authorized device/root proof plus proof of possession
of the new recovery key. Recovery-assisted rotation requires an explicit old-key
proof and new-key proof. Never implement unauthenticated credential replacement.
Old recovery epochs become permanently unusable. A lost rotation response must
be resolvable by operation identifier and fresh proof without restoring old keys.

Anyone holding the recovery secret has recovery authority. If it is compromised,
an attacker can race the owner. Rotation from a trusted device invalidates old
material, but cannot undo actions already authorized. Device notifications and
an account security event history may improve detection; they do not solve the
race. A cooling-off/recovery-delay policy and root-versus-recovery authority
after compromise need independent review before release.

## Account versus message recovery

Recovering account access does not decrypt historical messages. Old message
recovery requires a separate encrypted-backup protocol, backup encryption keys,
integrity/version checks and retention consent. Do not derive a history key
from account signing keys or imply that new devices inherit message secrets.
Future E2EE must surface device replacement and verification changes to peers.

## Client storage and privacy

Keep operational keys in the existing designated protected store. Do not retain
recovery plaintext after enrollment unless a separate reviewed local storage
policy authorizes it. Dart/managed memory cannot guarantee zeroization; minimize
copies and document the limitation. Never log proofs containing secrets, phrase
text, key files or screenshots. Prevent ordinary task preview/capture on secret
routes. An external camera and compromised OS remain outside this guarantee.
Export-to-file and share-sheet behavior require a separate threat assessment.

## Phases and release gates

1. Resolve protocol, entropy/encoding, root authority, revocation, delay and
   rollback questions with an independent security reviewer.
2. Add backward-compatible migration and server authorization model. Existing
   unenrolled accounts continue to work. No destructive account migration.
3. Add published encoding/signature vectors and adversarial protocol tests:
   replay, substitution, expiry, wrong account, stale epoch, concurrent recovery,
   database rollback, lost enrollment/rotation response, revoked devices and DoS.
4. Implement native secret handling and accessible capture-protected enrollment,
   phrase confirmation and recovery UI. No dummy phrases in production.
5. Validate two physical devices, process death at every commit boundary,
   encrypted storage failures, backup exclusions and compromise response.
6. Independent cryptographic/application review, fixes, regression evidence and
   explicit release decision. Only then enable recovery controls.

Open decisions: hardware versus exportable recovery signing, mnemonic standard
and localization, optional offline key file encryption, rooted-device policy,
multi-device authority, recovery delay, server rollback detection, security event
retention and key-transparency integration. None are silently decided by the UI.
