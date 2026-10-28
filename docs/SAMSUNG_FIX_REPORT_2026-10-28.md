# Samsung A54 diagnosis and acceptance — 2026-10-28

This report continues the existing uncommitted project. No commits, pushes,
normal-app uninstall, data clear, database reset, identity replacement or key
rotation were performed.

## Proven cause of the reported screen

The supplied screen contains `test-only`, exactly the nickname entered by
`apps/mobile/integration_test/identity_test.dart`. Runtime inspection of the
Samsung SM-A546E identified the validation activity and process 32149. Its
Flutter log at 14:26:27 started the identity integration test; at 14:26:37 it
failed because `Account created!` was absent. Test-finder diagnostics followed
physical touches. The validation package had the same launcher label and logo
as normal Shannon, and the test driver explicitly left the application running.

The integration entry point initializes IntegrationTestWidgetsFlutterBinding,
then taps Sign Up, enters `test-only`, checks consent and taps Create account.
Flutter's LiveTestWidgetsFlutterBinding defaults
`shouldPropagateDevicePointerEvents` to false; device events are dispatched to
the test finder instead of normal gesture handlers. This explains both the
automatic actions and ignored physical touches in the observed validation UI.
There is no evidence that this failed run completed server registration.

Normal `dev.shannon.shannon` was not running at initial inspection. Its installed
APK exactly matched the previous local normal APK, SHA-256
`7882e49c13f776001515363a5fc7bf7069dff464435ff6748c9a035f99bcbf98`.
Its Dart kernel contained `package:shannon/main.dart` and did not contain the
integration binding, identity-test entry point or `test-only` literal. Launching
that exact normal package showed the existing Auditore account and avatar.
Tapping Check connection navigated successfully. This is runtime evidence,
rather than an assumption based solely on source code.

The normal startup source has no automatic registration. Signup restoration
reads saved form/identity data and does not submit it. Controller startup only
resumes saved sessions and reauthenticates an expired existing session. Route
redirects do not create keys or submit signup. App Lock's cover is a visible
native lock screen; no invisible touch blocker was observed in normal Shannon.
EXPORT_UI_PREVIEWS occurs only in host visual tests, not production startup.

## Changes in this pass

- `apps/mobile/android/app/build.gradle.kts`: normal application ID accepts only
  canonical `lib/main.dart`; alternate entry points require the isolated
  validation package. Validation launcher label is `Shannon Validation (TEST)`.
- `apps/mobile/android/app/src/main/AndroidManifest.xml`: generated app label.
- `apps/mobile/android/app/src/main/kotlin/dev/shannon/shannon/MainActivity.kt`:
  synthetic QR image decoding restricted to the debuggable validation package.
- `scripts/Test-M3Database.ps1`: always force-stops only the validation package
  in cleanup and disables it between runs. Explicitly enables it before a test.
- `scripts/Install-NormalAndroid.ps1`: explicitly builds lib/main.dart with
  API_BASE_URL=http://127.0.0.1:8080, verifies exact package and Dart test-binding
  absence, saves a stable normal artifact, installs with `adb install -r`,
  stops/disables validation and starts the normal package. No uninstall fallback.
- `apps/mobile/lib/features/onboarding/account_screen.dart`: submit handler
  itself rejects missing consent/loading/busy; button remains disabled for an
  empty nickname and updates as manual text changes.
- `apps/mobile/lib/features/identity/data/identity_repository.dart`: explicit
  HTTP 426 diagnostic, preserving the HTTPS and loopback-only server policy.
- `apps/mobile/lib/features/workspace/chat_search.dart`: existing-conversation
  filtering is local only; exact username lookup stays in the dedicated contact
  discovery screen. Local chat queries no longer make server requests.
- `apps/mobile/integration_test/identity_test.dart`: wait for actual asynchronous
  registration confirmation instead of assuming settled animations mean HTTP
  and Keystore operations have completed.
- Regression coverage in `identity_widget_test.dart`,
  `registration_recovery_test.dart`, and `ux_checkpoint_test.dart`.

## Data and backend

Before and after the first data-preserving update, encrypted
`shared_prefs/shannon_identity_v1.xml` had the identical SHA-256
`f0bb48607032065213b66da839b9c38089b8d665203caf1971ff0f68cf9fa452`.
No plaintext private keys were extracted. Normal saved public identity was
compared in full using ignored local device evidence; abbreviated value:
`shn1_3Dy9…7pt0`.

