# M4 messaging design — preliminary, not approved

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
