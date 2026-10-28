# Samsung Galaxy A54 validation and operating commands

Normal package: dev.shannon.shannon. Isolated integration package:
dev.shannon.shannon.validation. Do not uninstall, clear data, reset shannon_dev,
or use a real account for revocation tests. No commit/push is part of delivery.

## Acceptance matrix

Automated isolated Android run covers signup with nickname, real registration,
Keystore readback, nickname/avatar repository reload, contact request/accept/block,
real invitation QR render -> native ZXing decode -> backend validation, protected
and public FLAG_SECURE assertions, logout/login and same public identity.
Repository reload is not OS process death. Image decoding is not a live camera
test. Consult IMPLEMENTATION_STATUS.md for actual run results.

Manual pending:
1. Record normal app's public account ID locally; do not export private storage.
   Confirm saved nickname/avatar. Use existing-account Continue and compare ID.
   Confirm backend binding before replacing its APK. Do not repair a binding
   mismatch by changing stored identity or clearing data.
2. Confirm logout and back navigation cannot open protected routes; sign in with
   the same account, restart, compare public ID and profile again.
3. Enable App Lock; authenticate on the handset. Cancel unlock, then fingerprint;
   test PIN/pattern/password fallback, failed scans/OS lockout and credential
   changes. Test 0/30/60/300 seconds by leaving and returning on both sides of
   the boundary. Fresh process must require unlock. Verify normal foreground
   navigation does not lock and notification/deep-link entry cannot bypass it.
4. In the validation package only, kill/relaunch at registration network and
   metadata boundaries; compare IDs. Repeat with a username conflict and offline.
5. Generate a test invitation on another display; initiate camera scanning on
   the A54, grant/deny permission, cancel, rotate, scan, confirm preview and send
   a request. Check persistence from the other test account. Repeat expired,
   revoked, self, duplicate and malformed invitations.
6. Screenshot Settings successfully, sensitive route unsuccessfully, and inspect
   recents when backgrounded/locked. Do not capture genuine secrets for evidence.
7. TalkBack traversal and labels, largest font, landscape, en/hy/ru forms,
   keyboard/picker interruption, dark/light launcher masks. Profile frame times
   on hardware; debug integration timings are not 60 FPS evidence.

## PowerShell: backend (one terminal)

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
# Only when the installed service is stopped; may require an elevated terminal:
$pgService = Get-Service -Name 'postgresql*' | Select-Object -First 1
if ($pgService.Status -ne 'Running') { Start-Service -Name $pgService.Name }
. .\scripts\Set-LocalEnvironment.ps1
# Existing PGPASSWORD user environment or pgpass.conf must contain the configured
# shannon_app credential. Never paste credentials into logs or commit them.
$env:SHANNON_ALLOW_INSECURE_LOCAL_AUTH = '1'
$env:SHANNON_AUTH_AUDIENCE = 'shannon.local'
.\scripts\Start-LocalBackend.ps1
```

The startup script applies pending versioned migrations, never resets the DB.
Keep this shell open. In a second terminal:

```powershell
Invoke-RestMethod 'http://127.0.0.1:8080/health' -TimeoutSec 6
$adb = 'C:\Users\Erik\AppData\Local\Android\Sdk\platform-tools\adb.exe'
# Use the current Wireless Debugging screen, not an old port from a transcript.
$endpoint = Read-Host 'Current phone IP:connection-port (blank for USB/already connected)'
if ($endpoint) { & $adb connect $endpoint }
# If not paired, use the separate current pairing endpoint and interactive code:
# & $adb pair (Read-Host 'Current pairing IP:port')
& $adb devices -l
$device = Read-Host 'Exact Samsung device identifier from the list'
& $adb -s $device reverse tcp:8080 tcp:8080
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon\apps\mobile'
Remove-Item Env:SHANNON_VALIDATION_APP -ErrorAction SilentlyContinue
flutter pub get
flutter analyze
flutter test
flutter build apk --debug -t lib/main.dart --dart-define=API_BASE_URL=http://127.0.0.1:8080
if ($LASTEXITCODE -ne 0) { throw 'Build failed; do not install a stale APK' }
& $adb -s $device install -r '.\build\app\outputs\flutter-apk\app-debug.apk'
if ($LASTEXITCODE -ne 0) { throw 'Install failed; do not uninstall or clear data' }
& $adb -s $device shell am start -W -n dev.shannon.shannon/dev.shannon.shannon.MainActivity
# Only fixed validation markers; no broad log export with tokens/links:
& $adb -s $device logcat -d -s flutter:I | Select-String 'SHANNON_PRIVACY_TEST_(SECURE|PUBLIC)|All tests passed'
```

An existing identity bound to 10.0.2.2 must retain that logical configuration;
the existing explicit ANDROID_ADB_REVERSE define maps transport to localhost.
Do not silently install a different binding over it. The requested normal
localhost APK is for identities already bound to localhost or new installations.
This build fails closed on a mismatch and does not replace keys.

## Isolated regression

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
.\scripts\Test-M3Database.ps1
.\scripts\Test-M3Database.ps1 -AndroidDevice $device
```

That runner creates/stops/removes its own temporary PostgreSQL cluster and
installs only the verified validation application ID. It does not touch normal
Shannon. Rebuild the normal APK after this runner, since Flutter reuses the APK
output filename for validation builds.
