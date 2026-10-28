# Onboarding and authentication

The Riverpod IdentityController is the routing authority. Async loading denotes
initialization or an operation/renewal in progress; the router retains the last
stable state during an operation. Protected routes require authenticated state
or an existing offline identity for local views. Server actions always verify
the session independently. A local App Lock is enforced by Android above Flutter,
not by claiming that biometric authentication is a server login.

IdentityStage distinguishes none, local (including durable signed-out marker),
registrationInterrupted, authenticated, expired, rejected, offline,
storageUnavailable and revoked. A server 401 is deliberately ambiguous about
expiry/revocation; only confirmed local revocation is labelled revoked. Recovery
is a permanently unavailable UI capability in this build, not an auth success.

Signup validates a required nickname and optional normalized username using the
existing backend rules. It persists the existing encrypted identity before any
network request. The small registration_progress_v1 record contains nickname
and desired username, no keys. On restart a pending draft routes to signup.
Retry signs a fresh challenge with the same keys. Server enrollment is already
idempotent for the same original device, including a committed but lost response.
Username claim uses the authenticated existing profile API; conflicts leave the
draft editable and preserve keys. Discovery remains off unless explicitly enabled.
Availability is not claimed until the server accepts the profile write.

Identity persistence and draft persistence are separate writes. A crash between
them leaves a local identity that the existing-account screen can register; it
does not generate a replacement. A photo picked before registration is in memory
until the account operation completes; process death may require choosing it
again. This is a remaining avatar-draft usability limitation, not key loss.

Concurrent create calls on the application repository are rejected; concurrent
resume calls share one verification/refresh. Expired access credentials refresh
before /me; timer expiry runs renewal rather than immediately logging out.
If refresh is rejected, the controller may perform signed reauthentication.
No background polling. Startup always respects a durable signed-out marker.

Logout submits the refresh credential, so an expired access token cannot block
revocation. A 401 means that credential is unusable. A network failure offers an
explicit local-only sign-out and does not claim remote revocation. The deny
marker is persisted before session deletion; failure to delete cannot reuse the
session after restart. Late verification responses recheck the marker. Account
keys, nickname, avatar and database account remain intact.

Server/audience binding in the existing identity record is unchanged. A different
configured backend is an error, never an invitation to regenerate identity.
Debug localhost HTTP is explicit. No insecure production fallback is added.

Tests include simultaneous create, interrupted registration, username conflict,
restart/key continuity, shared verification, logout with expired access,
local-only logout/deletion failure, startup guards and expiry renewal. Android
integration covers real Keystore storage, Go/PostgreSQL, UI signup/logout/login,
native QR decoding and contact/capture operations in an isolated package.
