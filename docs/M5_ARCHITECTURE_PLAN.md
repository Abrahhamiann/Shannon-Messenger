# M5 account recovery and multi-device — design proposal

2026-10-30. Design only; no enrollment, schema change or destructive recovery is
implemented or authorized. Begin implementation only after M4 integration
decisions and M5 scope are approved. This extends
[the existing recovery design](security/ACCOUNT_RECOVERY_DESIGN.md).

## Invariants and authority

Keep the existing account identifier/root public key as immutable anchor.
Generate fresh device signing and messaging keys on every added device; never
copy live ratchet state between devices or derive message keys from auth seeds.
Account access recovery and history restoration are independent capabilities.
The server stores public authorization records and opaque backups, not recovery
phrases, private keys or plaintext history.

Today a root signature authorizes messaging enrollment. Future recovered devices
cannot satisfy that rule merely by presenting a new device key. M5 must define a
versioned authorization-chain verifier anchored in the original account root:
root-signed recovery authority and device roster policy, followed by authorized
recovery/device statements at monotonic epochs. Update both server and peer
verification together; an older M4 client must fail closed on unknown chains,
not accept a substituted root. Whether to permit recovery-secret-encrypted root
escrow is a separate high-risk design decision, not an implicit implementation.

## Proposed components

| Component | Proposed design / unresolved decision |
|---|---|
| Recovery key and phrase | Independent CSPRNG 256-bit recovery seed; reviewed signing/KDF/encoding libraries and domain separation. Human mnemonic must preserve entropy with version/checksum and reviewed wordlists; no promise of twelve words. Recovery key file includes account/audience/version binding. Final standard and vectors require review. |
| Enrollment | Explicit unlocked authorized device action; short-lived single-use challenge bound to account, current roster/recovery epoch, recovery public key, action, audience and nonce. Existing authority signs enrollment; new recovery key proves possession. Local confirmation that the owner retained material before success. |
| Device linking | New device creates independent keys and one-time linking nonce. QR binds keys, account/server, expiry and transcript. Existing unlocked device compares/authorizes exact transcript after user confirmation. Establish an authenticated encrypted link using reviewed primitives; never trust relay-provided device keys alone. |
| Roster / authorization | Signed ordered device records, revocations and monotonic account authorization epoch. Server serializes changes under account lock and consumes challenges in the mutation transaction. Clients pin latest accepted roster/epoch and reject stale or forked changes. Server rollback/equivocation detection and transparency remain design gates. |
| Per-device messaging | Recipient roster fanout creates separately encrypted envelopes and independent sessions per sender/recipient device pair. A new active device cannot silently replace the old pinned messaging device. New device/fingerprint changes require clear trust UX. |
| Sync | Existing authorized device sends encrypted logical events/history export only with owner consent; destination verifies roster/transcript and authenticates source. Independent cursors, stable IDs, idempotent projections and causal revisions; never transplant active ratchets/skipped keys. Pins, drafts, local deletes and archives need explicit per-device versus shared scope. |
| Backup | Optional independent random backup master key; reviewed AEAD/key wrapping; versioned authenticated manifest and encrypted chunks with account, backup generation, schema and object IDs bound as associated data. Server sees opaque sizes/times. Separate key custody/retention/rotation policy; do not back up live ratchets for blind rollback. |
| History restore | Requires actual backup data plus its decryption key and compatible reader, integrity checks and rollback/version policy. A recovery phrase alone does not restore messages. Restored history is historical data; new device creates new sessions. Decide whether the recovery secret wraps a separate backup key and disclose expanded compromise impact. |
| Lost-device recovery | New independent device proves recovery authority against one-time challenge. Owner chooses reviewed revocation policy; default proposal revokes lost devices/sessions and rotates recovery authority after success. Transactional idempotency handles a lost success response without admitting another device. |
| Revocation / rotation | Advance signed roster/authorization epoch; revoke tokens/streams, stop new fanout and backup access, warn peers and remove revoked devices from future sync. Rotate recovery authority with old/current authority proof and new-key possession. Old epochs never reactivate. Previously received secrets/content cannot be recalled. |
| Compromised device | Suspend sync/fanout, revoke compromised device, rotate affected authorization/backup keys and establish fresh trusted sessions. If root/recovery authority is compromised, authority precedence and attacker/owner race need an explicit reviewed policy; rotation cannot undo prior authorized disclosure. |

## Additive data model proposal

New migrations, never rewrite M1–M4 migrations: recovery authorities/epochs,
signed device roster entries, one-time linking/recovery challenges and idempotent
operation records; per-device envelope routing/cursors; opaque backup manifests
and retention metadata. Existing accounts stay unenrolled and functional.
Do not drop the one-device enforcement until roster authorization and client
fanout are complete. Bound devices/account, challenges, queue/fanout, sync size
and storage, with tested concurrent enrollment/revocation.

## Test and review gates

Publish canonical signature/challenge vectors. Test wrong account/audience,
substituted device/QR, expired/reused nonce, stale/forked roster, revoked signer,
concurrent linking/recovery/rotation, interrupted success responses, service/DB
restart, disk corruption, backup replay/tamper/missing chunks and partial restore.
Test account recovery without history and history restore without ratchet reuse.
Verify no phrase/key logging, capture exposure or secret-bearing server fields.

Order: resolve authority/root continuity and threat model; independent protocol
review; additive server model and adversarial tests; native secret/phrase/link UI;
per-device messaging/fanout; optional reviewed backup and history sync; isolated
multi-device acceptance; explicit release approval. No M5 code starts under this
M4 review authorization.
