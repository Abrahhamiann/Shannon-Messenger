# Resumed-pass security notes — 2026-10-25

Local avatar normalization now lives in AvatarRepository and is tested for
successful reload, invalid-input preservation and unchanged identity records.
An image-descriptor lifetime bug discovered by tests was corrected. The saved
256px PNG contains re-encoded pixels; system-picker cache is not claimed erased.
No profile data is uploaded. Main tabs contain no fictional account activity.
Native decoder/system-picker attack surface still requires normal platform updates.

Android tests use dev.shannon.shannon.validation, verify that package ID before
additive install, use a fresh encrypted namespace, and attach to the running VM.
No uninstall, data clear or real-account revocation is performed. Test-only keys
are preserved; only the runner's own temporary PostgreSQL cluster is cleaned up.
M4 remains unavailable; no messaging confidentiality or production readiness claim.

# Security status

## M3 update — 2026-10-24

The historical M1 statements below describe the initial foundation only.
M3 now implements development identity/authentication with independent signing
keys, Keystore-protected storage, replay-resistant challenges and revocable
server sessions. Recovery, device linking and messaging encryption are NOT
implemented. Account loss after app-data or Keystore loss is possible.
Read security/M3_IDENTITY_DESIGN.md, M3_THREAT_MODEL.md and M3_SECURITY_REVIEW.md.
This integration has not received an independent security audit.
M1 contains no authentication, identity generation, encryption, recovery,
messaging, or user data. Do not use it for private communication.

Database credentials remain on the development machine; errors and health output
do not disclose them. Secrets are excluded by .gitignore. SQL parameters are
bound. Backend defaults to loopback, with bounded connections and request timeouts.
Local PG SSL is disabled only in the development helper. Deployments require
TLS, restricted roles, reviewed secrets management, and separate migration access.

Debug Android allows cleartext only to localhost, 127.0.0.1, and emulator host
10.0.2.2. Release code requires an HTTPS API URL and has no debug cleartext
exception. Generated release signing remains unsuitable for distribution.

Future threat-model work must cover malicious servers, stolen/compromised phones,
traffic analysis, malicious group members and attachments, leaked backups, and
denial of service. No claim of anonymity or production security is made.
