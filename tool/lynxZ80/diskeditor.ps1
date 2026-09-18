[CmdletBinding()]
param(
    [ValidateSet('Help','Info','List','Import','Export','Delete')]
    [string]$Command = 'List',

    [string]$Image,
    [string]$Path,
    [string]$Name,
    [string]$Out,

    [ValidateRange(0,15)]
    [int]$User = 0,

    [ValidateSet('Current','Legacy')]
    [string]$Format = 'Current',

    [switch]$Force,

    [ValidateRange(0,255)]
    [int]$PadByte = 0x1A
)

$ErrorActionPreference = 'Stop'
$LogicalRecordSize = 128

if($Format -eq 'Current') {
    # eLynxZ80 CP/M 2.2 system disk (DPB: SPT=64, BSH=4, BLM=15,
    # EXM=1, DSM=151, DRM=127, AL0=C0h, CKS=32, OFF=2).
    $Cylinders = 40
    $Sides = 2
    $SectorsPerSide = 16
    $SectorSize = 256
    $ReservedUnits = 2
    $BlockSize = 2048
    $DirEntries = 128
    $DirBlocks = 2
    $Dsm = 151
    $Exm = 1
    $UnitSize = $Sides * $SectorsPerSide * $SectorSize
    $GeometryText = "$Cylinders cylinders, $Sides sides, $SectorsPerSide sectors/side, $SectorSize bytes/sector"
} else {
    # Compatibility with the pre-2026 diskeditor geometry.
    $Cylinders = 77
    $Sides = 1
    $SectorsPerSide = 26
    $SectorSize = 128
    $ReservedUnits = 2
    $BlockSize = 1024
    $DirEntries = 64
    $DirBlocks = 2
    $Dsm = 242
    $Exm = 0
    $UnitSize = $Sides * $SectorsPerSide * $SectorSize
    $GeometryText = "$Cylinders tracks, 1 side, $SectorsPerSide sectors/track, $SectorSize bytes/sector"
}

$DiskSize = $Cylinders * $UnitSize
$SystemOffset = $ReservedUnits * $UnitSize
$DirOffset = $SystemOffset
$DirSize = $DirEntries * 32
$DataStartBlock = $DirBlocks
$MaxBlocks = $Dsm + 1
$RecordsPerBlock = [int]($BlockSize / $LogicalRecordSize)
$RecordsPerDirectoryEntry = 128 * ($Exm + 1)
$BlocksPerDirectoryEntry = [int]($RecordsPerDirectoryEntry / $RecordsPerBlock)

function Show-Usage {
    $scriptName = if($PSCommandPath) { Split-Path -Leaf $PSCommandPath } else { 'diskeditor.ps1' }
    Write-Host @"
Usage:
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.2d> [-Command Info|List]
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.2d> -Command Import -Path <host-file> [-Name <CPM-NAME>] [-User 0-15] [-Force]
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.2d> -Command Export -Name <CPM-NAME> [-Out <host-file>] [-User 0-15]
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.2d> -Command Delete -Name <CPM-NAME> [-User 0-15]

Commands:
  Help    Show this help.
  Info    Show disk image geometry and usage summary.
  List    List files in the CP/M directory.
  Import  Import a host file into the CP/M image.
  Export  Export a CP/M file from the image.
  Delete  Delete a CP/M file from the image.

Options:
  -Image    Required for Info, List, Import, Export, and Delete.
  -User     CP/M user number. Default: 0.
  -Name     CP/M 8.3 file name for Import, Export, or Delete.
  -Path     Host file path for Import.
  -Out      Host output path for Export.
  -Force    Replace an existing CP/M file during Import.
  -PadByte  Import padding byte. Default: 0x1A.
  -Format   Current (default) or Legacy.

Current format:
  40 cylinders, 2 sides, 16 sectors/side, 256 bytes/sector
  2 reserved cylinders, 2048-byte blocks, 128 directory entries, EXM=1

Legacy format:
  77 tracks, 1 side, 26 sectors/track, 128 bytes/sector
  2 reserved tracks, 1024-byte blocks, 64 directory entries, EXM=0
"@
}