Initially the API was stopped and this agent had no configured PostgreSQL
credentials. PostgreSQL itself was running. The user restored the backend from
their authorized credential session. Health then passed but authentication
returned HTTP 426 because the loopback debug exception was not enabled in the
running server. After the user's restart with
SHANNON_ALLOW_INSECURE_LOCAL_AUTH=1, a synthetic invalid auth request returned
400 instead of 426, and normal saved-key login succeeded. The API stays at
127.0.0.1:8080 with adb reverse; remote cleartext authentication remains denied.

Unexpected real-account creation was not established. No existing account was
deleted. Synthetic integration identities used a separate app/secure-storage
namespace and a unique temporary PostgreSQL cluster.

## Automated results

| Check | Executed result |
|---|---|
| flutter pub get | Passed |
| flutter analyze --no-pub | No issues |
| flutter test --no-pub | 113 tests passed |
| Go unit tests, go test ./... | Passed |
| Isolated PostgreSQL go test -count=1 ./... | Passed |
| go vet ./... in isolated harness | Passed |
| Native Android :app:testDebugUnitTest | 3 LockPolicy tests, 0 failures |
| Normal-ID integration-target negative build | Rejected with required isolation diagnostic |
| Samsung isolated identity/contacts/QR/privacy integration | Passed, including native Keystore, signed Go/PostgreSQL signup, contact request/accept/block, actual rendered QR decoding, capture privacy, logout/login and synthetic device revocation |
| Normal APK build | Passed; exact package dev.shannon.shannon |

The integration test's repository reload is not OS process death. Native camera
scanning is separate from the passing synthetic image-decoding test.

## Physical normal-app acceptance

Verified on the connected Samsung A54:

- Explicit normal-package launch; saved account/blue ribbon/profile avatar.
- No automatic test nickname or signup on startup.
- Responsive Check connection tap and navigation.
- Real saved-key challenge-response login after backend transport correction.
- Chats empty state and Session verified profile with the saved public ID.
- Data-preserving update and encrypted-storage hash equality.

Final-install, logout, process-restart, contact, QR-camera and App Lock results
are recorded below. Unexecuted checks are not accepted.

Final normal artifact: `apps/mobile/build/normal/shannon-debug.apk`, SHA-256
recorded in the final delivery verification below.
The safe installer completed successfully, verified label Shannon and exact
normal package, then launched it. Validation process was absent afterward.

On the final installed normal build, Android input events successfully opened
profile, scrolled to Log Out, showed the confirmation dialog, confirmed logout,
and reached the saved-account screen with “Session revoked”. Force-stopping and
restarting while signed out retained Auditore and showed “Signed out on this
device”; no authenticated page or automatic signup appeared. Explicit saved-key
sign-in then returned to Chats. The same public identity was displayed before
logout. No identity replacement occurred.

Normal App Lock: initially disabled; the user successfully completed native
authentication to enable it. Android UI inspection confirmed the enabled switch
and all four timeout controls. Lock now displayed the opaque native “Unlock
Shannon” cover. Following a canceled/back attempt and activity reopen, the cover
remained locked. The user authenticated again; the cover was removed and normal
Chats/settings navigation responded. The user performed the remaining
30-second background/disable/restart checks; results below distinguish user
confirmation from agent-observed UI state. Native fingerprint/PIN entry is
handled by the user; credentials and biometric templates were not read.

User-confirmed normal-app results: 30-second timeout enabled; locked after 35+
seconds in the background; fingerprint/PIN unlock succeeded; Chats, Contacts and
Settings responded to touch; disabling App Lock succeeded; restart no longer
requested unlock. All seven reported steps passed. The 1-minute and 5-minute
timeouts have native boundary unit coverage, but were not each timed on the
phone. Full OS biometric lockout and credential-change tests remain unverified.

A validation process was reopened later (PID 9963; identity-test startup logged
at 14:51:59), while normal Shannon remained foreground. The validation package
was stopped and disabled with `pm disable-user --user 0` to prevent accidental
test launches. Its data was retained; ADB confirmed only validation was disabled.

Normal contact discovery accepted typed `@shannon_probe_1028` and returned the
real missing-contact result after explicit Find exact match. Generated a real
QR with a 24-hour server expiry. Screenshot capture of that ordinary contact
screen succeeded, confirming capture is not globally blocked. The native camera
scanner opened and the user scanned this QR from the computer display. ADB then
confirmed Add contact contained a correctly formed Shannon invitation link.
No contact request was sent. Physical camera decoding/navigation: PASS.

## Follow-up: invitation diagnostics

The original “Contact unavailable” after scanning was the deliberate self-invite
rejection (`p.ID == s.Identity`) in the backend, not a QR decoder failure. After
the update, opening the exact same scanned link in normal Shannon displayed
“This is your own invitation. Scan an invitation from someone else.”

