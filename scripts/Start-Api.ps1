$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Set-LocalEnvironment.ps1"
Push-Location "$PSScriptRoot/../services/api"
try {
    go run ./cmd/migrate
    if ($LASTEXITCODE -ne 0) { throw 'Migration failed. Check local PostgreSQL credentials and schema permissions.' }
    go run ./cmd/api
    if ($LASTEXITCODE -ne 0) { throw 'API stopped with an error.' }
} finally { Pop-Location }
