$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$taskRust = Join-Path $repo '.local-test/m4-rust'
$env:RUSTUP_HOME = Join-Path $taskRust 'rustup'
$env:CARGO_HOME = Join-Path $taskRust 'cargo'
$cargo = Join-Path $env:CARGO_HOME 'bin/cargo.exe'
if (-not (Test-Path $cargo)) { throw 'Isolated Rust evaluation toolchain is not installed.' }
Push-Location (Join-Path $repo 'packages/messaging-protocol')
try {
    & $cargo test --locked
    if ($LASTEXITCODE -ne 0) { throw 'M4 upstream protocol evaluation failed; messaging remains unavailable.' }
} finally { Pop-Location }
