$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$asw = 'E:\aswcurr\bin\asw.exe'
$p2bin = 'E:\aswcurr\bin\p2bin.exe'
$source = Join-Path $root 'build\cpm22_runtime\CPM22.ASM'
$romBiosSource = Join-Path $root 'build\bios\bios.asm'
$outDir = Join-Path $root 'bin'
$stage = Join-Path $root 'build\cpm22_runtime'
$runtimeOut = Join-Path $outDir 'CPM22_RUNTIME.BIN'
$runtimeImageSize = 8192
$residentBiosWorkBase = 0xF900

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool -PathType Leaf)) {
        throw "Required tool not found: $tool"
    }
}
if(!(Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Z80 CP/M source not found: $source"
}
if(!(Test-Path -LiteralPath $romBiosSource -PathType Leaf)) {
    throw "IPL BIOS source not found: $romBiosSource"
}

function New-ResidentBiosSource {
    param(
        [string]$SourcePath,
        [int]$BootAddress,
        [int]$CbaseAddress
    )

    $lines = Get-Content -LiteralPath $SourcePath
    $orgIndex = -1
    for($i = 0; $i -lt $lines.Count; $i++) {
        if($lines[$i] -match '^\s*ORG\s+0000H\b') {
            $orgIndex = $i
            break
        }
    }
    if($orgIndex -lt 0) {
        throw "ORG 0000H not found in $SourcePath"
    }

    $bodyStart = -1
    $bodyEnd = -1
    for($i = 0; $i -lt $lines.Count; $i++) {
        if($lines[$i] -match '^BIOS_BOOT:') {
            $bodyStart = $i
        }
        if($lines[$i] -match '^OPENING_MESSAGE:') {
            $bodyEnd = $i
            break
        }
    }
    if($bodyStart -lt 0 -or $bodyEnd -lt 0 -or $bodyEnd -le $bodyStart) {
        throw "BIOS body range not found in $SourcePath"
    }

    $constants = ($lines[0..($orgIndex - 1)] -join [Environment]::NewLine)
    $body = ($lines[$bodyStart..($bodyEnd - 1)] -join [Environment]::NewLine)

    $origin = ('0{0:X4}H' -f $BootAddress)
    $jumpTable = @"
        ORG     $origin

BOOT:
        JP      BIOS_BOOT
WBOOT:
        JP      BIOS_WBOOT
CONST:
        JP      BIOS_CONST
CONIN:
        JP      BIOS_CONIN
CONOUT:
        JP      BIOS_CONOUT
LIST:
        JP      BIOS_LIST
PUNCH:
        JP      BIOS_PUNCH
READER:
        JP      BIOS_READER
HOME:
        JP      BIOS_HOME
SELDSK:
        JP      BIOS_SELDSK
SETTRK:
        JP      BIOS_SETTRK
SETSEC:
        JP      BIOS_SETSEC
SETDMA:
        JP      BIOS_SETDMA
READ:
        JP      BIOS_READ
WRITE:
        JP      BIOS_WRITE
PRSTAT:
        JP      BIOS_PRSTAT
SECTRN:
        JP      BIOS_SECTRN

"@

    $runtimeConstants = ("CPM_CBASE_ADDR     EQU     0{0:X4}H" -f $CbaseAddress)
    return ($constants + [Environment]::NewLine + $runtimeConstants + [Environment]::NewLine + $jumpTable + $body + [Environment]::NewLine + "RESIDENT_BIOS_END:" + [Environment]::NewLine)
}

function Get-SymbolAddress {
    param(
        [string]$ListingPath,
        [string]$SymbolName
    )

    $text = Get-Content -LiteralPath $ListingPath -Raw
    $pattern = '(?im)\b' + [regex]::Escape($SymbolName.ToUpperInvariant()) + '\s*:\s*([0-9A-F]+)\s+\S+(?=\s|\|)'
    $match = [regex]::Match($text, $pattern)
    if(!$match.Success) {
        throw "Symbol not found in $ListingPath : $SymbolName"
    }
    return [Convert]::ToInt32($match.Groups[1].Value, 16)
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$stageSource = Join-Path $stage 'CPM22.ASM'
if((Resolve-Path -LiteralPath $source).Path -ne (Resolve-Path -LiteralPath $stageSource -ErrorAction SilentlyContinue).Path) {
    Copy-Item -LiteralPath $source -Destination $stageSource -Force
}
Push-Location $stage
try {
    & $asw '-cpu' 'z80' '-L' $stageSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW CP/M assembly failed with exit code $LASTEXITCODE"
    }

    $object = Join-Path $stage 'CPM22.p'
    $listing = Join-Path $stage 'CPM22.lst'
    $stageBin = Join-Path $stage 'CPM22.bin'

    Remove-Item -LiteralPath $stageBin -Force -ErrorAction SilentlyContinue
    & $p2bin $object $stageBin
    if($LASTEXITCODE -ne 0) {
        throw "p2bin CP/M conversion failed with exit code $LASTEXITCODE"
    }

    $cbase = Get-SymbolAddress -ListingPath $listing -SymbolName 'CBASE'
    $fbase = Get-SymbolAddress -ListingPath $listing -SymbolName 'FBASE'
    $fbase1 = Get-SymbolAddress -ListingPath $listing -SymbolName 'FBASE1'
    $boot = Get-SymbolAddress -ListingPath $listing -SymbolName 'BOOT'
    $wboot = Get-SymbolAddress -ListingPath $listing -SymbolName 'WBOOT'
    $coldBoot = Get-SymbolAddress -ListingPath $listing -SymbolName 'COLD_BOOT'
    $coldBootEnd = Get-SymbolAddress -ListingPath $listing -SymbolName 'COLD_BOOT_AREA_END'
    $biosPatchSource = Join-Path $stage '__resident_bios_patch.asm'
    $biosPatchBin = Join-Path $stage '__resident_bios_patch.bin'
    $biosPatchObject = Join-Path $stage '__resident_bios_patch.p'
    $biosPatchListing = Join-Path $stage '__resident_bios_patch.lst'

    Set-Content -LiteralPath $biosPatchSource -Value (New-ResidentBiosSource -SourcePath $romBiosSource -BootAddress $boot -CbaseAddress $cbase) -Encoding ASCII
    & $asw '-cpu' 'z80' '-D' 'RESIDENT_BIOS' '-L' $biosPatchSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW resident BIOS patch assembly failed with exit code $LASTEXITCODE"
    }
    Remove-Item -LiteralPath $biosPatchBin -Force -ErrorAction SilentlyContinue
    & $p2bin $biosPatchObject $biosPatchBin
    if($LASTEXITCODE -ne 0) {
        throw "p2bin resident BIOS patch conversion failed with exit code $LASTEXITCODE"
    }
    $biosEnd = Get-SymbolAddress -ListingPath $biosPatchListing -SymbolName 'RESIDENT_BIOS_END'
    $assembledResidentWorkBase = Get-SymbolAddress -ListingPath $biosPatchListing -SymbolName 'BOOT_VARS_BASE'
    $dirbuf = Get-SymbolAddress -ListingPath $biosPatchListing -SymbolName 'DIRBUF'
    $residentWorkEnd = $dirbuf + 128
    if($assembledResidentWorkBase -ne $residentBiosWorkBase) {
        throw ("Resident BIOS work base mismatch: source={0:X4} expected={1:X4}" -f $assembledResidentWorkBase,$residentBiosWorkBase)
    }
    if($coldBoot -lt $biosEnd -or $coldBootEnd -gt $residentBiosWorkBase) {
        throw ("Cold-boot sign-on overlaps resident BIOS memory: biosEnd={0:X4} cold={1:X4}-{2:X4} workBase={3:X4}" -f $biosEnd,$coldBoot,$coldBootEnd,$residentBiosWorkBase)
    }

    $bytes = [System.IO.File]::ReadAllBytes($stageBin)
    $biosPatchBytes = [System.IO.File]::ReadAllBytes($biosPatchBin)
    $baseRuntimeSize = $boot - $cbase
    if($baseRuntimeSize -le 0) {
        throw ("Invalid BDOS+CCP range: CBASE={0:X4} BOOT={1:X4}" -f $cbase,$boot)
    }
    if($baseRuntimeSize -gt $bytes.Length) {
        throw ("BDOS+CCP range exceeds assembled binary: runtime={0} binary={1}" -f $baseRuntimeSize,$bytes.Length)
    }

    $runtimeBytes = New-Object byte[] $runtimeImageSize
    for($i = 0; $i -lt $runtimeBytes.Length; $i++) {
        $runtimeBytes[$i] = 0
    }
    [Array]::Copy($bytes, 0, $runtimeBytes, 0, [Math]::Min($bytes.Length, $runtimeBytes.Length))

    $biosPatchOffset = $boot - $cbase
    if(($biosPatchOffset + $biosPatchBytes.Length) -gt $runtimeBytes.Length) {
        throw "Resident BIOS patch exceeds runtime image"
    }
    if($residentBiosWorkBase -lt $biosEnd -or $residentWorkEnd -gt 0xFC00) {
        throw ("Resident BIOS workspace overlaps code or leaves the reserved BIOS area: base={0:X4} end={1:X4} biosEnd={2:X4}" -f $residentBiosWorkBase,$residentWorkEnd,$biosEnd)
    }
    [Array]::Copy($biosPatchBytes, 0, $runtimeBytes, $biosPatchOffset, $biosPatchBytes.Length)
    [System.IO.File]::WriteAllBytes($runtimeOut, $runtimeBytes)

    Write-Host "Generated $runtimeOut ($($runtimeBytes.Length) bytes)"
    Write-Host ("Runtime load    CBASE={0:X4} size={1} FBASE={2:X4} FBASE1={3:X4}" -f $cbase,$runtimeBytes.Length,$fbase,$fbase1)
    Write-Host ("Patched BIOS    BOOT={0:X4} WBOOT={1:X4} end={2:X4} size={3}" -f $boot,$wboot,$biosEnd,$biosPatchBytes.Length)
    Write-Host ("Cold sign-on    base={0:X4} end={1:X4}" -f $coldBoot,$coldBootEnd)
    Write-Host ("BIOS workspace  base={0:X4} end={1:X4}" -f $residentBiosWorkBase,$residentWorkEnd)
    Write-Host "Source          $source"
    Write-Host "Listing         $listing"
    Write-Host "Stage directory $stage"

    Remove-Item -LiteralPath $object -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $biosPatchSource,$biosPatchObject,$biosPatchBin,$biosPatchListing -Force -ErrorAction SilentlyContinue
}
finally {
    Pop-Location
}
