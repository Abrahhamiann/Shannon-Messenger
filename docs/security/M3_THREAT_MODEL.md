# M3 threat model
Assets: root/device seeds, access/refresh tokens, authorization graph, public-key integrity.
Adversaries: network attacker, unauthenticated spammer, malicious registered user,
stolen/compromised device, malicious backend, malicious backup reader.
Trust boundaries: UI/service; Dart/native storage; Android sandbox/Keystore;
TLS/HTTP API; Go/PostgreSQL.

- Network substitution/replay: TLS; audience/purpose/key-bound signed nonce;
  atomic single use and expiry. Debug loopback HTTP is explicitly insecure.
- Malicious client: server verifies keys and proofs; no caller ID is trusted;
  ownership checked for devices, sessions, logout and revocation.
- Database disclosure: public keys/metadata and token hashes only; no key seeds.
- Backup extraction: Android backup exclusions; wrapping keys cannot be restored
  from ordinary app data. Physical OEM behavior still needs testing.
- Stolen unlocked/rooted device: software keys can be extracted from process memory.
  No biometric app lock in M3. Keystore wrapping does not solve endpoint compromise.
- Malicious server: can correlate devices, deny service or falsify responses.
  No transparency log or independently verified peer directory in this milestone.
- DoS: bounded input, pool, request timeout, local rate limiter and expiry cleanup.
  Not a complete distributed abuse-control architecture.
- Data loss: no recovery; explicit warning before key generation. No silent reset.
- Linking substitution: linking is disabled until an authenticated protocol exists.
- Future encryption: independent X25519/MLS keys; authentication signatures are
  not message encryption and do not authenticate future peer keys automatically.
