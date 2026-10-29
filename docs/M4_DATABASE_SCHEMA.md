# M4 database schema

Additive migration: `000005_messaging_transport.sql`. No auth/contact tables or
existing records are reset. Normal deployment of this migration is pending the
owner's deployment authorization; it has been exercised on isolated PostgreSQL.

- messaging_devices: existing account/device references, suite/epoch, public DH
  and signing keys, public authorization signatures, next recipient sequence.
- messaging_prekeys: public keys/signatures, immutable per-device IDs and claim
  times. Claimed entries remain anti-reuse tombstones; no private key material.
- messaging_receipts: sender-owned idempotency ID, ciphertext/routing digest,
  recipient device, acceptance/expiry. No plaintext or read state.
- messaging_queue: recipient sequence, sender routing, library message type,
  opaque ciphertext and absolute expiry. No decrypted message body.
- messaging_limits: bounded durable per-device request-window counters.

Queue insertion, receipt creation and cursor advancement commit together.
Recipient row locking orders cursor allocation and commit, avoiding the gap
hazard of globally allocated sequence numbers whose transactions commit out of
order. Exact acknowledgements remove only rows owned by the authenticated device.

Pending ciphertext is excluded from retrieval immediately at expiry and deleted
by minute cleanup. Maximum pending lifetime is 14 days from first acceptance;
identical retries do not extend it. Idempotency/status metadata is retained one
additional day, then deleted. This is a bounded dedup horizon, not a promise of
infinite server replay history; the client stops retries after 14 local days
and retains its own durable message dedup/history records.

Local Android storage is separate: SQLite records contain AES-GCM-encrypted
protocol snapshots, trust records, message bodies and outbox envelopes. The
wrapping key is in Android Keystore. Opaque peer indices, counts, row order and
timestamps remain visible in the private local database; this is authenticated
row encryption, not full-file SQLCipher. SQLite journals receive ciphertext,
not plaintext message values. Local plaintext/metadata must never be logged.

The isolated UI extension additively upgrades the same local file to schema 2:
`messages.visible` defaults to visible for existing rows; indexed `effects`
stores AES-GCM-encrypted interaction bodies. Identities, Keystore alias, ratchets
and v1 history are retained. See [interaction scope](security/M4_INTERACTION_EVENTS.md).
