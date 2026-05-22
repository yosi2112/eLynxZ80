$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$root = Join-Path $repoRoot 'src\vm\Lynxz80'
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'
$cpmSource = Join-Path $root 'build\cpm22disk\CPM22_z80.ASM'
$runtimeSource = Join-Path $root 'build\bios\cpm22bios_runtime.asm'
$buildDir = Join-Path $root 'build'
$outDir = $buildDir
$stage = Join-Path $buildDir ("cpm22disk")
$imgOut = Join-Path $outDir 'CPM22_SYSTEM.IMG'

$diskSize = 77 * 26 * 128
$systemAreaSize = 2 * 26 * 128

function Get-SymbolAddress {
    param(
        [string]$ListingPath,
        [string]$SymbolName
    )

    $text = Get-Content -LiteralPath $ListingPath -Raw
    $pattern = '(?im)\b' + [regex]::Escape($SymbolName.ToUpperInvariant()) + '\s*:\s*([0-9A-F]+)\s+C\b'
    $match = [regex]::Match($text, $pattern)
    if(!$match.Success) {
        throw "Symbol not found in $ListingPath : $SymbolName"
    }
    return [Convert]::ToInt32($match.Groups[1].Value, 16)
}

function Set-WordLe {
    param(
        [byte[]]$Buffer,
        [int]$Offset,
        [int]$Value
    )
    $Buffer[$Offset] = [byte]($Value -band 0xff)
    $Buffer[$Offset + 1] = [byte](($Value -shr 8) -band 0xff)
}

