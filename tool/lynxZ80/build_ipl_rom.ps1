[CmdletBinding()]
param(
    [string]$AswPath = 'E:\aswcurr\bin\asw.exe',
    [string]$P2BinPath = 'E:\aswcurr\bin\p2bin.exe',
    [string]$EmulatorBinRoot = 'E:\source\vc++2017\bin',
    [switch]$SkipBackup
)

# Build the clock-optimized IPL source, verify it, then deploy it beside every
# lynxz80.exe below $EmulatorBinRoot.  Existing IPL.ROM files are archived first.
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$stage = Join-Path $root 'build\bios'
$source = Join-Path $stage 'bios.asm'
$object = Join-Path $stage 'bios.p'
$builtRom = Join-Path $stage 'bios.bin'
$binRom = Join-Path $root 'bin\IPL.ROM'

foreach($path in @($AswPath, $P2BinPath, $source)) {
    if(!(Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
}

if(!$SkipBackup) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupRoot = Join-Path $root "archive\before_ipl_build_$stamp"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $existingRoms = @($binRom)
    if(Test-Path -LiteralPath $EmulatorBinRoot) {
        $existingRoms += Get-ChildItem -LiteralPath $EmulatorBinRoot -Recurse -File -Filter 'lynxz80.exe' |
            ForEach-Object { Join-Path $_.DirectoryName 'IPL.ROM' }
    }

    $index = 0
    foreach($rom in $existingRoms | Select-Object -Unique) {
        if(Test-Path -LiteralPath $rom) {
            $index++
            $destination = Join-Path $backupRoot ("{0:D2}_{1}" -f $index, (Split-Path -Leaf $rom))
            Copy-Item -LiteralPath $rom -Destination $destination -Force
            $hash = (Get-FileHash -LiteralPath $rom -Algorithm SHA256).Hash
            "{0}`t{1}`t{2}" -f $rom, $hash, (Get-Item -LiteralPath $rom).Length |
                Add-Content -LiteralPath (Join-Path $backupRoot 'manifest.tsv') -Encoding utf8
        }
    }
}

Push-Location $stage
try {
    & $AswPath '-cpu' 'z80' '-L' 'bios.asm'
    if($LASTEXITCODE -ne 0) {
        throw "ASW assembly failed with exit code $LASTEXITCODE"
    }

    & $P2BinPath 'bios.p' 'bios.bin' '-r' '0x0000-0x1fff' '-l' '0xff'
    if($LASTEXITCODE -ne 0) {
        throw "p2bin conversion failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $object -Force -ErrorAction SilentlyContinue
}

if((Get-Item -LiteralPath $builtRom).Length -ne 8192) {
    throw "Unexpected IPL.ROM size: $((Get-Item -LiteralPath $builtRom).Length) bytes"
}

$destinations = @($binRom)
if(!(Test-Path -LiteralPath $EmulatorBinRoot)) {
    throw "Emulator binary root not found: $EmulatorBinRoot"
}
$destinations += Get-ChildItem -LiteralPath $EmulatorBinRoot -Recurse -File -Filter 'lynxz80.exe' |
    ForEach-Object { Join-Path $_.DirectoryName 'IPL.ROM' }
$destinations = $destinations | Select-Object -Unique

if($destinations.Count -lt 2) {
    throw "No lynxz80.exe deployment target found below: $EmulatorBinRoot"
}

foreach($destination in $destinations) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $builtRom -Destination $destination -Force
}

$expectedHash = (Get-FileHash -LiteralPath $builtRom -Algorithm SHA256).Hash
foreach($destination in $destinations) {
    $item = Get-Item -LiteralPath $destination
    $actualHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if($item.Length -ne 8192 -or $actualHash -ne $expectedHash) {
        throw "Deployment verification failed: $destination"
    }
}

Write-Host "Built and verified: $builtRom"
Write-Host "SHA-256: $expectedHash"
Write-Host "Deployed to:"
$destinations | ForEach-Object { Write-Host "  $_" }
