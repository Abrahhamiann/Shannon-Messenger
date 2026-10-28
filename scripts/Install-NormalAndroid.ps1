param([Parameter(Mandatory=$true)][string]$AndroidDevice)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$mobile = Join-Path $repo 'apps/mobile'
$adb = 'C:\Users\Erik\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$savedValidation = $env:SHANNON_VALIDATION_APP
try {
    $env:SHANNON_VALIDATION_APP = $null
    Push-Location $mobile
    try {
        flutter build apk --debug -t lib/main.dart --dart-define=API_BASE_URL=http://127.0.0.1:8080
        if ($LASTEXITCODE -ne 0) { throw 'Normal APK build failed' }
        $aapt = Get-ChildItem 'C:/Users/Erik/AppData/Local/Android/Sdk/build-tools/*/aapt2.exe' | Sort-Object FullName -Descending | Select-Object -First 1
        if (-not $aapt) { throw 'aapt2 is required to verify the package before installation' }
        $apk = Join-Path $mobile 'build/app/outputs/flutter-apk/app-debug.apk'
        $badging = (& $aapt.FullName dump badging $apk) -join "`n"
        if ($LASTEXITCODE -ne 0 -or $badging -notmatch "(?m)^package: name='dev\.shannon\.shannon'") {
            throw 'Refusing to install an APK without the exact normal application ID'
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($apk)
        try {
            $kernel = $archive.GetEntry('assets/flutter_assets/kernel_blob.bin')
            if (-not $kernel) { throw 'Cannot inspect debug APK entry point' }
            $reader = [IO.StreamReader]::new($kernel.Open(), [Text.Encoding]::Latin1)
            try { $code = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if (-not $code.Contains('package:shannon/main.dart') -or
                $code.Contains('IntegrationTestWidgetsFlutterBinding') -or
                $code.Contains('integration_test/identity_test.dart')) {
                throw 'Refusing to install a normal APK containing test-runner code'
            }
        } finally { $archive.Dispose() }
        # Keep a stable normal artifact; validation builds use the Flutter output too.
        $output = Join-Path $mobile 'build/normal/shannon-debug.apk'
        New-Item -ItemType Directory -Force (Split-Path $output -Parent) | Out-Null
        Copy-Item -LiteralPath $apk -Destination $output -Force
        & $adb -s $AndroidDevice reverse tcp:8080 tcp:8080
        if ($LASTEXITCODE -ne 0) { throw 'Device forwarding failed' }
        & $adb -s $AndroidDevice install -r $output
        if ($LASTEXITCODE -ne 0) { throw 'Update failed. No uninstall or data clear was attempted.' }
        & $adb -s $AndroidDevice shell am force-stop dev.shannon.shannon.validation
        & $adb -s $AndroidDevice shell pm disable-user --user 0 dev.shannon.shannon.validation
        & $adb -s $AndroidDevice shell am force-stop dev.shannon.shannon
        & $adb -s $AndroidDevice shell am start -W -n dev.shannon.shannon/dev.shannon.shannon.MainActivity
        if ($LASTEXITCODE -ne 0) { throw 'Normal app launch failed' }
        Get-FileHash -LiteralPath $output -Algorithm SHA256
    } finally { Pop-Location }
} finally { $env:SHANNON_VALIDATION_APP = $savedValidation }
