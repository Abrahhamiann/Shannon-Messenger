# M4 preliminary threat model

This is a design checklist for a feature not yet implemented, not an audit.

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
