[CmdletBinding()]
param(
    [string]$AswPath,
    [string]$P2BinPath,
    [string]$EmulatorBinRoot,
    [switch]$SkipBackup,
    [switch]$NoDeploy
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $root '..\..')).Path
$stage = Join-Path $root 'build\bios'
$source = Join-Path $stage 'bios.asm'
$object = Join-Path $stage 'bios.p'
$builtRom = Join-Path $stage 'bios.bin'
$binRom = Join-Path $root 'bin\IPL.ROM'
$vmBuildDir = Join-Path $repoRoot 'src\vm\Lynxz80\build'
$vmRom = Join-Path $vmBuildDir 'IPL.ROM'

if([string]::IsNullOrWhiteSpace($EmulatorBinRoot)) {
    $EmulatorBinRoot = Join-Path $repoRoot 'vc++2017\bin'
}

function Resolve-Executable {
    param(
        [string]$ExplicitPath,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if(-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if(Test-Path -LiteralPath $ExplicitPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $ExplicitPath).Path
        }
        $explicitCommand = Get-Command -Name $ExplicitPath -CommandType Application -ErrorAction SilentlyContinue
        if($null -ne $explicitCommand) {
            return $explicitCommand.Source
        }
        throw "Required tool not found: $ExplicitPath"
    }

    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue
    if($null -eq $command) {
        throw "Required tool not found in PATH: $Name"
    }
    return $command.Source
}

$asw = Resolve-Executable -ExplicitPath $AswPath -Name 'asw.exe'
$p2bin = Resolve-Executable -ExplicitPath $P2BinPath -Name 'p2bin.exe'

if(!(Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Build source not found: $source"
}

New-Item -ItemType Directory -Path (Split-Path -Parent $binRom) -Force | Out-Null
New-Item -ItemType Directory -Path $vmBuildDir -Force | Out-Null

$deploymentRoms = @()
if(!$NoDeploy -and (Test-Path -LiteralPath $EmulatorBinRoot -PathType Container)) {
    $deploymentRoms = Get-ChildItem -LiteralPath $EmulatorBinRoot -Recurse -File -Filter 'lynxz80.exe' |
        ForEach-Object { Join-Path $_.DirectoryName 'IPL.ROM' }
} elseif(!$NoDeploy) {
    Write-Warning "Emulator binary root not found; ROM build will continue without executable-directory deployment: $EmulatorBinRoot"
}

$destinations = @($binRom, $vmRom) + @($deploymentRoms)
$destinations = @($destinations | Select-Object -Unique)

if(!$SkipBackup) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupRoot = Join-Path $root "archive\before_ipl_build_$stamp"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

    $index = 0
    foreach($rom in $destinations) {
        if(Test-Path -LiteralPath $rom -PathType Leaf) {
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
    & $asw '-cpu' 'z80' '-L' 'bios.asm'
    if($LASTEXITCODE -ne 0) {
        throw "ASW assembly failed with exit code $LASTEXITCODE"
    }

    & $p2bin 'bios.p' 'bios.bin' '-r' '0x0000-0x1fff' '-l' '0xff'
    if($LASTEXITCODE -ne 0) {
        throw "p2bin conversion failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $object -Force -ErrorAction SilentlyContinue
}

if(!(Test-Path -LiteralPath $builtRom -PathType Leaf)) {
    throw "IPL ROM was not generated: $builtRom"
}
if((Get-Item -LiteralPath $builtRom).Length -ne 8192) {
    throw "Unexpected IPL.ROM size: $((Get-Item -LiteralPath $builtRom).Length) bytes"
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
Write-Host "ASW: $asw"
Write-Host "p2bin: $p2bin"
Write-Host 'Installed to:'
$destinations | ForEach-Object { Write-Host "  $_" }
