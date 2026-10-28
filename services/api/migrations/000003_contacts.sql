CREATE TABLE contact_profiles (
 identity_id text PRIMARY KEY REFERENCES identities(id),
 username text UNIQUE CHECK (username ~ '^[a-z][a-z0-9_]{2,31}$'),
 discoverable boolean NOT NULL DEFAULT false
);
CREATE TABLE contact_invitations (
 owner_id text PRIMARY KEY REFERENCES identities(id),
 token_hash bytea UNIQUE NOT NULL CHECK (octet_length(token_hash)=32),
 expires_at timestamptz NOT NULL
);
-- One canonical pair is the mutual accepted relationship or one pending request.
CREATE TABLE contact_relationships (
 low_id text NOT NULL REFERENCES identities(id),
 high_id text NOT NULL REFERENCES identities(id),
 sender_id text NOT NULL REFERENCES identities(id),
 state text NOT NULL CHECK (state IN ('pending','accepted')),
 PRIMARY KEY(low_id,high_id), CHECK(low_id<high_id),
 CHECK(sender_id=low_id OR sender_id=high_id)
);
CREATE INDEX contact_relationships_high ON contact_relationships(high_id);
CREATE TABLE contact_blocks (
 owner_id text NOT NULL REFERENCES identities(id),
 target_id text NOT NULL REFERENCES identities(id),
 PRIMARY KEY(owner_id,target_id), CHECK(owner_id<>target_id)
);
CREATE TABLE contact_limits (
 identity_id text PRIMARY KEY REFERENCES identities(id),
 window_start timestamptz NOT NULL,
 attempts integer NOT NULL
);
