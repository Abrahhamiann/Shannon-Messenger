CREATE TABLE identities (
 id text PRIMARY KEY,
 root_key bytea NOT NULL UNIQUE CHECK (octet_length(root_key)=32),
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE devices (
 id text PRIMARY KEY,
 identity_id text NOT NULL REFERENCES identities(id),
 public_key bytea NOT NULL UNIQUE CHECK (octet_length(public_key)=32),
 created_at timestamptz NOT NULL DEFAULT now(),
 revoked_at timestamptz,
 UNIQUE(identity_id,id)
);
CREATE INDEX devices_identity_idx ON devices(identity_id);
CREATE TABLE auth_challenges (
 nonce text PRIMARY KEY,
 purpose text NOT NULL CHECK (purpose IN ('register','login')),
 root_key bytea NOT NULL CHECK (octet_length(root_key)=32),
 device_key bytea NOT NULL CHECK (octet_length(device_key)=32),
 payload text NOT NULL,
 expires_at timestamptz NOT NULL
);
CREATE INDEX auth_challenges_expiry_idx ON auth_challenges(expires_at);
CREATE TABLE auth_sessions (
 access_hash bytea PRIMARY KEY CHECK (octet_length(access_hash)=32),
 refresh_hash bytea NOT NULL UNIQUE CHECK (octet_length(refresh_hash)=32),
 identity_id text NOT NULL,
 device_id text NOT NULL,
 access_expires_at timestamptz NOT NULL,
 expires_at timestamptz NOT NULL,
 FOREIGN KEY(identity_id,device_id) REFERENCES devices(identity_id,id)
);
CREATE INDEX auth_sessions_device_idx ON auth_sessions(device_id);
CREATE INDEX auth_sessions_expiry_idx ON auth_sessions(expires_at);