Additional source changes:

- `services/api/migrations/000004_invitation_diagnostics.sql`: additive,
  owner-free capability-hash history for revoked/expired diagnostics. No tokens,
  private keys or account directory are stored here. History is pruned seven
  days after original expiry; links removed before this migration or beyond
  retention cannot be diagnosed precisely and receive invalid/unavailable.
- `services/api/internal/identity/contacts.go`: allowlisted error codes for own,
  invalid, expired, revoked/replaced invitations and unavailable contacts.
  Hidden and blocked usernames remain indistinguishable from missing accounts.
  Diagnostic responses do not return account IDs, owners or profiles.
- `services/api/internal/identity/http.go`: bounded expired-capability cleanup.
- Mobile repository parses only known codes; contact UI distinguishes those
  cases from network failures, backend service failures and expired sessions.
  Scanner-local invalid QR handling remains separate.
- Tests: `services/api/internal/identity/invitation_diagnostics_test.go` and
  `apps/mobile/test/contact_failure_test.dart`. The isolated database test proves
  a valid invitation resolves to a different account, self/expired/revoked
  messages differ, and replacing/revoking an invitation invalidates it.

The user restarted the credential-owning backend with the updated sources.
Normal-app replacement invitation generation succeeded and reopening the old
scanned link displayed “This invitation was revoked or replaced”. That live
operation requires the new history table and proves the new migration and API
code are active. PostgreSQL was not reset. Expiration was simulated only in the
isolated test database; real account expiry data was not edited.

A complete camera-mediated request/accept exchange between two different
physical accounts has NOT passed. Cross-account resolution/request/accept/block
and native image decoding pass in isolated Samsung integration; the physical
normal camera check used a self-invitation and is accepted only for decoding,
navigation and truthful self-invitation diagnostics.

## Scope limitations

First-launch signup under the normal package cannot be exercised on this
existing-identity installation without violating the data-preservation rule.
Startup/form regressions and isolated Samsung signup cover that behavior, but
are not a claim of a fresh normal-package signup acceptance test.

The approved ribbon, navy/blue UI, welcome, signup, authenticated confirmation,
saved-account login and recovery-unavailable pages are present. Recovery method
onboarding offers only key/phrase models, both explicitly unavailable; no fake
recovery words or functional recovery claim. The existing
`docs/security/ACCOUNT_RECOVERY_DESIGN.md` covers the proposed protocol and gates.
E2EE messaging and calls remain unavailable. Localization currently covers
onboarding and App Lock in English/Armenian/Russian; other screens remain English.
Full TalkBack, all large-text combinations, performance/battery profiling and
independent security review remain incomplete.

Expired-access logout is covered by the real PostgreSQL regression
`TestLogoutWithExpiredAccessUsesRefreshWithoutMintingTokens`; local/offline
logout and key preservation are covered by Flutter regressions. A separately
timed 15-minute normal-device logout experiment was not recorded, so it is not
claimed as a distinct physical acceptance result.

## Exact installation commands

Final delivery verification: normal APK SHA-256
`07d34cb1a7c9ed278c1da58fd59e6b772f054c20b0c6388fdc3a5bf569342afb`.
The final source built successfully and `adb install -r` reported Success.
Cold launch reached authenticated Chats. Final profile inspection confirmed
Auditore, Session verified, and the exact same full public identity as before.
The normal process was running; validation was disabled and had no process.
Shannon was left on Chats. The final isolated Samsung run against migration
000004 also passed and its cleanup disabled validation automatically.

Run from PowerShell using the current wireless-debugging port:

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
$adb = 'C:\Users\Erik\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb connect 192.168.0.130:44359
.\scripts\Install-NormalAndroid.ps1 -AndroidDevice '192.168.0.130:44359'
```

For the already built, verified normal artifact:

```powershell
& $adb -s '192.168.0.130:44359' reverse tcp:8080 tcp:8080
& $adb -s '192.168.0.130:44359' install -r '.\apps\mobile\build\normal\shannon-debug.apk'
& $adb -s '192.168.0.130:44359' shell am force-stop dev.shannon.shannon.validation
& $adb -s '192.168.0.130:44359' shell pm disable-user --user 0 dev.shannon.shannon.validation
& $adb -s '192.168.0.130:44359' shell am start -W -n dev.shannon.shannon/dev.shannon.shannon.MainActivity
```

Wireless-debugging ports can change. Never replace these steps with uninstall,
pm clear, flutter test installation against the normal package, or a database
reset. Keep the credential-owning backend terminal running.
