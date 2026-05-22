$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$root = Join-Path $repoRoot 'src\vm\Lynxz80'
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'
$buildDir = Join-Path $root 'build'
$outDir = $buildDir
$stage = Join-Path $buildDir 'bios'
$romOut = Join-Path $outDir 'IPL.ROM'
$runtimeOffset = 0x1000
$runtimeWindow = 0x1000

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool)) {
        throw "Required tool not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$stageRomSource = Join-Path $stage 'biosrom.asm'
$stageRuntimeSource = Join-Path $stage 'cpm22bios_runtime.asm'

foreach($source in @($stageRomSource, $stageRuntimeSource)) {
    if(!(Test-Path -LiteralPath $source)) {
        throw "Build source not found: $source"
    }
}

Push-Location $stage
try {
    & $asw '-cpu' 'z80' '-L' $stageRomSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW ROM assembly failed with exit code $LASTEXITCODE"
    }

    & $asw '-cpu' 'z80' '-L' $stageRuntimeSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW runtime BIOS assembly failed with exit code $LASTEXITCODE"
    }

    $romObject = Join-Path $stage 'biosrom.p'
    $romListing = Join-Path $stage 'biosrom.lst'
    $runtimeObject = Join-Path $stage 'cpm22bios_runtime.p'
    $runtimeListing = Join-Path $stage 'cpm22bios_runtime.lst'
    $stageRomBin = Join-Path $stage 'biosrom.bin'
    $stageRuntimeBin = Join-Path $stage 'cpm22bios_runtime.bin'

    & $p2bin $romObject $stageRomBin '-r' '0x0000-0x1fff' '-l' '0xff'
    if($LASTEXITCODE -ne 0) {
        throw "p2bin ROM conversion failed with exit code $LASTEXITCODE"
    }

    & $p2bin $runtimeObject $stageRuntimeBin
    if($LASTEXITCODE -ne 0) {
        throw "p2bin runtime conversion failed with exit code $LASTEXITCODE"
    }

    $romBytes = [System.IO.File]::ReadAllBytes($stageRomBin)
    $runtimeBytes = [System.IO.File]::ReadAllBytes($stageRuntimeBin)

    if($romBytes.Length -ne 8192) {
        throw "Unexpected ROM size before overlay: $($romBytes.Length) bytes"
    }
    if($runtimeBytes.Length -gt $runtimeWindow) {
        throw "Runtime BIOS is too large: $($runtimeBytes.Length) bytes"
    }

    [Array]::Copy($runtimeBytes, 0, $romBytes, $runtimeOffset, $runtimeBytes.Length)
    [System.IO.File]::WriteAllBytes($romOut, $romBytes)

    Remove-Item -LiteralPath $romObject -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $runtimeObject -Force -ErrorAction SilentlyContinue

    Write-Host "Generated $romOut ($($romBytes.Length) bytes)"
    Write-Host "ROM listing      $romListing"
    Write-Host "Runtime listing  $runtimeListing"
    Write-Host "Stage directory  $stage"
    Get-ChildItem -Path $stage -Filter *.p -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}
finally {
    Pop-Location
}
