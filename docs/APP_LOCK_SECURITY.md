# App Lock

Implemented in Android AppLock.kt, separate from server authentication. Android
29+ uses BiometricPrompt with device-credential fallback (strong biometrics on
30+); 26–28 uses the platform device-credential confirmation activity. No local
PIN, fingerprint template or recovery credential is stored by Shannon.

Enable, disable and timeout changes require successful platform authentication.
Settings commit synchronously to app-private preferences; failed/cancelled
confirmation preserves the old policy. No device screen lock means unavailable.
Changing the OS credential/enrollment follows OS policy: this is a UI lock, not
an authentication-bound encryption-key vault. Removing the device screen lock
while enabled fails closed until a credential is set up again.

Timeout choices: immediately, 30 seconds, 1 minute, 5 minutes after leaving the
foreground. Monotonic elapsed time avoids wall-clock changes. Normal navigation
does not lock. Fresh process launch always locks when enabled. Native cover
blocks touch and hides underlying accessibility nodes; biometric cancellation
keeps it in place. Back may navigate underlying routes but never removes cover.
Android enforces biometric failure/lockout limits and device-PIN fallback.

FLAG_SECURE is applied while locked and while backgrounded. Existing route leases
continue to protect sensitive routes; ordinary foreground settings remain
capturable. Startup fails closed. No absolute claim against cameras/rooted OS.
The key store itself retains the pre-existing at-rest protection; App Lock does
not change, regenerate or delete keys and does not revoke server sessions.

Validation: native timeout unit tests and Flutter settings tests are separate
from hardware acceptance. Samsung enrollment changes, credential fallback,
cancellation, recents, process recreation and each timeout require the manual
matrix in SAMSUNG_A54_TEST_PLAN.md. No actual calls exist; call lifecycle policy
must be revisited before calling ships.

Platform references:
- https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt.Builder
- https://developer.android.com/reference/android/app/KeyguardManager
