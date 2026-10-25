# M3 identity design — 2026-10-24
Status: development design, not independently audited or production-approved.
Written before implementation. Local M2 changes are the source of truth.
The latest user assignment supersedes the old milestone numbering.

## Objectives and scope
Prove possession of independent account and device Ed25519 keys without phone,
email, passwords, contacts, or personal data. Preserve keys through network
failures. Do not claim messaging encryption or anonymous network transport.

## Identity lifecycle and keys
Explicit user action generates two independent Ed25519 seeds with the library's
CSPRNG. Root signs first-device enrollment; device signs enrollment and login.
No deterministic derivation, no shared master secret, no Ed25519-to-X25519 conversion.
X25519/prekeys and MLS credentials are deferred until protocol integration review;
future device encryption keys must be independently generated and bound to device
authorization. Root keys authorize account operations, never encrypt messages.
Public IDs are shn1_/dev1_ plus RFC 7638 SHA-256 thumbprints of canonical RFC 8037
JWK JSON: {"crv":"Ed25519","kty":"OKP","x":"<unpadded base64url raw 32 bytes>"}.
Prefixes label the role; keys must differ. IDs are not authentication secrets.

## Registration and authentication
A fixed, narrow RFC 7515 compact JWS profile uses RFC 9864 Ed25519.
Protected header is exactly {"alg":"Ed25519","typ":"shannon-auth-v1"}.
Payload is the exact server-issued JSON bytes, base64url encoded, containing:
version=1, audience from server configuration, purpose register/login,
random 256-bit nonce, root_key, device_key and exp (Unix seconds).
Client checks ALL fields against its local keys, configured audience, requested
purpose, and a short lifetime before signing (120 seconds plus up to 30 seconds
of client clock skew at the upper bound). Server strictly enforces 120 seconds
without extending expiry for clock skew. Server verifies the exact
stored payload and fixed header, never caller-chosen algorithms or arbitrary
claims. Both signatures are required to enroll a first device.
Login requires the stored, unrevoked device bound to that root.
This is application authorization policy composed with standard signatures,
NOT an audited end-to-end identity protocol. Independent review remains a gate.

Challenges expire in 120 seconds and are consumed by DELETE ... RETURNING in the
same transaction as enrollment/session creation. Row locking prevents replay;
failed signatures consume the challenge as well. Duplicate enrollment with fresh
valid proofs is idempotent ONLY for the same original device. An existing root
cannot enroll another device via register. Revoked devices cannot re-enroll.
Device linking returns unavailable until an authenticated protocol is reviewed.

## Sessions and revocation
Random 256-bit opaque bearer access/refresh tokens; store SHA-256 hashes only.
Access lifetime 15 minutes; session/refresh absolute lifetime seven days.
Refresh replaces both hashes atomically without extending absolute lifetime.
Replayed refresh fails; this version does not implement reuse-family detection.
Lost refresh responses require a new signed login. Logout revokes server state.
Device revocation invalidates every session and is permanent in M3.
Session operations and revocation serialize using device-row locks. API checks
current device/session state on every protected operation; UI state is not proof.
Client sessions are Keystore-protected, and restart verifies /me before claiming
authentication. Server outages leave local identity intact, shown as offline.
In-flight revocation/logout linearizes at DB transaction commit.

## Secure storage and platforms
cryptography Ed25519 keys are exportable software keys in app memory; they are
NOT non-exportable hardware-backed Ed25519 keys. flutter_secure_storage encrypts
the persistent record using Android Keystore-backed protection. Hardware backing
of wrapping keys depends on the handset and is NOT claimed.
One encrypted identity record is written before network registration, read back
and verified on load; storage errors never trigger destructive re-generation.
Private material stays inside the repository/service, never presentation state.
Dart GC cannot guarantee zeroization of temporary strings or copied key bytes.
No secret goes into SharedPreferences appearance settings or application logs.
Android cloud/device-transfer backups are excluded; FLAG_SECURE protects windows.
Unsupported platforms fail explicitly; iOS/desktop secure-store adapters need review.

## Recovery decision
DEFERRED. BIP39 defines 128-bit entropy -> 12 words + checksum and PBKDF2 seed,
not enrollment recovery, root rotation, compromise response, or lost-device
revocation. No audited messenger-specific mapping has been established here.
Do not generate/show a mnemonic, accept a phrase, or pretend keys/history can
be restored. User must acknowledge that uninstall, clear-data, or Keystore loss
can permanently lose this DEVELOPMENT identity. No secret export or cloud backup.
BIP39 tests are not applicable until a recovery implementation is approved.

## Multi-device and loss
Independent device data model and device list/revocation are implemented.
QR linking/new device enrollment is unavailable, not a trust shortcut.
A lost last device currently means account loss. Recovery and root rotation
must be designed before real users can depend on these identities.

## Server trust, transport, metadata and abuse
Server sees public keys, account-device association, timestamps and request IPs;
it can deny service and lie about directory state. TLS authenticates the server.
No client-side message confidentiality is provided by authentication.
Auth refuses HTTP except explicit SHANNON_ALLOW_INSECURE_LOCAL_AUTH=1 AND loopback
peer (USB adb reverse). Production ingress must terminate TLS in the Go process
or use a reviewed trusted-proxy design; spoofable forwarding headers are ignored.
Bounded per-IP and global in-memory rate limits, body limit, strict JSON,
DB expiry cleanup, and request deadlines. Multi-replica/distributed DoS protection
and log retention controls remain deployment work.

## Tests and unresolved risks
RFC 8032 vector, cross-language JWS/profile tests, malformed signatures, invalid
serialization, expired/replayed challenges, token expiry/rotation/revocation,
ownership, concurrent replay and revoke/refresh, persistence/failure paths.
DB tests use real PostgreSQL, Android tests use real secure storage.
A self-review is not an independent audit. Plugin implementation/audit evidence,
physical Samsung backup/Keystore loss tests, recovery, root rotation, TLS deployment,
and messaging credential integration are production blockers.

## Sources
- https://www.rfc-editor.org/rfc/rfc8032
- https://www.rfc-editor.org/rfc/rfc7515
- https://www.rfc-editor.org/rfc/rfc8037 and https://www.rfc-editor.org/rfc/rfc9864
- https://www.rfc-editor.org/rfc/rfc7638
- https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
- https://pub.dev/packages/cryptography
- https://pub.dev/packages/flutter_secure_storage
- https://developer.android.com/privacy-and-security/keystore
- https://developer.android.com/privacy-and-security/risks/backup-best-practices

