# M4 messaging design — evaluation, not deployment approval

2026-10-28 update: owner requires proprietary distribution. Official libsignal
and AGPL Dart wrappers are excluded absent separate rights. Evaluate Apache-2.0
vodozemac 0.11.1 through a separately authored native bridge. This is classical
Olm v1 3DH/Double Ratchet, not Signal wire compatibility or PQXDH. No experimental
v2 or custom ratchet. The following original checklist remains historical context;
the current decision is in M4_CRYPTO_LIBRARY_DECISION.md.

## Current-code audit and boundaries

M3 account/device IDs are SHA-256 thumbprints of separate Ed25519 public keys.
Root/device secrets remain unchanged in the current Android encrypted namespace.
Authentication proves possession; username discovery does not verify identity.
Device revocation currently invalidates server authentication. Messaging must
extend this check to bundle access, envelope submit/fetch and live streams.

Use independently generated library messaging signing/DH keys. A purpose-bound
statement containing audience, stable account/device IDs, messaging public keys
and epoch is authorized by both existing root/device signing keys. These are
authentication signatures, never encryption-key reuse. Library signing keys
authenticate one-time prekeys. Verify both authorizations, recompute public IDs,
and pin peer keys; server storage alone cannot establish peer authenticity.

Native worker owns crypto and local transactions. Sending commits advanced
session state, encrypted history and exact retryable outbox bytes atomically
before networking. Receiving commits account/prekey/session state, dedup marker
and history before acknowledgement. Rollback restores the old snapshot. Duplicate
checks precede ratchet mutation. Retrying resends identical ciphertext/message ID.

Use library ciphertext/type unchanged. Encrypted application payload includes
version, message ID, sender/recipient account/device IDs, timestamp and text.
Compare routing inside decrypted content with the pinned authenticated peer and
outer envelope. Reject mismatches, oversized messages and unsupported versions.
Per-session operations are serialized off the UI thread with bounded skipped
keys, page sizes, queues and parsing. A storage failure never regenerates keys.

Only accepted, unblocked contacts exchange envelopes. Sender routing derives
from authentication. Public prekey claims consume one key atomically, never
reissue it, and fail explicitly on exhaustion. No plaintext or weaker fallback.
Durable cursor sync is authoritative; authenticated WebSocket hints accelerate
it. Pending retention is at most 14 days from first acceptance; retries cannot
extend it. Acknowledgement is durable device acceptance, never reading.

Future device linking requires independent keys, root-authorized enrollment,
complete authenticated device lists and per-device trust/fanout. M4 must reject
unsupported fanout rather than silently omit devices. Recovery preserves the
account anchor and advances authorization epochs; recovering account access does
not recover historical messages. No server decryption keys or fake recovery.

Production activation requires independent protocol/bridge review, atomic-storage
fault injection, persistent trust-change handling and normal Samsung/emulator
acceptance. An audited dependency does not audit Shannon's integration. The
composer is enabled only in explicitly gated validation builds; the normal
Samsung package remains unchanged. Validation success is not production approval.

## Original prerequisites

The current application has M3 Ed25519 authentication only. No messaging protocol
has been selected or integrated. The proposed scope is one-to-one text between
two independently provisioned Android installations; groups, media, calls,
recovery, multi-device synchronization and encrypted profile sharing remain out
of scope until separately designed.

Candidate: maintained libsignal via its Android/Java bridge, with a pinned
upstream release. Verify the exact upstream session-establishment and ratchet
APIs at that release rather than claiming PQXDH or other capabilities based on
the project name. External use is unsupported and the API is unstable; see
https://github.com/signalapp/libsignal . License and maintenance ownership must
be settled before integration.

Proposed boundaries:

- Flutter orchestrates UI; a narrow reviewed bridge owns protocol operations.
- Messaging keys must be distinct from existing M3 signing seeds. No ad-hoc
  Ed25519/X25519 conversion or seed reuse. Define an authenticated binding using
  the chosen implementation's established identity model and review it.
- Server stores authenticated public bundles and opaque envelopes only. Public
  key registration is not proof against a malicious server substituting a peer.
- Peer safety-number/QR verification and visible identity-change blocking must
  exist before the UI claims a verified recipient.
- Protocol state and outgoing ciphertext must commit atomically before delivery.
  Receiving must commit ratchet state and deduplication atomically before ack.
- A server queue acknowledgement means accepted by the server, not read or
  decrypted by a recipient. Do not add read receipts, typing indicators, online
  status or last-seen status; these are explicitly excluded product features.
- Pending ciphertext retention must never exceed fourteen days, using a
  server-enforced expiry. A client cannot extend that limit. Routing identifiers,
  device identifiers, arrival/expiry times, sizes and network addresses remain
  server-visible metadata and require a documented retention policy.
- Keep strict envelope limits, bounded skipped-message keys, expiry and quotas.
  No database migration for messages should precede review of these contracts.

Unresolved: bridge release, distribution terms, local encrypted storage engine,
crash transaction contract, binding format, envelope schema/version negotiation,
prekey replenishment, trust-change UX, metadata retention and independent review.
See M4_THREAT_MODEL.md and ../M4_IMPLEMENTATION_PLAN.md.
