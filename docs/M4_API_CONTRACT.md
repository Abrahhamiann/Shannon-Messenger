# M4 API contract (gated implementation)

Messaging routes require `SHANNON_M4_TRANSPORT=1`; otherwise return 503 with
`messaging_not_enabled`. Existing auth/contact endpoints remain unchanged.
Bearer credentials belong only in Authorization headers. TLS is mandatory except
the existing authenticated development exception for loopback HTTP. Version 1
accepts only `olm.v1` and library message types 0/1. These routes never accept a
plaintext text/message field or private key. Unknown JSON fields are rejected.

| Route | Meaning |
|---|---|
| PUT /api/v1/messaging/bundle | Authenticated immutable epoch-1 identity and up to 50 signed public prekeys; replayed publication cannot resurrect claimed keys |
| GET /api/v1/messaging/bundle?account=ID | Read an accepted contact's authorized public identity without consuming prekeys |
| GET /api/v1/messaging/inventory | Read this device's unused public-prekey count and target=50; not another user's presence |
| POST /api/v1/messaging/claim | `{account}`; atomically claim one unused recipient prekey; explicit 409 exhaustion |
| POST /api/v1/messaging/envelopes | Accept opaque ciphertext and persist queue/receipt atomically; 202 first acceptance, 200 identical retry, 409 changed ciphertext for same ID |
| GET /api/v1/messaging/envelopes?after=CURSOR | At most 50 ordered, unexpired, currently policy-allowed envelopes for this authenticated recipient device |
| POST /api/v1/messaging/ack | `{sequences:["1",...]}`; exact recipient-owned acknowledgements, at most 50; idempotent 204 |
| GET /api/v1/messaging/status?id=ID | Sender-owned accepted/expired state; no read/seen or recipient acknowledgement disclosure |
| GET /api/v1/messaging/events | Authenticated WebSocket synchronization hints; see stream contract |

## Public bundles

Fields: account, device, suite, epoch, curve, signing, account_proof, device_proof,
prekeys. Retrieval additionally supplies root_key/device_key for verification;
publication rejects caller-supplied copies of those authentication public keys.
Each prekey is `{id,key,signature}`, with ID equal to its encoded public key.
All binary fields use canonical unpadded base64url; keys are 32 bytes, signatures
64 bytes. Account and device IDs must match the authenticated M3 identity.

The exact root/device signature input is LF-joined, no terminal LF:
`shannon-messaging-key-v1`, audience, account, device, suite, decimal epoch, curve,
signing. The prekey signature input is LF-joined: `shannon-messaging-prekey-v1`,
account, device, epoch, curve, signing, prekey ID, prekey key. Clients verify both
authorization proofs, public ID hashes, and the messaging signature on a claim.
These signatures authenticate library key distribution; they do not replace or
modify the library key agreement/ratchet. Root/device seeds remain unchanged.

Epoch is currently 1; existing messaging identities cannot be silently replaced.
Additional messaging devices are rejected explicitly until enrollment/fanout is
implemented. Identity replacement and re-verification need a future reviewed
transition; there is no overwrite workaround.

## Envelopes and limits

Submission: version=1, id (16 random bytes base64url), recipient account,
recipient_device, suite, type, ciphertext. Sender fields derive from the
authenticated session; supplying extra impersonation fields fails decoding.
Ciphertext is 1..65536 bytes; HTTP body at most 100000 bytes. Return acceptance
and absolute expiry timestamps, never a fake delivered/read result.

Fetch adds sender, sender_device, sequence (decimal string), expires_at. The
recipient validates matching routing/ID fields inside authenticated plaintext.
Device authorization is checked at the request boundary; revocation cannot
recall content already returned by an authorized request. Fetch also checks
current sender revocation, accepted-contact state and both directions of blocks.

Limits: 120 messaging operations/device/minute plus the existing 60/IP/minute
and global 600/minute boundary; 1000 pending envelopes and 16 MiB per recipient;
10000 lifetime public-prekey records/device (claimed tombstones prevent reuse).
Errors preserve account state and never trigger plaintext fallback.
