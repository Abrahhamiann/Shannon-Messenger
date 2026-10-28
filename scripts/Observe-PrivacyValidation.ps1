param([string]$AndroidDevice='emulator-5554')
$ErrorActionPreference='Stop'
$adb=Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$repo=Split-Path $PSScriptRoot -Parent
$output=Join-Path $repo '.local-test\capture-validation'
New-Item -ItemType Directory -Force $output | Out-Null
$deadline=[DateTime]::UtcNow.AddMinutes(8)
$captured=@{}
while([DateTime]::UtcNow -lt $deadline -and $captured.Count -lt 2) {
    $validationPid=((& $adb -s $AndroidDevice shell pidof dev.shannon.shannon.validation) -join '').Trim()
    if($validationPid -match '^\d+$') {
        $logs=(& $adb -s $AndroidDevice logcat --pid=$validationPid -d -t 200) -join "`n"
        foreach($phase in @('SECURE','PUBLIC')) {
            if(-not $captured.ContainsKey($phase) -and $logs.Contains("SHANNON_PRIVACY_TEST_$phase")) {
                $name=$phase.ToLowerInvariant()
                & $adb -s $AndroidDevice shell screencap -p "/sdcard/shannon-test-$name.png"
                & $adb -s $AndroidDevice pull "/sdcard/shannon-test-$name.png" (Join-Path $output "$name.png") | Out-Null
                & $adb -s $AndroidDevice shell screenrecord --time-limit 3 "/sdcard/shannon-test-$name.mp4"
                & $adb -s $AndroidDevice pull "/sdcard/shannon-test-$name.mp4" (Join-Path $output "$name.mp4") | Out-Null
                if($LASTEXITCODE -ne 0){throw 'Capture collection failed'}
                $captured[$phase]=$true
                Write-Output "Collected emulator $name screenshot and recording (synthetic test content only)."
            }
        }
    }
    Start-Sleep -Milliseconds 500
}
if($captured.Count -ne 2){throw 'Timed out waiting for isolated capture test phases'}
