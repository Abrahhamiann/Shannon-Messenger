param([string[]]$Targets=@('aarch64-linux-android','x86_64-linux-android'))
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$taskRust=Join-Path $repo '.local-test/m4-rust'
$env:RUSTUP_HOME=Join-Path $taskRust 'rustup'
$env:CARGO_HOME=Join-Path $taskRust 'cargo'
$rustup=Join-Path $env:CARGO_HOME 'bin/rustup.exe'
$cargo=Join-Path $env:CARGO_HOME 'bin/cargo.exe'
$ndk='C:/Users/Erik/AppData/Local/Android/Sdk/ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64'
Push-Location (Join-Path $repo 'packages/messaging-protocol')
try {
 foreach($target in $Targets){
  if($target -notin @('aarch64-linux-android','x86_64-linux-android')){throw 'Unsupported M4 evaluation target'}
  & $rustup target add $target
  if($LASTEXITCODE -ne 0){throw 'Android Rust target installation failed'}
  $linkerName='CARGO_TARGET_'+$target.Replace('-','_').ToUpperInvariant()+'_LINKER'
  $flagName='CARGO_TARGET_'+$target.Replace('-','_').ToUpperInvariant()+'_RUSTFLAGS'
  [Environment]::SetEnvironmentVariable($linkerName,"$ndk/bin/clang.exe",'Process')
  [Environment]::SetEnvironmentVariable($flagName,"-C link-arg=--target=$($target)26 -C link-arg=--sysroot=$ndk/sysroot",'Process')
  & $cargo build --locked --release --target $target
  if($LASTEXITCODE -ne 0){throw "Native protocol build failed: $target"}
  $abi=if($target -eq 'aarch64-linux-android'){'arm64-v8a'}else{'x86_64'}
  $out=Join-Path $repo "apps/mobile/android/app/src/main/jniLibs/$abi"
  New-Item -ItemType Directory -Force $out|Out-Null
  if(Test-Path "target/$target/release/libshannon_messaging_protocol.so"){
   Copy-Item -LiteralPath "target/$target/release/libshannon_messaging_protocol.so" -Destination "$out/libshannon_messaging_protocol.so" -Force
  }else{throw 'Expected Android shared library missing'}
 }
}finally{Pop-Location}
