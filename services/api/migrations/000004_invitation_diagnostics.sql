-- Capability hashes only; never retain plaintext invitations or an owner directory.
CREATE TABLE contact_invitation_history (
 token_hash bytea PRIMARY KEY CHECK (octet_length(token_hash)=32),
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz
);
CREATE INDEX contact_invitation_history_expiry ON contact_invitation_history(expires_at);
