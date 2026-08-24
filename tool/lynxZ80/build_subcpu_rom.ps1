$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$root = Join-Path $repoRoot 'src\vm\Lynxz80'
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'
$buildDir = Join-Path $root 'build'
$outDir = $buildDir
$stage = Join-Path $buildDir 'subcpu'
$romOut = Join-Path $outDir 'SUBCPU.ROM'

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool)) {
        throw "Required tool not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$stageSource = Join-Path $stage 'subcpurom.asm'
if(!(Test-Path -LiteralPath $stageSource)) {
    throw "Build source not found: $stageSource"
}

Push-Location $stage
try {
    & $asw '-cpu' 'z80' '-L' $stageSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW SUB CPU ROM assembly failed with exit code $LASTEXITCODE"
    }

    $object = Join-Path $stage 'subcpurom.p'
    $listing = Join-Path $stage 'subcpurom.lst'
    $romBin = Join-Path $stage 'subcpu.bin'

    & $p2bin $object $romBin '-r' '0x0000-0x1fff' '-l' '0xff'
    if($LASTEXITCODE -ne 0) {
        throw "p2bin SUB CPU conversion failed with exit code $LASTEXITCODE"
    }

    $romBytes = [System.IO.File]::ReadAllBytes($romBin)
    if($romBytes.Length -ne 8192) {
        throw "Unexpected SUB CPU ROM size: $($romBytes.Length) bytes"
    }
    [System.IO.File]::WriteAllBytes($romOut, $romBytes)

    Get-ChildItem -Path $stage -Filter *.p -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host "Generated $romOut ($($romBytes.Length) bytes)"
    Write-Host "Listing         $listing"
    Write-Host "Stage directory $stage"
}
finally {
    Pop-Location
}
