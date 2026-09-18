[CmdletBinding()]
param(
    [string]$RuntimePath,
    [string]$UtilitiesDir,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$outDir = Join-Path $root 'bin'
if([string]::IsNullOrWhiteSpace($RuntimePath)) {
    $RuntimePath = Join-Path $outDir 'CPM22_RUNTIME.BIN'
}
if([string]::IsNullOrWhiteSpace($UtilitiesDir)) {
    $UtilitiesDir = Join-Path $outDir 'cpmutils'
}
if([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $outDir 'CPM22_SYSTEM.2d'
}

$tracks = 40
$sides = 2
$sectorsPerTrack = 16
$sectorSize = 256
$sectorInterleave = 1
$cylinderSize = $sides * $sectorsPerTrack * $sectorSize
$systemAreaSize = 2 * $cylinderSize
$diskSize = $tracks * $cylinderSize

$logicalRecordSize = 128
$blockSize = 2048
$recordsPerBlock = [int]($blockSize / $logicalRecordSize)
$dirEntries = 128
$dirSize = $dirEntries * 32
$dirBlocks = 2
$dataStartBlock = $dirBlocks
$dsm = 151
$maxBlocks = $dsm + 1
$exm = 1
$recordsPerDirectoryEntry = 128 * ($exm + 1)

function ConvertTo-CpmName {
    param([string]$InputName)

    $leaf = [IO.Path]::GetFileName($InputName).ToUpperInvariant()
    $parts = $leaf.Split('.', 2)
    $base = $parts[0]
    $ext = if($parts.Count -gt 1) { $parts[1] } else { '' }
    if($base.Length -lt 1 -or $base.Length -gt 8 -or $ext.Length -gt 3) {
        throw "Invalid CP/M 8.3 file name: $InputName"
    }
    if(($base + $ext) -notmatch '^[A-Z0-9_$#@!%&''(){}^~-]+$') {
        throw "Unsupported CP/M file name characters: $InputName"
    }

    return [pscustomobject]@{
        Base = $base.PadRight(8, ' ')
        Ext = $ext.PadRight(3, ' ')
        Display = if($ext.Length -gt 0) { "$base.$ext" } else { $base }
    }
}

function Get-BlockOffset {
    param([int]$Block)

    if($Block -lt 0 -or $Block -ge $maxBlocks) {
        throw "Block out of range: $Block"
    }
    return $systemAreaSize + ($Block * $blockSize)
}

function Write-DirectoryEntry {
    param(
        [byte[]]$Image,
        [int]$DirectoryIndex,
        [object]$CpmName,
        [int]$ExtentGroup,
        [int]$RecordCount,
        [int[]]$Blocks
    )

    if($DirectoryIndex -lt 0 -or $DirectoryIndex -ge $dirEntries) {
        throw "Directory index out of range: $DirectoryIndex"
    }
    if($RecordCount -lt 0 -or $RecordCount -gt $recordsPerDirectoryEntry) {
        throw "Record count out of range: $RecordCount"
    }
    if($Blocks.Count -gt 16) {
        throw "Too many allocation blocks in one directory entry: $($Blocks.Count)"
    }

    $subExtent = if($RecordCount -gt 128) { [int][Math]::Floor(($RecordCount - 1) / 128) } else { 0 }
    $rc = $RecordCount - ($subExtent * 128)
    $logicalExtent = ($ExtentGroup * ($exm + 1)) + $subExtent

    $dirOffset = $systemAreaSize + ($DirectoryIndex * 32)
    for($i = 0; $i -lt 32; $i++) {
        $Image[$dirOffset + $i] = 0
    }

    $Image[$dirOffset] = 0
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes($CpmName.Base), 0, $Image, $dirOffset + 1, 8)
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes($CpmName.Ext), 0, $Image, $dirOffset + 9, 3)
    $Image[$dirOffset + 12] = [byte]($logicalExtent -band 0x1F)
    $Image[$dirOffset + 13] = 0
    $Image[$dirOffset + 14] = [byte](($logicalExtent -shr 5) -band 0x3F)
    $Image[$dirOffset + 15] = [byte]$rc

    for($i = 0; $i -lt $Blocks.Count; $i++) {
        $Image[$dirOffset + 16 + $i] = [byte]$Blocks[$i]
    }
}