if($Command -eq 'Help' -or [string]::IsNullOrWhiteSpace($Image)) {
    Show-Usage
    return
}

function Assert-Image {
    param([byte[]]$Bytes)
    if($Bytes.Length -ne $DiskSize) {
        $legacySize = 77 * 26 * 128
        $currentSize = 40 * 2 * 16 * 256
        if($Format -eq 'Current' -and $Bytes.Length -eq $legacySize) {
            throw "Legacy image detected ($($Bytes.Length) bytes). Re-run with -Format Legacy."
        }
        if($Format -eq 'Legacy' -and $Bytes.Length -eq $currentSize) {
            throw "Current eLynxZ80 image detected ($($Bytes.Length) bytes). Re-run with -Format Current."
        }
        throw "Unexpected image size: $($Bytes.Length). Expected $DiskSize bytes for $Format format."
    }
}

function Get-ImageBytes {
    if(!(Test-Path -LiteralPath $Image -PathType Leaf)) {
        throw "Image not found: $Image"
    }
    $bytes = [System.IO.File]::ReadAllBytes($Image)
    Assert-Image $bytes
    return ,$bytes
}

function Save-ImageBytes {
    param([byte[]]$Bytes)
    Assert-Image $Bytes
    [System.IO.File]::WriteAllBytes($Image, $Bytes)
}

function ConvertTo-CpmName {
    param([string]$InputName)
    if([string]::IsNullOrWhiteSpace($InputName)) {
        throw 'CP/M file name is required.'
    }

    $leaf = [System.IO.Path]::GetFileName($InputName).ToUpperInvariant()
    $parts = $leaf.Split('.', 2)
    $base = $parts[0]
    $ext = if($parts.Count -gt 1) { $parts[1] } else { '' }
    if($base.Length -lt 1 -or $base.Length -gt 8 -or $ext.Length -gt 3) {
        throw "Invalid CP/M 8.3 name: $InputName"
    }
    if(($base + $ext) -notmatch '^[A-Z0-9_$#@!%&''(){}^~-]+$') {
        throw "Unsupported CP/M name characters: $InputName"
    }

    return [pscustomobject]@{
        Base = $base.PadRight(8, ' ')
        Ext = $ext.PadRight(3, ' ')
        Display = if($ext.Length -gt 0) { "$base.$ext" } else { $base }
    }
}

function Get-DirectoryText {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [int]$Length
    )

    $clean = New-Object byte[] $Length
    for($i = 0; $i -lt $Length; $i++) {
        $clean[$i] = [byte]($Bytes[$Offset + $i] -band 0x7F)
    }
    return [System.Text.Encoding]::ASCII.GetString($clean)
}

function Get-DirEntry {
    param([byte[]]$Bytes, [int]$Index)

    $off = $DirOffset + ($Index * 32)
    $userByte = $Bytes[$off]
    $name = Get-DirectoryText -Bytes $Bytes -Offset ($off + 1) -Length 8
    $ext = Get-DirectoryText -Bytes $Bytes -Offset ($off + 9) -Length 3
    $ex = [int]$Bytes[$off + 12]
    $s2 = [int]$Bytes[$off + 14]
    $rc = [int]$Bytes[$off + 15]
    $logicalExtent = (($s2 -band 0x3F) * 32) + ($ex -band 0x1F)
    $subExtent = $logicalExtent -band $Exm
    $records = ($subExtent * 128) + $rc

    $blocks = @()
    for($i = 0; $i -lt 16; $i++) {
        $block = [int]$Bytes[$off + 16 + $i]
        if($block -ne 0) {
            $blocks += $block
        }
    }

    $displayName = $name.TrimEnd()
    $displayExt = $ext.TrimEnd()
    if($displayExt.Length -gt 0) {
        $displayName = "$displayName.$displayExt"
    }

    return [pscustomobject]@{
        Index = $Index
        Offset = $off
        Deleted = ($userByte -eq 0xE5)
        User = [int]$userByte
        NameRaw = $name
        ExtRaw = $ext
        Name = $displayName
        Ex = $ex
        S1 = [int]$Bytes[$off + 13]
        S2 = $s2
        Rc = $rc
        LogicalExtent = $logicalExtent
        ExtentGroup = [int][Math]::Floor($logicalExtent / ($Exm + 1))
        Records = $records
        Blocks = $blocks
    }
}

