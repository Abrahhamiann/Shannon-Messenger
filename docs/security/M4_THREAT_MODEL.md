# M4 preliminary threat model

2026-10-28 scope: proprietary Shannon; vodozemac 0.11.1/Olm v1 evaluation only.
Trust boundaries: Flutter/native worker, native encrypted persistence,
device/Go transport, Go/PostgreSQL, and out-of-band peer verification. Existing
root/device signing identities remain stable; messaging identities are separate.

Prekey substitution requires signature verification against a pinned authorized
messaging identity. Root/device-to-messaging binding proofs must be checked on
both server and client. Unknown/changed identities block sending until resolved;
TOFU cannot prevent a malicious directory substituting first-contact accounts.

Ratchet/session corruption and failed writes must fail closed with no automatic
identity regeneration. Received plaintext, dedup and ratchet advancement must
commit together before ack. Outgoing state/ciphertext commit before submission.
Serialized workers and transaction fault-injection tests are mandatory.

Future recovery and linking must preserve stable account anchors, independent
per-device secrets and explicit authorization epochs. Revocation cannot recall
already received ciphertext or erase plaintext from a malicious recipient.
Classical Olm v1 is not post-quantum; authentication-tag limits and dependency
audit findings must be recorded. Neither a new bridge nor Shannon is covered
by the library's historical audit.

This is the threat model for the gated validation implementation, not an audit
or approval for production deployment. Observed acceptance and missing review
items are recorded in M4_ANDROID_ACCEPTANCE.md and M4_IMPLEMENTATION_STATUS.md.

| Threat | Required mitigation/acceptance evidence |
|---|---|
| Network interception | TLS for authentication and envelope transport, plus protocol authentication; reject plaintext fallback |
| Compromised server substitutes public bundles | Peer identity pinning, visible changes, out-of-band fingerprint/QR comparison; first contact remains unverified until checked |
| Server reads database | Only public keys and ciphertext in server storage; inspect schema, logs and captured requests |
| Replayed, reordered or duplicated envelopes | Upstream protocol validation, bounded skipped keys and transactionally persisted deduplication |
| App crashes between encrypting and persisting | Atomic ratchet/outbox state; fault-injection tests at each transaction boundary |
| Concurrent sending or receiving | Per-session serialization with atomic state; race/interoperability tests |
| Lost/revoked device | Revocation blocks API access; peer-device trust change handling; clarify previously delivered ciphertext cannot be recalled |
| Stolen unlocked/rooted endpoint | Not solved by E2EE; plaintext and unlocked keys can be exposed. No hardware-key claim for software protocol keys |
| Traffic analysis | Server can observe routing, time, sizes and network addresses; define retention. Do not claim anonymity |
| Malicious recipient | Recipient can copy plaintext. Screenshot blocking cannot prevent external capture |
| Resource exhaustion | Per-user/device/IP quotas, envelope bounds, prekey limits and bounded skipped-key windows |
| Dependency compromise | Pinned source/binaries, provenance/license review, upstream vectors, independent integration review |

Forward secrecy and recovery after compromise must be demonstrated with the
chosen protocol's guarantees and integration tests. They are not properties of
the current M3 authentication code. No security claim is made for a future
recovery phrase, device linking, backups or group messaging.
