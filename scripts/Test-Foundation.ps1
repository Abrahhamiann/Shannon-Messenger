param([switch]$Integration)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Set-LocalEnvironment.ps1"
$previousIntegration = $env:SHANNON_INTEGRATION
Push-Location "$PSScriptRoot/../services/api"
try {
    $env:SHANNON_INTEGRATION = if ($Integration) { '1' } else { '0' }
    go test -count=1 ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go tests failed.' }
    go vet ./...
    if ($LASTEXITCODE -ne 0) { throw 'Go static checks failed.' }
} finally {
    $env:SHANNON_INTEGRATION = $previousIntegration
    Pop-Location
}
Push-Location "$PSScriptRoot/../apps/mobile"
try {
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
} finally { Pop-Location }