function Get-ActiveEntries {
    param([byte[]]$Bytes)
    $entries = @()
    for($i = 0; $i -lt $DirEntries; $i++) {
        $entry = Get-DirEntry $Bytes $i
        if(!$entry.Deleted -and $entry.User -le 15) {
            $entries += $entry
        }
    }
    return $entries
}

function Get-FreeDirIndexes {
    param([byte[]]$Bytes)
    $free = @()
    for($i = 0; $i -lt $DirEntries; $i++) {
        if($Bytes[$DirOffset + ($i * 32)] -eq 0xE5) {
            $free += $i
        }
    }
    return $free
}

function Get-UsedBlocks {
    param([byte[]]$Bytes)
    $used = New-Object bool[] $MaxBlocks
    for($i = 0; $i -lt $DirBlocks; $i++) {
        $used[$i] = $true
    }
    foreach($entry in (Get-ActiveEntries $Bytes)) {
        foreach($block in $entry.Blocks) {
            if($block -ge 0 -and $block -lt $MaxBlocks) {
                $used[$block] = $true
            }
        }
    }
    return $used
}

function Get-FreeBlocks {
    param([byte[]]$Bytes)
    $used = Get-UsedBlocks $Bytes
    $free = @()
    for($i = $DataStartBlock; $i -lt $MaxBlocks; $i++) {
        if(!$used[$i]) {
            $free += $i
        }
    }
    return $free
}

function Get-BlockOffset {
    param([int]$Block)
    if($Block -lt 0 -or $Block -ge $MaxBlocks) {
        throw "Block out of range: $Block"
    }
    return $SystemOffset + ($Block * $BlockSize)
}

function Find-FileEntries {
    param([byte[]]$Bytes, [object]$CpmName, [int]$UserNumber)
    return Get-ActiveEntries $Bytes |
        Where-Object { $_.User -eq $UserNumber -and $_.NameRaw -eq $CpmName.Base -and $_.ExtRaw -eq $CpmName.Ext } |
        Sort-Object LogicalExtent, Index
}

function Clear-DirectoryEntry {
    param([byte[]]$Bytes, [int]$Index)
    $off = $DirOffset + ($Index * 32)
    for($i = 0; $i -lt 32; $i++) {
        $Bytes[$off + $i] = 0xE5
    }
}

function Write-DirectoryEntry {
    param(
        [byte[]]$Bytes,
        [int]$Index,
        [object]$CpmName,
        [int]$UserNumber,
        [int]$ExtentGroup,
        [int]$RecordCount,
        [int[]]$Blocks
    )

    if($RecordCount -lt 0 -or $RecordCount -gt $RecordsPerDirectoryEntry) {
        throw "Record count out of range for one directory entry: $RecordCount"
    }
    if($Blocks.Count -gt 16) {
        throw "Too many allocation blocks for one directory entry: $($Blocks.Count)"
    }

    $subExtent = if($RecordCount -gt 128) { [int][Math]::Floor(($RecordCount - 1) / 128) } else { 0 }
    $rc = $RecordCount - ($subExtent * 128)
    $logicalExtent = ($ExtentGroup * ($Exm + 1)) + $subExtent

    $off = $DirOffset + ($Index * 32)
    for($i = 0; $i -lt 32; $i++) {
        $Bytes[$off + $i] = 0
    }

    $Bytes[$off] = [byte]$UserNumber
    $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($CpmName.Base)
    $extBytes = [System.Text.Encoding]::ASCII.GetBytes($CpmName.Ext)
    [Array]::Copy($nameBytes, 0, $Bytes, $off + 1, 8)
    [Array]::Copy($extBytes, 0, $Bytes, $off + 9, 3)
    $Bytes[$off + 12] = [byte]($logicalExtent -band 0x1F)
    $Bytes[$off + 13] = 0
    $Bytes[$off + 14] = [byte](($logicalExtent -shr 5) -band 0x3F)
    $Bytes[$off + 15] = [byte]$rc

    for($i = 0; $i -lt $Blocks.Count; $i++) {
        $Bytes[$off + 16 + $i] = [byte]$Blocks[$i]
    }
}

