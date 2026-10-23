# Security status
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
