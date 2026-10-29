# M4 key management

Status: implemented behind the M4 gate in isolated Android validation. The
normal Samsung account has not been enrolled in messaging.

Keep existing root/device Ed25519 seeds and secure-storage namespaces unchanged.
Generate independent messaging signing/DH/prekeys through the selected library;
never convert/reuse authentication seeds for encryption. Root/device signatures
authorize a domain-separated public messaging identity and epoch. Public prekeys
are signed by the messaging identity. Replacement is explicit and detectable.

Android Keystore holds a non-exportable wrapping/storage key. Protocol identity,
ratchet and skipped keys are software secrets that exist in process memory and
must be authenticated-encrypted at rest in private application storage. They do
not each live directly in Keystore. Exclude Android backup/transfer. Storage keys
are independent from session tokens: logout/expiry must retain encrypted history.

Native worker serializes operations. Send commits state/history/outbox atomically;
receive commits account/prekey/session/history/dedup atomically before ack.
Write failure preserves the prior snapshot. Corruption fails closed rather than
regenerating identity. Prekey private material is removed only after successful
inbound creation and durable commit. Claims never reissue public one-time keys.

The client queries its authenticated unused-public-prekey inventory and targets
50 available keys. Publication retries retain unpublished keys; replenishment
does not evict private keys still needed by pending prekey messages. The adapter
fails closed at the upstream 5000-private-key storage bound rather than silently
discarding outstanding keys. Server claim tombstones have a 10000-record lifetime
bound. Identity rotation/replacement is deliberately unsupported in epoch 1;
there is no automatic key regeneration or overwrite path.

Native lifecycle visibility is coupled to App Lock. Messaging operations are
rejected while locked/backgrounded, and Flutter queries native visibility at
cold start before reading history. Foreground plaintext views are cleared when
the app backgrounds or locks. This does not promise process-memory zeroization.

Future device linking requires root authorization and independent per-device
keys. Account recovery and historical-message recovery remain separate designs;
neither is implemented. Losing the local wrapping key may permanently lose
history. Minimize plaintext memory/copies; no guaranteed managed-memory wiping.