function Show-Info {
    $bytes = Get-ImageBytes
    $entries = Get-ActiveEntries $bytes
    $freeDir = (Get-FreeDirIndexes $bytes).Count
    $freeBlocks = (Get-FreeBlocks $bytes).Count

    [pscustomobject]@{
        Image = $Image
        Format = $Format
        Size = $bytes.Length
        Geometry = $GeometryText
        ReservedSystemBytes = $SystemOffset
        DirectoryOffset = $DirOffset
        DirectoryEntries = $DirEntries
        ActiveDirectoryEntries = $entries.Count
        FreeDirectoryEntries = $freeDir
        BlockSize = $BlockSize
        ExtentMask = $Exm
        RecordsPerDirectoryEntry = $RecordsPerDirectoryEntry
        DataBlocks = $MaxBlocks - $DirBlocks
        FreeDataBlocks = $freeBlocks
        FreeBytes = $freeBlocks * $BlockSize
    } | Format-List
}

function Show-List {
    $bytes = Get-ImageBytes
    $groups = Get-ActiveEntries $bytes | Group-Object User, Name | Sort-Object Name
    if($groups.Count -eq 0) {
        Write-Host 'No CP/M files.'
        return
    }

    foreach($group in $groups) {
        $entries = @($group.Group | Sort-Object LogicalExtent, Index)
        $records = ($entries | Measure-Object Records -Sum).Sum
        $blocks = @($entries | ForEach-Object { $_.Blocks } | Sort-Object -Unique)
        [pscustomobject]@{
            User = $entries[0].User
            Name = $entries[0].Name
            Records = $records
            Bytes = $records * $LogicalRecordSize
            DirectoryEntries = $entries.Count
            Blocks = ($blocks -join ',')
        }
    }
}

