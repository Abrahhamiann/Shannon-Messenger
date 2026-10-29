param([string]$Manifest = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $repo '.local-test'
if (-not $Manifest) { $Manifest = Join-Path $testRoot 'm4-sandbox.json' }
$saved = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$cluster = [IO.Path]::GetFullPath($saved.cluster)
$allowed = [IO.Path]::GetFullPath($testRoot) + [IO.Path]::DirectorySeparatorChar
if (-not $cluster.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path $cluster -Leaf) -notmatch '^pg-[a-f0-9]{32}$') { throw 'Not an isolated M4 cluster' }
$port = [int]$saved.databasePort
if ($port -lt 1024 -or $port -gt 65535 -or $port -eq 5432) { throw 'Unsafe test database port' }
if ([int]$saved.apiPort -ne 18080) { throw 'Not the retained two-device M4 API port' }
$pg = 'C:\Program Files\PostgreSQL\17\bin'
$data = Join-Path $cluster 'data'
if ((Get-Content -LiteralPath "$data/PG_VERSION").Trim() -ne '17') { throw 'Unexpected isolated cluster version' }
$hba = Join-Path $data 'pg_hba.conf'
$backup = Join-Path $cluster 'm4-original-pg_hba.conf'
$names = @('DATABASE_URL','PGHOST','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGSSLMODE','SHANNON_INTEGRATION','SHANNON_ALLOW_INSECURE_LOCAL_AUTH','SHANNON_AUTH_AUDIENCE','SHANNON_M4_TRANSPORT','HTTP_ADDR','TLS_CERT_FILE','TLS_KEY_FILE')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name,'Process') }
$api = $null
$started = $false
$hbaChanged = $false
function Start-TestPostgres {
    $arguments = @('-D',('"'+$data+'"'),'-l',('"'+$cluster+'\postgres.log"'),'-o',('"-h 127.0.0.1 -p '+$port+'"'),'-w','start')
    $starter = Start-Process "$pg/pg_ctl.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$cluster/resume.log" -RedirectStandardError "$cluster/resume-error.log"
    $starter.WaitForExit()
    if ($starter.ExitCode -ne 0) { throw 'Existing isolated PostgreSQL cluster could not resume' }
}
function Start-TestApi {
    Push-Location "$repo/services/api"
    try {
        go run ./cmd/migrate
        if ($LASTEXITCODE -ne 0) { throw 'Additive test migrations failed' }
        go build -o "$cluster/api.exe" ./cmd/api
        if ($LASTEXITCODE -ne 0) { throw 'Test API build failed' }
    } finally { Pop-Location }
    $script:api = Start-Process "$cluster/api.exe" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$cluster/api.log" -RedirectStandardError "$cluster/api-error.log"
    @{cluster=$cluster;apiPid=$api.Id;databasePort=$port;apiPort=18080} | ConvertTo-Json | Set-Content -LiteralPath $Manifest
}
try {
    & "$pg/pg_ctl.exe" -D $data status | Out-Null
    if ($LASTEXITCODE -eq 0) { throw 'Sandbox is already running; resume refused' }
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $hba -Destination $backup }
    # The prior random password existed only in the interrupted process. Keep
    # that credential unchanged. Temporarily allow this test role/database over
    # loopback in this unique cluster only; restore the original HBA on exit.
    $original = [IO.File]::ReadAllText($backup)
    [IO.File]::WriteAllText($hba,"host postgres shannon_test 127.0.0.1/32 trust`n"+$original)
    $hbaChanged = $true
    Start-TestPostgres
    $started = $true
    $env:DATABASE_URL=''; $env:PGHOST='127.0.0.1'; $env:PGPORT=[string]$port
    $env:PGDATABASE='postgres'; $env:PGUSER='shannon_test'; $env:PGPASSWORD=''; $env:PGSSLMODE='disable'
    $env:SHANNON_INTEGRATION='1'; $env:SHANNON_AUTH_AUDIENCE='shannon.local'
    $env:HTTP_ADDR='127.0.0.1:18080'; $env:SHANNON_ALLOW_INSECURE_LOCAL_AUTH='1'; $env:SHANNON_M4_TRANSPORT='1'
    $env:TLS_CERT_FILE=''; $env:TLS_KEY_FILE=''
    Start-TestApi
    Write-Output 'Resumed existing M4 sandbox at 127.0.0.1:18080; accounts and ciphertext retained. Normal database untouched.'
    $control = Join-Path $testRoot 'm4-control.json'
    while (-not $api.HasExited) {
        if (Test-Path -LiteralPath $control) {
            $operation = (Get-Content -LiteralPath $control -Raw | ConvertFrom-Json).operation
            Remove-Item -LiteralPath $control
            switch ($operation) {
                'inspect' {
                    Push-Location "$repo/services/api"
                    try { go run ./cmd/m4-inspect; if($LASTEXITCODE -ne 0){throw 'Test inspection failed'} } finally { Pop-Location }
                }
                'restart-api' { Stop-Process -Id $api.Id; $api.WaitForExit(); Start-TestApi; Write-Output 'Test API restarted; same database retained.' }
                'restart-database' {
                    & "$pg/pg_ctl.exe" -D $data -m fast -w stop | Out-Null
                    if($LASTEXITCODE -ne 0){throw 'Test database stop failed'}
                    Start-TestPostgres
                    Write-Output 'Existing test PostgreSQL cluster restarted; no reset.'
                }
                'stop' { break }
                default { throw 'Unknown sandbox operation' }
            }
            if($operation -eq 'stop'){break}
        }
        Start-Sleep -Seconds 1
    }
} finally {
    if($api -and -not $api.HasExited){Stop-Process -Id $api.Id}
    if($hbaChanged){Copy-Item -LiteralPath $backup -Destination $hba -Force}
    if($started){& "$pg/pg_ctl.exe" -D $data -m fast -w stop | Out-Null}
    foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$previous[$name],'Process')}
    # Deliberately retain the existing test accounts/data for future resumption.
}
