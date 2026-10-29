# Encrypted interaction extension — 2026-10-29

Implemented and exercised in isolated Android validation. This original
application protocol extension and JNI/storage adapter require independent
security review. The vodozemac 0.11.1 Olm v1 engine is unchanged. Passing tests
do not constitute production security approval.

## Wire and authorization

Go still stores the existing opaque Olm envelope. Event types, text, reply
references and emoji are inside authenticated encryption. Routing metadata,
traffic size/timing and contact relationships remain visible to the server.
There is no plaintext server edit/reaction/delete endpoint.

Ordinary text retains application version 1. Version 2 carries replies,
`capabilities`, `reaction`, `edit`, `delete`, and `event_ack`. Forwarding is a
new encrypted send with a forwarded flag and no original sender identity; it
never reuses source ciphertext. This does not introduce a cryptographic suite.

An authenticated encrypted announcement advertises `interactions.v1`. Shared
actions remain unavailable until the pinned peer confirms support. Version-1
history remains readable. Live older-APK interoperability has not been fully
acceptance-tested; unsupported controls can remain pending until transport
expiry. No simulated capability or successful receipt is supplied.

Decoded sender/recipient account/device IDs must match the authenticated peer,
native owner and outer routing. A target is the original sender device ID plus
random message ID, scoped to that peer. Edit/shared deletion require the actor
device to equal the original sender device. Reactions belong to the authenticated
actor; user-controlled sender fields cannot authorize another actor's reaction.

Highest positive revision wins per actor/kind/target, with deterministic event-ID
tie ordering. Deletion is terminal; later edits cannot resurrect it. A 256-effect
limit per target fails excess operations rather than evicting protocol state.
Durable transport deduplication precedes ratchet/effect mutation.

## Transactions and confirmation

The serialized native worker commits protocol snapshots, messages, encrypted
effects and outbox together. A received mutation and its queued encrypted
application acknowledgment commit in the same SQLite transaction. Injected
failures roll back both. Duplicate delivery does not reapply or advance twice.

An acknowledgment must reference the local device's own control event in the
same pinned conversation. Server acceptance means ciphertext accepted for
delivery. Queued/waiting labels remain until the peer commits and sends the
authenticated acknowledgment. Late server acceptance cannot downgrade applied.
An acknowledgment is neither a read receipt nor proof of remote secure erasure.
Modified/untrusted peers can retain plaintext. Seen, copied, exported, captured
or backed-up content cannot be recalled. An accepted event whose peer never
acknowledges can continue to say waiting; eventual confirmation is not promised.
No presence, read/view counts or typing indicators are introduced.

## Storage and local scope

The same `shannon_m4_v1.db` and Keystore alias are retained. Additive local schema
1→2 introduces `messages.visible` (existing rows default visible) and indexed
`effects`. Effect payloads use existing row AES-GCM encryption/associated data.
Opaque peer/target indices, IDs, ordering and counts remain metadata; this is
not full-file SQLCipher. Identities, trust pins and ratchets are preserved.

Controls/acks are hidden from chat history. Delete for me redacts the original
text/reply and excludes that row from history, lookup and navigation; references
become unavailable. Already queued ciphertext may still deliver: this scope
does not recall a send. Shared deletion projects a tombstone on supported peers.
These are logical deletions. Older encrypted effect versions, SQLite pages,
journals or external copies can remain. No secure flash erasure is promised;
identities, session keys and the entire database are not destroyed.

Message pins are explicitly on this device, inside the encrypted peer record.

The reaction/chat follow-up also stores chat pin/archive/hide flags there.
Local bulk deletion and chat clearing preserve protocol state and dedup rows;
new text can reopen a hidden chat. Bulk shared deletion queues existing per-message
events atomically locally, with individual remote acknowledgments. There is no
new bilateral whole-chat deletion event or authorization. Selection is bounded
to 100 messages. No new cryptographic suite or plaintext server action is added.
Contact pins and aliases use separate encrypted `shannon_ui_v1` storage scoped
to the existing owner. Neither implies remote or multi-device sync. Profile
photos are not shared; recipient avatars use a disclosed fallback.

Authenticated Delete User ends only the accepted relationship, using participant
authorization and existing account locks. Block User uses existing block policy.
Both preserve identities, messaging keys and local history. A new request/accept
is required after removal or block/unblock before delivery is authorized again.
Relationship and block records are server metadata.

See [UI acceptance](../UI_UX_ACCEPTANCE_2026-10-29.md) for real-device and native
evidence. Independent review must cover event authorization/order, capability
interoperability, atomic storage/dedup, JNI, key binding, denial-of-service bounds,
clipboard and native lock lifecycle. Upstream audits do not review Shannon.
M4 remains disabled for the normal Samsung installation.
