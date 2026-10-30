# Flutter target-specific stamps can outlive assets in the shared Android output
# after switching entrypoints/defines. Invalidate only copy/build metadata, never
# source, retained APKs, application stores or protocol state.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$cache = [IO.Path]::GetFullPath((Join-Path $repo 'apps/mobile/.dart_tool/flutter_build'))
if (Test-Path -LiteralPath $cache) {
    $allowed = $cache + [IO.Path]::DirectorySeparatorChar
    foreach ($stamp in Get-ChildItem -LiteralPath $cache -Recurse -File -Filter 'debug_android_application.stamp') {
        if (-not $stamp.FullName.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unexpected Flutter asset cache path'
        }
        Remove-Item -LiteralPath $stamp.FullName
    }
}
