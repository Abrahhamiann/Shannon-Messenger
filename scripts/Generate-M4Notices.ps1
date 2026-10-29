$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$env:RUSTUP_HOME=Join-Path $repo '.local-test/m4-rust/rustup'
$env:CARGO_HOME=Join-Path $repo '.local-test/m4-rust/cargo'
$cargo=Join-Path $env:CARGO_HOME 'bin/cargo.exe'
$metadata=(& $cargo metadata --locked --format-version 1 --filter-platform aarch64-linux-android --manifest-path "$repo/packages/messaging-protocol/Cargo.toml" | ConvertFrom-Json)
if($LASTEXITCODE -ne 0){throw 'Cannot generate native dependency notices'}
$resolved=@{};foreach($node in $metadata.resolve.nodes){$resolved[$node.id]=$true}
$choices=Get-Content "$repo/docs/security/M4_DEPENDENCY_LICENSES.json" -Raw|ConvertFrom-Json
$notices=[Text.StringBuilder]::new()
[void]$notices.AppendLine('Shannon M4 native dependencies. Proprietary Shannon code is separate from the following third-party components.')
foreach($package in $metadata.packages|Where-Object {$_.source -and $resolved.ContainsKey($_.id)}|Sort-Object name){
 $choice=$choices|Where-Object {$_.name -eq $package.name -and $_.version -eq $package.version}|Select-Object -First 1
 if(-not $choice){throw "License choice missing: $($package.name)"}
 [void]$notices.AppendLine("`n--- $($package.name) $($package.version); selected $($choice.selected_license); $($package.repository) ---")
 $folder=Split-Path $package.manifest_path -Parent
 $files=@(Get-ChildItem -LiteralPath $folder -File|Where-Object {$_.Name -match '^(LICENSE|COPYING|COPYRIGHT|NOTICE)'}|Sort-Object Name)
 if($files.Count -eq 0){
  $vcs=Get-Content (Join-Path $folder '.cargo_vcs_info.json') -Raw|ConvertFrom-Json
  if($package.repository -notmatch '^https://github\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)/?$' -or $vcs.git.sha1 -notmatch '^[0-9a-f]{40}$'){throw 'Cannot verify upstream notice provenance'}
  $project=$Matches[1]
  # PowerShell's second regex can replace $Matches; retain the repository explicitly.
  $project=([Uri]$package.repository).AbsolutePath.Trim('/')
  $cache=Join-Path $repo '.local-test/m4-notices';New-Item -ItemType Directory -Force $cache|Out-Null
  foreach($candidate in @('LICENSE-MIT','LICENSE-APACHE','LICENSE')){
   $dest=Join-Path $cache "$($package.name)-$($package.version)-$candidate"
   try{Invoke-WebRequest "https://raw.githubusercontent.com/$project/$($vcs.git.sha1)/$candidate" -OutFile $dest;$files+=Get-Item $dest}catch{continue}
  }
  if($files.Count -eq 0){throw "Upstream license notice unavailable: $($package.name)"}
 }
 foreach($file in $files){[void]$notices.AppendLine($file.Name);[void]$notices.AppendLine([IO.File]::ReadAllText($file.FullName))}
}
$toolchain=Join-Path $env:RUSTUP_HOME 'toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust'
foreach($name in @('COPYRIGHT','LICENSE-APACHE','LICENSE-MIT')){
 $file=Join-Path $toolchain $name
 if(Test-Path $file){[void]$notices.AppendLine("`nRust standard library: $name");[void]$notices.AppendLine([IO.File]::ReadAllText($file))}
}
[IO.File]::WriteAllText("$repo/apps/mobile/assets/licenses/m4-native.txt",$notices.ToString())
Write-Output 'Generated M4 Android third-party notices from the locked dependency sources.'
