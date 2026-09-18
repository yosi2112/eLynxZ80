[CmdletBinding()]
param(
    [switch]$diag,
    [ValidateSet('Debug', 'Release', 'Both')]
    [string]$Target = 'Release',
    [ValidateSet('x86', 'x64')]
    [string]$Platform = 'x86',
    [switch]$RequireFont
)

$ErrorActionPreference = 'Stop'

$toolRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$vmBuildDir = Join-Path $repoRoot 'src\vm\Lynxz80\build'
$toolBinDir = Join-Path $toolRoot 'bin'
$fontBuildDir = Join-Path $toolRoot 'build\font'
$emulatorBinRoot = Join-Path $repoRoot "vc++2017\bin\$Platform"

function Find-RomSource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string[]]$Directories,
        [switch]$Optional
    )

    foreach($directory in $Directories) {
        $candidate = Join-Path $directory $Name
        if(Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    if($Optional) {
        return $null
    }

    throw "ROM source not found: $Name`nSearched:`n  $($Directories -join "`n  ")"
}

function Copy-RomPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,
        [string]$DestinationName = (Split-Path -Leaf $Source)
    )

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    $destination = Join-Path $DestinationDir $DestinationName
    Copy-Item -LiteralPath $Source -Destination $destination -Force

    $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if($sourceHash -ne $destinationHash) {
        throw "ROM copy verification failed: $destination"
    }

    Write-Host "Copied $Source -> $destination"
}

function Get-DestinationDir {
    param([string]$Configuration)
    return Join-Path $emulatorBinRoot $Configuration
}

if($diag) {
    $debugDir = Get-DestinationDir 'Debug'
    $diagMain = Find-RomSource -Name 'DIAGMAIN.ROM' -Directories @($vmBuildDir)
    $diagSub = Find-RomSource -Name 'DIAGSUB.ROM' -Directories @($vmBuildDir)
    Copy-RomPath -Source $diagMain -DestinationDir $debugDir -DestinationName 'IPL.ROM'
    Copy-RomPath -Source $diagSub -DestinationDir $debugDir -DestinationName 'SUBCPU.ROM'
    Write-Host "Installed diagnostic ROMs to $Platform Debug."
    return
}

$ipl = Find-RomSource -Name 'IPL.ROM' -Directories @($toolBinDir, $vmBuildDir)
$sub = Find-RomSource -Name 'SUBCPU.ROM' -Directories @($toolBinDir, $vmBuildDir)
$font = Find-RomSource -Name 'FONT.ROM' -Directories @($fontBuildDir, $toolBinDir, $vmBuildDir) -Optional

if($RequireFont -and $null -eq $font) {
    throw 'FONT.ROM was not found. Run build_fontrom.ps1 first or omit -RequireFont.'
}
if($null -eq $font) {
    Write-Warning 'FONT.ROM was not found. IPL.ROM and SUBCPU.ROM will still be copied.'
}

$configurations = if($Target -eq 'Both') { @('Debug', 'Release') } else { @($Target) }
foreach($configuration in $configurations) {
    $destinationDir = Get-DestinationDir $configuration
    Copy-RomPath -Source $ipl -DestinationDir $destinationDir -DestinationName 'IPL.ROM'
    Copy-RomPath -Source $sub -DestinationDir $destinationDir -DestinationName 'SUBCPU.ROM'
    if($null -ne $font) {
        Copy-RomPath -Source $font -DestinationDir $destinationDir -DestinationName 'FONT.ROM'
    }
}