function Write-CpmFile {
    param(
        [byte[]]$Image,
        [string]$HostPath,
        [int]$DirectoryIndex,
        [int]$NextBlock
    )

    $fileBytes = [IO.File]::ReadAllBytes($HostPath)
    $cpmName = ConvertTo-CpmName $HostPath
    $records = [int][Math]::Ceiling($fileBytes.Length / [double]$logicalRecordSize)
    $blocksNeeded = [int][Math]::Ceiling($records / [double]$recordsPerBlock)
    $entriesNeeded = [Math]::Max(1, [int][Math]::Ceiling($records / [double]$recordsPerDirectoryEntry))

    if(($DirectoryIndex + $entriesNeeded) -gt $dirEntries) {
        throw "Not enough directory entries for $($cpmName.Display)"
    }
    if(($NextBlock + $blocksNeeded) -gt $maxBlocks) {
        throw "Not enough CP/M disk blocks for $($cpmName.Display)"
    }

    $blockList = @()
    for($i = 0; $i -lt $blocksNeeded; $i++) {
        $block = $NextBlock + $i
        $blockList += $block
        $offset = Get-BlockOffset $block
        for($j = 0; $j -lt $blockSize; $j++) {
            $Image[$offset + $j] = 0x1A
        }

        $copyOffset = $i * $blockSize
        $copyCount = [Math]::Min($blockSize, $fileBytes.Length - $copyOffset)
        if($copyCount -gt 0) {
            [Array]::Copy($fileBytes, $copyOffset, $Image, $offset, $copyCount)
        }
    }

    $remainingRecords = $records
    $blockCursor = 0
    for($extentGroup = 0; $extentGroup -lt $entriesNeeded; $extentGroup++) {
        $entryRecords = [Math]::Min($recordsPerDirectoryEntry, $remainingRecords)
        $entryBlockCount = [int][Math]::Ceiling($entryRecords / [double]$recordsPerBlock)
        $entryBlocks = @()
        for($i = 0; $i -lt $entryBlockCount; $i++) {
            $entryBlocks += $blockList[$blockCursor++]
        }

        Write-DirectoryEntry `
            -Image $Image `
            -DirectoryIndex ($DirectoryIndex + $extentGroup) `
            -CpmName $cpmName `
            -ExtentGroup $extentGroup `
            -RecordCount $entryRecords `
            -Blocks $entryBlocks

        $remainingRecords -= $entryRecords
    }

    return [pscustomobject]@{
        NextDirectoryIndex = $DirectoryIndex + $entriesNeeded
        NextBlock = $NextBlock + $blocksNeeded
        Name = $cpmName.Display
        Size = $fileBytes.Length
        Records = $records
        DirectoryEntries = $entriesNeeded
        Blocks = ($blockList -join ',')
    }
}

if(!(Test-Path -LiteralPath $RuntimePath -PathType Leaf)) {
    throw "Runtime not found: $RuntimePath"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

$runtime = [IO.File]::ReadAllBytes($RuntimePath)
if($runtime.Length -gt $systemAreaSize) {
    throw "Runtime is too large for the reserved system area: $($runtime.Length) bytes"
}

$image = New-Object byte[] $diskSize
for($i = 0; $i -lt $image.Length; $i++) {
    $image[$i] = 0xE5
}
[Array]::Copy($runtime, 0, $image, 0, $runtime.Length)

$dirIndex = 0
$nextBlock = $dataStartBlock
$imported = @()
if(Test-Path -LiteralPath $UtilitiesDir -PathType Container) {
    foreach($file in Get-ChildItem -LiteralPath $UtilitiesDir -File -Filter '*.COM' | Sort-Object Name) {
        $result = Write-CpmFile -Image $image -HostPath $file.FullName -DirectoryIndex $dirIndex -NextBlock $nextBlock
        $dirIndex = $result.NextDirectoryIndex
        $nextBlock = $result.NextBlock
        $imported += $result
    }
} else {
    Write-Warning "CP/M utilities directory not found; generating a bootable disk without COM utilities: $UtilitiesDir"
}

[IO.File]::WriteAllBytes($OutputPath, $image)

Write-Host "Generated $OutputPath ($($image.Length) bytes)"
Write-Host ("System runtime  {0} bytes at cylinder 0 side 0 sector 1" -f $runtime.Length)
Write-Host ("Disk geometry   {0} cylinders, {1} sides, {2} sectors/side, {3} bytes/sector" -f $tracks,$sides,$sectorsPerTrack,$sectorSize)
Write-Host ("Sector interval {0}" -f $sectorInterleave)
Write-Host ("Directory       offset={0} size={1} entries={2} EXM={3}" -f $systemAreaSize,$dirSize,$dirEntries,$exm)
if($imported.Count -gt 0) {
    Write-Host 'Imported files:'
    $imported | Select-Object Name,Size,Records,DirectoryEntries,Blocks | Format-Table -AutoSize
}
