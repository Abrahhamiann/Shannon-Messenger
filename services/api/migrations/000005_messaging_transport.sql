-- Public keys and opaque envelopes only. No protocol private state or plaintext.
CREATE TABLE messaging_devices (
 device_id text PRIMARY KEY REFERENCES devices(id),
 identity_id text NOT NULL REFERENCES identities(id),
 suite text NOT NULL CHECK (suite='olm.v1'),
 epoch bigint NOT NULL CHECK (epoch=1),
 curve_key bytea NOT NULL CHECK (octet_length(curve_key)=32),
 signing_key bytea NOT NULL CHECK (octet_length(signing_key)=32),
 account_proof bytea NOT NULL CHECK (octet_length(account_proof)=64),
 device_proof bytea NOT NULL CHECK (octet_length(device_proof)=64),
 next_sequence bigint NOT NULL DEFAULT 0,
 UNIQUE(identity_id,device_id)
);
CREATE TABLE messaging_prekeys (
 device_id text NOT NULL REFERENCES messaging_devices(device_id),
 key_id text NOT NULL,
 public_key bytea NOT NULL CHECK (octet_length(public_key)=32),
 signature bytea NOT NULL CHECK (octet_length(signature)=64),
 claimed_at timestamptz,
 PRIMARY KEY(device_id,key_id), UNIQUE(device_id,public_key)
);
CREATE TABLE messaging_receipts (
 sender_device text NOT NULL REFERENCES devices(id),
 message_id text NOT NULL,
 recipient_device text NOT NULL REFERENCES devices(id),
 digest bytea NOT NULL CHECK (octet_length(digest)=32),
 accepted_at timestamptz NOT NULL DEFAULT now(),
 expires_at timestamptz NOT NULL DEFAULT now()+interval '14 days',
 PRIMARY KEY(sender_device,message_id),
 CHECK(expires_at<=accepted_at+interval '14 days')
);
CREATE TABLE messaging_queue (
 recipient_device text NOT NULL REFERENCES messaging_devices(device_id),
 sequence bigint NOT NULL,
 sender_identity text NOT NULL REFERENCES identities(id),
 sender_device text NOT NULL,
 message_id text NOT NULL,
 message_type smallint NOT NULL CHECK (message_type IN (0,1)),
 ciphertext bytea NOT NULL CHECK (octet_length(ciphertext) BETWEEN 1 AND 65536),
 expires_at timestamptz NOT NULL,
 PRIMARY KEY(recipient_device,sequence),
 UNIQUE(sender_device,message_id),
 FOREIGN KEY(sender_device,message_id) REFERENCES messaging_receipts(sender_device,message_id)
);
CREATE INDEX messaging_queue_expiry ON messaging_queue(expires_at);
CREATE INDEX messaging_receipts_expiry ON messaging_receipts(expires_at);
CREATE TABLE messaging_limits (
 device_id text PRIMARY KEY REFERENCES devices(id),
 window_start timestamptz NOT NULL,
 attempts integer NOT NULL
);
