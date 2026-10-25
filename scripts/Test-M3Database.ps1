param([string]$AndroidDevice = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$pg = 'C:\Program Files\PostgreSQL\17\bin'
$testRoot = Join-Path $repo '.local-test'
$cluster = Join-Path $testRoot ('pg-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $cluster | Out-Null
$passwordFile = Join-Path $cluster 'password.tmp'
$bytes = New-Object byte[] 32
$random = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $random.GetBytes($bytes) } finally { $random.Dispose() }
$password = [Convert]::ToBase64String($bytes)
[IO.File]::WriteAllText($passwordFile, $password)
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$names = @('DATABASE_URL','PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGSSLMODE','SHANNON_INTEGRATION','SHANNON_ALLOW_INSECURE_LOCAL_AUTH','SHANNON_AUTH_AUDIENCE','HTTP_ADDR','TLS_CERT_FILE','TLS_KEY_FILE','SHANNON_VALIDATION_APP')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
$started = $false
$apiProcess = $null
$forwardPort = $null
try {
    & "$pg\initdb.exe" -D "$cluster\data" -U shannon_test --auth=scram-sha-256 --pwfile=$passwordFile --encoding=UTF8 --locale=C | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Temporary PostgreSQL initialization failed' }
    Remove-Item -LiteralPath $passwordFile
    $startArguments = @('-D', ('"' + $cluster + '\data"'), '-l', ('"' + $cluster + '\postgres.log"'), '-o', ('"-h 127.0.0.1 -p ' + $port + '"'), '-w', 'start')
    $starter = Start-Process -FilePath "$pg\pg_ctl.exe" -ArgumentList $startArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$cluster/start.log" -RedirectStandardError "$cluster/start-error.log"
    $starter.WaitForExit()
    if ($starter.ExitCode -ne 0) { throw 'Temporary PostgreSQL startup failed' }
    $started = $true
    $env:DATABASE_URL = ''
    $env:PGHOST = '127.0.0.1'
    $env:PGPORT = [string]$port
    $env:PGDATABASE = 'postgres'
    $env:PGUSER = 'shannon_test'
    $env:PGPASSWORD = $password
    $env:PGSSLMODE = 'disable'
    $env:SHANNON_INTEGRATION = '1'
    $env:SHANNON_AUTH_AUDIENCE = 'shannon.local'
    $env:TLS_CERT_FILE = ''
    $env:TLS_KEY_FILE = ''
    Push-Location "$repo/services/api"
    try {
        go test -count=1 ./...
        if ($LASTEXITCODE -ne 0) { throw 'Database-backed Go tests failed' }
        go vet ./...
        if ($LASTEXITCODE -ne 0) { throw 'Go vet failed' }
        if ($AndroidDevice) {
            go run ./cmd/migrate
            if ($LASTEXITCODE -ne 0) { throw 'Migrations failed' }
            $binary = Join-Path $cluster 'api.exe'
            go build -o $binary ./cmd/api
            if ($LASTEXITCODE -ne 0) { throw 'API build failed' }
            $env:HTTP_ADDR = '127.0.0.1:18080'
            $env:SHANNON_ALLOW_INSECURE_LOCAL_AUTH = '1'
            $apiProcess = Start-Process -FilePath $binary -WindowStyle Hidden -PassThru -RedirectStandardOutput "$cluster/api.log" -RedirectStandardError "$cluster/api-error.log"
        }
    } finally { Pop-Location }
    if ($AndroidDevice) {
        $adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
        & $adb -s $AndroidDevice reverse tcp:18080 tcp:18080
        if ($LASTEXITCODE -ne 0) { throw 'adb reverse failed' }
        $ready = $false
        for ($i=0; $i -lt 20; $i++) {
            if ($apiProcess.HasExited) { throw 'Temporary API exited before readiness; check for a port conflict' }
            try { $health = Invoke-RestMethod http://127.0.0.1:18080/health -TimeoutSec 3; $ready = $health.database -eq 'up'; if ($ready) { break } } catch { Start-Sleep -Milliseconds 250 }
        }
        if (-not $ready) { throw 'Test API did not become ready' }
        Push-Location "$repo/apps/mobile"
        try {
            # Never let flutter test's installer uninstall the user's app.
            # Build a separate application ID, install additively, then attach.
            $env:SHANNON_VALIDATION_APP = '1'
            flutter build apk --debug -t integration_test/identity_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:18080
            if ($LASTEXITCODE -ne 0) { throw 'Validation APK build failed' }
            $aapt = Get-ChildItem "$env:LOCALAPPDATA/Android/Sdk/build-tools/*/aapt2.exe" | Sort-Object FullName -Descending | Select-Object -First 1
            if (-not $aapt) { throw 'Cannot verify validation APK application ID' }
            $badging = (& $aapt.FullName dump badging build/app/outputs/flutter-apk/app-debug.apk) -join "`n"
            if ($LASTEXITCODE -ne 0 -or $badging -notmatch "(?m)^package: name='dev\.shannon\.shannon\.validation'") {
                throw 'Refusing to install an APK without the isolated validation application ID'
            }
            & $adb -s $AndroidDevice install -r build/app/outputs/flutter-apk/app-debug.apk
            if ($LASTEXITCODE -ne 0) { throw 'Validation APK installation failed; no uninstall attempted' }
            & $adb -s $AndroidDevice shell am start -W -n dev.shannon.shannon.validation/dev.shannon.shannon.MainActivity | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Validation app launch failed' }
            $serviceUri = $null
            for ($i=0; $i -lt 40; $i++) {
                $appPid = ((& $adb -s $AndroidDevice shell pidof dev.shannon.shannon.validation) -join '') -replace '\s',''
                if ($appPid) {
                    $log = (& $adb -s $AndroidDevice logcat --pid=$appPid -d -s flutter:I) -join "`n"
                    if ($log -match 'http://127\.0\.0\.1:(\d+)/([A-Za-z0-9=_-]+/)') {
                        $remotePort = $Matches[1]
                        $servicePath = $Matches[2]
                        $forwardPort = (& $adb -s $AndroidDevice forward tcp:0 tcp:$remotePort).Trim()
                        $serviceUri = "http://127.0.0.1:$forwardPort/$servicePath"
                        break
                    }
                }
                Start-Sleep -Milliseconds 500
            }
            if (-not $serviceUri) { throw 'Validation app VM service was not available' }
            flutter drive --driver=test_driver/integration_driver.dart --use-existing-app=$serviceUri -d $AndroidDevice --no-pub
            if ($LASTEXITCODE -ne 0) { throw 'Android identity integration failed' }
        } finally { Pop-Location }
    }
} finally {
    if ($apiProcess -and -not $apiProcess.HasExited) { Stop-Process -Id $apiProcess.Id }
    if ($forwardPort) { & $adb -s $AndroidDevice forward --remove tcp:$forwardPort | Out-Null }
    if ($AndroidDevice) { & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s $AndroidDevice reverse --remove tcp:18080 | Out-Null }
    if ($started) { & "$pg\pg_ctl.exe" -D "$cluster\data" -m fast -w stop | Out-Null }
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    # Remove only the unique test directory beneath this repository's test root.
    $resolved = [IO.Path]::GetFullPath($cluster)
    $allowed = [IO.Path]::GetFullPath($testRoot) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