function Find-BytePattern {
    param(
        [byte[]]$Buffer,
        [byte[]]$Pattern
    )
    for($i = 0; $i -le $Buffer.Length - $Pattern.Length; $i++) {
        $matched = $true
        for($j = 0; $j -lt $Pattern.Length; $j++) {
            if($Buffer[$i + $j] -ne $Pattern[$j]) {
                $matched = $false
                break
            }
        }
        if($matched) {
            return $i
        }
    }
    return -1
}

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool)) {
        throw "Required tool not found: $tool"
    }
}
foreach($src in @($cpmSource, $runtimeSource)) {
    if(!(Test-Path -LiteralPath $src)) {
        throw "Required source not found: $src"
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$stageCpmSource = Join-Path $stage 'CPM22_z80.ASM'
$stageRuntimeSource = Join-Path $stage 'cpm22bios_runtime.asm'
Copy-Item -LiteralPath $cpmSource -Destination $stageCpmSource
Copy-Item -LiteralPath $runtimeSource -Destination $stageRuntimeSource

Push-Location $stage
try {
    & $asw '-cpu' 'z80' '-L' $stageCpmSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW CP/M assembly failed with exit code $LASTEXITCODE"
    }

    & $asw '-cpu' 'z80' '-L' $stageRuntimeSource
    if($LASTEXITCODE -ne 0) {
        throw "ASW runtime BIOS assembly failed with exit code $LASTEXITCODE"
    }

    $cpmObject = Join-Path $stage 'CPM22_z80.p'
    $cpmListing = Join-Path $stage 'CPM22_z80.lst'
    $cpmBinary = Join-Path $stage 'CPM22_z80.bin'
    $runtimeListing = Join-Path $stage 'cpm22bios_runtime.lst'

    & $p2bin $cpmObject $cpmBinary
    if($LASTEXITCODE -ne 0) {
        throw "p2bin CP/M conversion failed with exit code $LASTEXITCODE"
    }

    $cbase = Get-SymbolAddress -ListingPath $cpmListing -SymbolName 'CBASE'
    $fbase1 = Get-SymbolAddress -ListingPath $cpmListing -SymbolName 'FBASE1'
    $boot = Get-SymbolAddress -ListingPath $cpmListing -SymbolName 'BOOT'
    $wboot = Get-SymbolAddress -ListingPath $cpmListing -SymbolName 'WBOOT'

    $jumpMap = [ordered]@{
        'BOOT'   = 'BIOS_BOOT'
        'WBOOT'  = 'BIOS_WBOOT'
        'CONST'  = 'BIOS_CONST'
        'CONIN'  = 'BIOS_CONIN'
        'CONOUT' = 'BIOS_CONOUT'
        'LIST'   = 'BIOS_LIST'
        'PUNCH'  = 'BIOS_PUNCH'
        'READER' = 'BIOS_READER'
        'HOME'   = 'BIOS_HOME'
        'SELDSK' = 'BIOS_SELDSK'
        'SETTRK' = 'BIOS_SETTRK'
        'SETSEC' = 'BIOS_SETSEC'
        'SETDMA' = 'BIOS_SETDMA'
        'READ'   = 'BIOS_READ'
        'WRITE'  = 'BIOS_WRITE'
        'PRSTAT' = 'BIOS_PRSTAT'
        'SECTRN' = 'BIOS_SECTRN'
    }

    $runtimeAddresses = @{}
    foreach($runtimeLabel in $jumpMap.Values) {
        $runtimeAddresses[$runtimeLabel] = Get-SymbolAddress -ListingPath $runtimeListing -SymbolName $runtimeLabel
    }

    $cpmBytes = [System.IO.File]::ReadAllBytes($cpmBinary)

    $memK = [int](($cbase / 1024) + 7)
    $tpaStart = 0x0100
    $tpaEnd = $cbase - 1
    $tpaSize = $cbase - $tpaStart
    if($memK -ne 62) {
        throw "Unexpected CP/M MEM derived from CBASE: $memK K"
    }
    if($tpaSize -ne 0xDB00) {
        throw ("Unexpected TPA size derived from CBASE: {0:X4}" -f $tpaSize)
    }

    foreach($entry in $jumpMap.GetEnumerator()) {
        $jumpLabel = $entry.Key
        $runtimeLabel = $entry.Value
        $jumpAddress = Get-SymbolAddress -ListingPath $cpmListing -SymbolName $jumpLabel
        $offset = $jumpAddress - $cbase
        if($offset -lt 0 -or ($offset + 2) -ge $cpmBytes.Length) {
            throw "Jump-table offset out of range for $jumpLabel"
        }
        $target = [int]$runtimeAddresses[$runtimeLabel]
        $cpmBytes[$offset] = 0xC3
        $cpmBytes[$offset + 1] = [byte]($target -band 0xff)
        $cpmBytes[$offset + 2] = [byte](($target -shr 8) -band 0xff)
    }

    $payloadBytes = $cpmBytes.Length
    $requiredSystemBytes = $payloadBytes
    if($requiredSystemBytes -gt $systemAreaSize) {
        throw "CP/M payload does not fit in 2 reserved tracks: $requiredSystemBytes bytes"
    }

    $image = New-Object byte[] $diskSize
    for($i = 0; $i -lt $image.Length; $i++) {
        $image[$i] = 0xE5
    }

    [Array]::Copy($cpmBytes, 0, $image, 0, $payloadBytes)
    [System.IO.File]::WriteAllBytes($imgOut, $image)

    Get-ChildItem -Path $stage -Filter *.p -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

    Write-Host "Generated $imgOut ($($image.Length) bytes)"
    Write-Host ("CP/M payload    load={0:X4} size={1} boot={2:X4} wboot={3:X4} fbase1={4:X4}" -f $cbase,$payloadBytes,$boot,$wboot,$fbase1)
    Write-Host ("CP/M signon     MEM={0}K TPA={1:X4}H ({2:X4}H-{3:X4}H) prompt=upper-case" -f $memK,$tpaSize,$tpaStart,$tpaEnd)
    Write-Host "System area     CP/M starts at track 0 sector 1; no Lynx private boot header"
    Write-Host "CP/M listing     $cpmListing"
    Write-Host "Runtime listing  $runtimeListing"
    Write-Host "Stage directory  $stage"
}
finally {
    Pop-Location
}
