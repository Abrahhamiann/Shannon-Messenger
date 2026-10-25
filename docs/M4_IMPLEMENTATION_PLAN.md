# Milestone 4 — prerequisites and next work

Status: NOT IMPLEMENTED. No E2EE transport, prekeys, ratchet state or encrypted
message queue has been added. M3 signing authenticates sessions; it is not
message encryption. This document records the gate before Phase F/G, rather
than claiming those phases complete.

1. Finish the coordinated Phase E UI migration and acceptance checks.
2. Evaluate a pinned maintained protocol implementation and its Android bridge.
   `signalapp/libsignal` is the leading candidate, not an approved dependency.
   Its official README states that external use is unsupported, bridges/APIs
   may change, and distribution is under AGPLv3:
   https://github.com/signalapp/libsignal
3. Decide and document Shannon's distribution/license compatibility. Do not
   assume a dependency license is compatible with unspecified product terms.
4. Implement a narrowly scoped native bridge with upstream protocol vectors and
   cross-client interoperability tests. Do not port a ratchet from a spec or
   combine raw cryptographic primitives into a new messaging protocol.
5. Review binding of M3 root/device identity to distinct messaging identity keys,
   prekey rotation, peer-key verification and device-revocation propagation.
6. Design transactional local encrypted session/message state, crash recovery,
   bounded skipped keys and retry/idempotency behavior before networking.
7. Add authenticated public prekey publication and an opaque envelope queue,
   quotas, a fourteen-day maximum pending retention and acknowledgement semantics to Go/PostgreSQL. Never
   accept message plaintext, private keys or local profile metadata in logs.
8. Validate two isolated Android installations, offline delivery, duplicate and
   reordered envelopes, concurrent sends, key changes, revoked devices, restart
   and tampering. Independently review the integration before production claims.

The current repository lacks the bridge, protocol dependency, state storage,
prekey service and two-device acceptance suite. This is concrete unfinished
implementation work, not evidence that safe protocol libraries do not exist.
No plaintext messaging fallback or mock encrypted-send button is permitted.
