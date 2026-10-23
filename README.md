# Shannon — Milestone 1

Working source lives at `C:\Users\Erik\OneDrive\Desktop\Shannon`.
This is a development foundation, not a secure messenger release.
The supplied UI image guides the near-black/graphite surfaces, blue accents,
rounded settings rows, typography, and four-tab navigation. No fake accounts,
messages, encryption, or calls are implemented.

## Repository

- `apps/mobile/`: Flutter Android app, Riverpod, GoRouter, package:http.
- `services/api/cmd/api/`: Go HTTP process.
- `services/api/cmd/migrate/`: explicit migration command.
- `services/api/internal/`: database pool and HTTP handlers.
- `services/api/migrations/`: embedded, ordered SQL migrations.
- `services/api/tests/`: opt-in PostgreSQL integration test.
- `packages/`: reserved crypto bridge and shared protocol contracts.
- `infrastructure/`: reserved database, Docker, TURN, and SFU documentation.
- `docs/`: decisions, requirements, validation, and API contract.
- `scripts/`: Windows PowerShell entry points.

## Run on Windows PowerShell

Prerequisites verified locally: Flutter 3.47.7 / Dart 3.13.5, Go 1.27.3,
Git 2.55.0, Docker CLI 29.9.2, PostgreSQL 17 service. Docker is not required
for M1; its daemon has not been validated.

Open PowerShell in the repository:

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
Push-Location services/api
go mod download
Pop-Location
Push-Location apps/mobile
flutter pub get
Pop-Location
```

Use the authenticated local environment that already connects as
`shannon_app` to `shannon_dev` on `localhost:5432`. The application reads
standard PG environment variables (including PGPASSWORD) or DATABASE_URL;
pgx also supports the standard PostgreSQL password file. Do not put credentials
in source, chat, command-line arguments, or the mobile app. The scripts import
an existing user-level PGPASSWORD if the process does not already have one.
The sample .env file is documentation, not automatically loaded.

Terminal 1:

```powershell
.\scripts\Start-Api.ps1
```

Expected: migrations applied successfully, then JSON log with address
127.0.0.1:8080. The first migration creates only schema_migrations.
No identity or message tables are created. Re-running is safe; editing an
applied migration is rejected. Add a new numbered SQL file for future changes.
Migrations run transactionally with an advisory lock. Rollbacks are not
automated; use reviewed forward migrations and backups.

Terminal 2:

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
Invoke-RestMethod http://127.0.0.1:8080/health
flutter emulators --launch Medium_Phone_API_37.0
Push-Location apps/mobile
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
Pop-Location
```

Replace emulator-5554 with the Android ID returned by flutter devices.
Select **Check backend connection**. Expected: **Connected to Shannon** and
**Go API is healthy. PostgreSQL is reachable.**

For a USB-connected Android device, keep the backend bound to loopback:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s YOUR_DEVICE_ID reverse tcp:8080 tcp:8080
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon\apps\mobile'
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

## Tests and builds

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon'
.\scripts\Test-Foundation.ps1
# Real database migration/idempotency/health test:
.\scripts\Test-Foundation.ps1 -Integration
# Real Android → Go → PostgreSQL test; API must be running:
Push-Location apps/mobile
flutter test integration_test/connection_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
# Launch/navigation only; does not require a running backend:
flutter test integration_test/launch_test.dart -d emulator-5554
flutter build apk --debug
Pop-Location
```

APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`.
Unit tests use explicit test doubles only; the application and Android
connection test always use real HTTP. Database integration tests skip unless
SHANNON_INTEGRATION=1; the script's -Integration flag enables them.

## Troubleshooting

- **No password supplied**: this shell lacks your local credential setup.
  A successful pgAdmin connection does not supply credentials to Go.
  Run from your configured authenticated shell; do not paste secrets into chat.
- **Permission denied for schema public**: the database owner must grant the
  migration role CREATE on the shannon_dev public schema, or own that schema.
  Do not grant superuser privileges.
- **Connection refused**: verify PostgreSQL service, port 5432, API console,
  and `Get-NetTCPConnection -LocalPort 8080`.
- **Android unavailable**: start the emulator and wait for flutter devices.
- **Android network failure**: emulator uses 10.0.2.2, USB uses adb reverse.
  HTTP is allowed only for these local hosts in debug builds. Release requires HTTPS.
- **Port busy**: stop the previous API with Ctrl+C or set HTTP_ADDR and matching
  API_BASE_URL when running Go directly.
- **Dependencies/build fail**: run flutter doctor -v; check JDK/SDK and network.
- **NDK package not found by sdkmanager**: the installed compatibility wrapper
  can split the legacy package name. With the current Android CLI, use:

  ```powershell
  & "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\android.exe" --no-metrics sdk install 'ndk/28.2.13676358'
  ```

- **PowerShell policy blocks scripts**: follow your organization's policy;
  the equivalent manual backend commands are below.

```powershell
Set-Location 'C:\Users\Erik\OneDrive\Desktop\Shannon\services\api'
$env:PGHOST='localhost'
$env:PGPORT='5432'
$env:PGDATABASE='shannon_dev'
$env:PGUSER='shannon_app'
$env:PGSSLMODE='disable'
go run ./cmd/migrate
go run ./cmd/api
```

See docs/PROGRESS.md for actual results and remaining validation.