function Import-File {
    if([string]::IsNullOrWhiteSpace($Path)) {
        throw '-Path is required for Import.'
    }
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Input file not found: $Path"
    }

    $bytes = Get-ImageBytes
    $source = [System.IO.File]::ReadAllBytes($Path)
    $cpmName = ConvertTo-CpmName $(if($Name) { $Name } else { [System.IO.Path]::GetFileName($Path) })
    $existing = @(Find-FileEntries $bytes $cpmName $User)
    if($existing.Count -gt 0 -and !$Force) {
        throw "$($cpmName.Display) already exists for user $User. Use -Force to replace it."
    }
    foreach($entry in $existing) {
        Clear-DirectoryEntry $bytes $entry.Index
    }

    $records = [int][Math]::Ceiling($source.Length / [double]$LogicalRecordSize)
    $neededBlocks = [int][Math]::Ceiling($records / [double]$RecordsPerBlock)
    $neededEntries = [Math]::Max(1, [int][Math]::Ceiling($records / [double]$RecordsPerDirectoryEntry))
    $freeDir = @(Get-FreeDirIndexes $bytes)
    $freeBlocks = @(Get-FreeBlocks $bytes)

    if($freeDir.Count -lt $neededEntries) {
        throw "Not enough directory entries. Need $neededEntries, have $($freeDir.Count)."
    }
    if($freeBlocks.Count -lt $neededBlocks) {
        throw "Not enough free blocks. Need $neededBlocks, have $($freeBlocks.Count)."
    }

    if($neededBlocks -gt 0) {
        $paddedLength = $neededBlocks * $BlockSize
        $padded = New-Object byte[] $paddedLength
        for($i = 0; $i -lt $padded.Length; $i++) {
            $padded[$i] = [byte]$PadByte
        }
        if($source.Length -gt 0) {
            [Array]::Copy($source, 0, $padded, 0, $source.Length)
        }

        for($b = 0; $b -lt $neededBlocks; $b++) {
            $block = $freeBlocks[$b]
            $dest = Get-BlockOffset $block
            [Array]::Copy($padded, $b * $BlockSize, $bytes, $dest, $BlockSize)
        }
    }

    $remainingRecords = $records
    $blockCursor = 0
    for($extentGroup = 0; $extentGroup -lt $neededEntries; $extentGroup++) {
        $entryRecords = [Math]::Min($RecordsPerDirectoryEntry, $remainingRecords)
        $entryBlocks = [int][Math]::Ceiling($entryRecords / [double]$RecordsPerBlock)
        $blocks = @()
        for($i = 0; $i -lt $entryBlocks; $i++) {
            $blocks += $freeBlocks[$blockCursor++]
        }

        Write-DirectoryEntry `
            -Bytes $bytes `
            -Index $freeDir[$extentGroup] `
            -CpmName $cpmName `
            -UserNumber $User `
            -ExtentGroup $extentGroup `
            -RecordCount $entryRecords `
            -Blocks $blocks

        $remainingRecords -= $entryRecords
    }

    Save-ImageBytes $bytes
    Write-Host ("Imported {0} as {1} user={2} bytes={3} records={4} blocks={5} entries={6}" -f $Path,$cpmName.Display,$User,$source.Length,$records,$neededBlocks,$neededEntries)
}

function Export-File {
    if([string]::IsNullOrWhiteSpace($Name)) {
        throw '-Name is required for Export.'
    }

    $bytes = Get-ImageBytes
    $cpmName = ConvertTo-CpmName $Name
    $entries = @(Find-FileEntries $bytes $cpmName $User)
    if($entries.Count -eq 0) {
        throw "$($cpmName.Display) not found for user $User."
    }

    $recordCount = ($entries | Measure-Object Records -Sum).Sum
    $outBytes = New-Object byte[] ($recordCount * $LogicalRecordSize)
    $destOffset = 0

    foreach($entry in $entries) {
        $remaining = $entry.Records * $LogicalRecordSize
        foreach($block in $entry.Blocks) {
            if($remaining -le 0) {
                break
            }
            $copy = [Math]::Min($BlockSize, $remaining)
            [Array]::Copy($bytes, (Get-BlockOffset $block), $outBytes, $destOffset, $copy)
            $destOffset += $copy
            $remaining -= $copy
        }
        if($remaining -ne 0) {
            throw "Directory entry for $($entry.Name) does not contain enough allocation blocks."
        }
    }

    $outPath = if($Out) { $Out } else { Join-Path (Get-Location) $cpmName.Display }
    $outDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($outPath))
    if($outDirectory) {
        New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
    }
    [System.IO.File]::WriteAllBytes($outPath, $outBytes)
    Write-Host ("Exported {0} user={1} to {2} bytes={3}" -f $cpmName.Display,$User,$outPath,$outBytes.Length)
}

function Delete-File {
    if([string]::IsNullOrWhiteSpace($Name)) {
        throw '-Name is required for Delete.'
    }

    $bytes = Get-ImageBytes
    $cpmName = ConvertTo-CpmName $Name
    $entries = @(Find-FileEntries $bytes $cpmName $User)
    if($entries.Count -eq 0) {
        throw "$($cpmName.Display) not found for user $User."
    }
    foreach($entry in $entries) {
        Clear-DirectoryEntry $bytes $entry.Index
    }
    Save-ImageBytes $bytes
    Write-Host ("Deleted {0} user={1} entries={2}" -f $cpmName.Display,$User,$entries.Count)
}

switch($Command) {
    'Info' { Show-Info }
    'List' { Show-List }
    'Import' { Import-File }
    'Export' { Export-File }
    'Delete' { Delete-File }
}
