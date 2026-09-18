[CmdletBinding()]
param(
    [string]$AswPath,
    [string]$P2BinPath
)

$ErrorActionPreference = 'Stop'

$toolRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$vmRoot = Join-Path $repoRoot 'src\vm\Lynxz80'
$buildDir = Join-Path $vmRoot 'build'
$stage = Join-Path $buildDir 'subcpu'
$romOut = Join-Path $buildDir 'SUBCPU.ROM'
$toolBinDir = Join-Path $toolRoot 'bin'
$toolBinRom = Join-Path $toolBinDir 'SUBCPU.ROM'

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

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
New-Item -ItemType Directory -Force -Path $stage | Out-Null
New-Item -ItemType Directory -Force -Path $toolBinDir | Out-Null

$stageSource = Join-Path $stage 'subcpurom.asm'
if(!(Test-Path -LiteralPath $stageSource -PathType Leaf)) {
    throw "Build source not found: $stageSource"
}

Push-Location $stage
try {
    & $asw '-cpu' 'z80' '-L' (Split-Path -Leaf $stageSource)
    if($LASTEXITCODE -ne 0) {
        throw "ASW SUB CPU ROM assembly failed with exit code $LASTEXITCODE"
    }

    $object = Join-Path $stage 'subcpurom.p'
    $listing = Join-Path $stage 'subcpurom.lst'
    $romBin = Join-Path $stage 'subcpu.bin'

    & $p2bin (Split-Path -Leaf $object) (Split-Path -Leaf $romBin) '-r' '0x0000-0x1fff' '-l' '0xff'
    if($LASTEXITCODE -ne 0) {
        throw "p2bin SUB CPU conversion failed with exit code $LASTEXITCODE"
    }

    $romBytes = [System.IO.File]::ReadAllBytes($romBin)
    if($romBytes.Length -ne 8192) {
        throw "Unexpected SUB CPU ROM size: $($romBytes.Length) bytes"
    }

    [System.IO.File]::WriteAllBytes($romOut, $romBytes)
    [System.IO.File]::WriteAllBytes($toolBinRom, $romBytes)

    $expectedHash = (Get-FileHash -LiteralPath $romOut -Algorithm SHA256).Hash
    $toolHash = (Get-FileHash -LiteralPath $toolBinRom -Algorithm SHA256).Hash
    if($toolHash -ne $expectedHash) {
        throw "SUB CPU ROM copy verification failed: $toolBinRom"
    }

    Get-ChildItem -Path $stage -Filter *.p -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host "Generated $romOut ($($romBytes.Length) bytes)"
    Write-Host "Mirrored  $toolBinRom"
    Write-Host "SHA-256   $expectedHash"
    Write-Host "Listing   $listing"
    Write-Host "ASW       $asw"
    Write-Host "p2bin     $p2bin"
}
finally {
    Pop-Location
}
