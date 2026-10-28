param([string]$AndroidDevice = '')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
# Keep credentials in the user's existing PostgreSQL environment/pgpass setup.
# Never print DATABASE_URL or PGPASSWORD.
if(-not $env:PGHOST){$env:PGHOST='127.0.0.1'}
if(-not $env:PGPORT){$env:PGPORT='5432'}
if(-not $env:PGDATABASE){$env:PGDATABASE='shannon_dev'}
if(-not $env:PGUSER){$env:PGUSER='shannon_app'}
$env:HTTP_ADDR='127.0.0.1:8080'
$env:SHANNON_ALLOW_INSECURE_LOCAL_AUTH='1'
if(-not $env:SHANNON_AUTH_AUDIENCE){$env:SHANNON_AUTH_AUDIENCE='shannon.local'}
if($AndroidDevice){
    $adb='C:\Users\Erik\AppData\Local\Android\Sdk\platform-tools\adb.exe'
    & $adb -s $AndroidDevice reverse tcp:8080 tcp:8080
    if($LASTEXITCODE -ne 0){throw 'USB port forwarding failed. Check device authorization.'}
}
Push-Location (Join-Path $repo 'services/api')
try {
    go run ./cmd/migrate
    if($LASTEXITCODE -ne 0){throw 'Migration failed. Check the existing local database configuration; no reset was performed.'}
    Write-Output 'Starting the local development API on 127.0.0.1:8080. Keep this terminal open.'
    go run ./cmd/api
    if($LASTEXITCODE -ne 0){throw 'API stopped with an error.'}
} finally {Pop-Location}
