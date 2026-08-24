$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root 'bin'
$runtimePath = Join-Path $outDir 'CPM22_RUNTIME.BIN'
$utilsDir = Join-Path $outDir 'cpmutils'
$imageOut = Join-Path $outDir 'CPM22_SYSTEM.2d'

$tracks = 40
$sides = 2
$sectorsPerTrack = 16
$sectorSize = 256
$sectorInterleave = 1
$cylinderSize = $sides * $sectorsPerTrack * $sectorSize
$systemAreaSize = 2 * $cylinderSize
$diskSize = $tracks * $cylinderSize

$blockSize = 2048
$dirEntries = 128
$dirSize = $dirEntries * 32
$dirBlocks = 2
$dataStartBlock = $dirBlocks
$maxBlocks = 152

function ConvertTo-CpmName {
    param([string]$InputName)

    $leaf = [IO.Path]::GetFileName($InputName).ToUpperInvariant()
    $parts = $leaf.Split('.', 2)
    $base = $parts[0]
    $ext = if($parts.Count -gt 1) { $parts[1] } else { '' }
    if($base.Length -lt 1 -or $base.Length -gt 8 -or $ext.Length -gt 3) {
        throw "Invalid CP/M 8.3 file name: $InputName"
    }
    [pscustomobject]@{
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

function Write-CpmFile {
    param(
        [byte[]]$Image,
        [string]$HostPath,
        [int]$DirectoryIndex,
        [int]$NextBlock
    )

    $fileBytes = [IO.File]::ReadAllBytes($HostPath)
    $cpmName = ConvertTo-CpmName $HostPath
    $blocksNeeded = [Math]::Ceiling($fileBytes.Length / $blockSize)
    if($blocksNeeded -gt 16) {
        throw "$($cpmName.Display) is too large for this simple importer"
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
        [Array]::Copy($fileBytes, $copyOffset, $Image, $offset, $copyCount)
    }

    $dirOffset = $systemAreaSize + ($DirectoryIndex * 32)
    for($i = 0; $i -lt 32; $i++) {
        $Image[$dirOffset + $i] = 0
    }
    $Image[$dirOffset] = 0
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes($cpmName.Base), 0, $Image, $dirOffset + 1, 8)
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes($cpmName.Ext), 0, $Image, $dirOffset + 9, 3)
    $Image[$dirOffset + 15] = [byte][Math]::Ceiling($fileBytes.Length / 128)
    for($i = 0; $i -lt $blockList.Count; $i++) {
        $Image[$dirOffset + 16 + $i] = [byte]$blockList[$i]
    }

    [pscustomobject]@{
        NextDirectoryIndex = $DirectoryIndex + 1
        NextBlock = $NextBlock + $blocksNeeded
        Name = $cpmName.Display
        Size = $fileBytes.Length
        Blocks = ($blockList -join ',')
    }
}

if(!(Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    throw "Runtime not found: $runtimePath"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$runtime = [IO.File]::ReadAllBytes($runtimePath)
if($runtime.Length -gt $systemAreaSize) {
    throw "Runtime is too large for the reserved system cylinder: $($runtime.Length) bytes"
}

$image = New-Object byte[] $diskSize
for($i = 0; $i -lt $image.Length; $i++) {
    $image[$i] = 0xE5
}

[Array]::Copy($runtime, 0, $image, 0, $runtime.Length)

$dirIndex = 0
$nextBlock = $dataStartBlock
$imported = @()
if(Test-Path -LiteralPath $utilsDir -PathType Container) {
    foreach($file in Get-ChildItem -LiteralPath $utilsDir -File -Filter '*.COM' | Sort-Object Name) {
        $result = Write-CpmFile -Image $image -HostPath $file.FullName -DirectoryIndex $dirIndex -NextBlock $nextBlock
        $dirIndex = $result.NextDirectoryIndex
        $nextBlock = $result.NextBlock
        $imported += $result
    }
}

[IO.File]::WriteAllBytes($imageOut, $image)

Write-Host "Generated $imageOut ($($image.Length) bytes)"
Write-Host ("System runtime  {0} bytes at cylinder 0 side 0 sector 1" -f $runtime.Length)
Write-Host ("Disk geometry   {0} cylinders, {1} sides, {2} sectors, {3} bytes/sector" -f $tracks,$sides,$sectorsPerTrack,$sectorSize)
Write-Host ("Sector interval {0}" -f $sectorInterleave)
Write-Host ("Directory       offset={0} size={1} entries={2}" -f $systemAreaSize,$dirSize,$dirEntries)
if($imported.Count -gt 0) {
    Write-Host "Imported files:"
    $imported | Select-Object Name,Size,Blocks | Format-Table -AutoSize
}
