param(
    [ValidateSet('Help','Info','List','Import','Export','Delete')]
    [string]$Command = 'List',

    [string]$Image,

    [string]$Path,
    [string]$Name,
    [string]$Out,

    [ValidateRange(0,15)]
    [int]$User = 0,

    [switch]$Force,

    [ValidateRange(0,255)]
    [int]$PadByte = 0x1A
)

$ErrorActionPreference = 'Stop'

$Tracks = 77
$SectorsPerTrack = 26
$SectorSize = 128
$ReservedTracks = 2
$BlockSize = 1024
$DirEntries = 64
$DirBlocks = 2
$Dsm = 242
$DiskSize = $Tracks * $SectorsPerTrack * $SectorSize
$SystemOffset = $ReservedTracks * $SectorsPerTrack * $SectorSize
$DirOffset = $SystemOffset
$DirSize = $DirEntries * 32
$DataStartBlock = $DirBlocks
$MaxBlocks = $Dsm + 1

function Show-Usage {
    $scriptName = if($PSCommandPath) { Split-Path -Leaf $PSCommandPath } else { 'diskeditor.ps1' }
    Write-Host @"
Usage:
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.img> [-Command Info|List]
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.img> -Command Import -Path <host-file> [-Name <CPM-NAME>] [-User 0-15] [-Force]
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.img> -Command Export -Name <CPM-NAME> [-Out <host-file>] [-User 0-15]
  powershell -ExecutionPolicy Bypass -File $scriptName -Image <disk.img> -Command Delete -Name <CPM-NAME> [-User 0-15]

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
"@
}

if($Command -eq 'Help' -or [string]::IsNullOrWhiteSpace($Image)) {
    Show-Usage
    return
}

function Assert-Image {
    param([byte[]]$Bytes)
    if($Bytes.Length -ne $DiskSize) {
        throw "Unexpected image size: $($Bytes.Length). Expected $DiskSize bytes."
    }
}

function Get-ImageBytes {
    if(!(Test-Path -LiteralPath $Image)) {
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
        throw "CP/M file name is required."
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

function Get-DirEntry {
    param([byte[]]$Bytes, [int]$Index)
    $off = $DirOffset + ($Index * 32)
    $userByte = $Bytes[$off]
    $name = [System.Text.Encoding]::ASCII.GetString($Bytes, $off + 1, 8)
    $ext = [System.Text.Encoding]::ASCII.GetString($Bytes, $off + 9, 3)
    $blocks = @()
    for($i = 0; $i -lt 16; $i++) {
        $b = $Bytes[$off + 16 + $i]
        if($b -ne 0) {
            $blocks += [int]$b
        }
    }
    $displayName = $name.TrimEnd()
    $displayExt = $ext.TrimEnd()
    if($displayExt.Length -gt 0) {
        $displayName = "$displayName.$displayExt"
    }
    [pscustomobject]@{
        Index = $Index
        Offset = $off
        Deleted = ($userByte -eq 0xE5)
        Empty = ($userByte -eq 0xE5)
        User = [int]$userByte
        NameRaw = $name
        ExtRaw = $ext
        Name = $displayName
        Ex = [int]$Bytes[$off + 12]
        S1 = [int]$Bytes[$off + 13]
        S2 = [int]$Bytes[$off + 14]
        Rc = [int]$Bytes[$off + 15]
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
    Get-ActiveEntries $Bytes |
        Where-Object { $_.User -eq $UserNumber -and $_.NameRaw -eq $CpmName.Base -and $_.ExtRaw -eq $CpmName.Ext } |
        Sort-Object Ex, S2, Index
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
        [int]$Extent,
        [int]$RecordCount,
        [int[]]$Blocks
    )
    $off = $DirOffset + ($Index * 32)
    for($i = 0; $i -lt 32; $i++) {
        $Bytes[$off + $i] = 0
    }
    $Bytes[$off] = [byte]$UserNumber
    $nameBytes = [System.Text.Encoding]::ASCII.GetBytes($CpmName.Base)
    $extBytes = [System.Text.Encoding]::ASCII.GetBytes($CpmName.Ext)
    [Array]::Copy($nameBytes, 0, $Bytes, $off + 1, 8)
    [Array]::Copy($extBytes, 0, $Bytes, $off + 9, 3)
    $Bytes[$off + 12] = [byte]($Extent -band 0x1F)
    $Bytes[$off + 13] = 0
    $Bytes[$off + 14] = [byte](($Extent -shr 5) -band 0xFF)
    $Bytes[$off + 15] = [byte]$RecordCount
    for($i = 0; $i -lt $Blocks.Count -and $i -lt 16; $i++) {
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
        Size = $bytes.Length
        Geometry = "$Tracks tracks, 1 side, $SectorsPerTrack sectors, $SectorSize bytes/sector"
        ReservedSystemBytes = $SystemOffset
        DirectoryOffset = $DirOffset
        DirectoryEntries = $DirEntries
        ActiveExtents = $entries.Count
        FreeDirectoryEntries = $freeDir
        BlockSize = $BlockSize
        DataBlocks = $MaxBlocks - $DirBlocks
        FreeDataBlocks = $freeBlocks
        FreeBytes = $freeBlocks * $BlockSize
    } | Format-List
}

function Show-List {
    $bytes = Get-ImageBytes
    $groups = Get-ActiveEntries $bytes | Group-Object User, Name | Sort-Object Name
    if($groups.Count -eq 0) {
        Write-Host "No CP/M files."
        return
    }
    foreach($group in $groups) {
        $entries = @($group.Group | Sort-Object Ex, S2, Index)
        $records = ($entries | Measure-Object Rc -Sum).Sum
        $blocks = @($entries | ForEach-Object { $_.Blocks } | Sort-Object -Unique)
        [pscustomobject]@{
            User = $entries[0].User
            Name = $entries[0].Name
            Records = $records
            Bytes = $records * 128
            Extents = $entries.Count
            Blocks = ($blocks -join ',')
        }
    }
}

function Import-File {
    if([string]::IsNullOrWhiteSpace($Path)) {
        throw "-Path is required for Import."
    }
    if(!(Test-Path -LiteralPath $Path)) {
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

    $records = [int][Math]::Ceiling($source.Length / 128.0)
    if($records -eq 0) {
        $records = 1
    }
    $neededBlocks = [int][Math]::Ceiling($records / 8.0)
    $neededExtents = [int][Math]::Ceiling($records / 128.0)
    $freeDir = @(Get-FreeDirIndexes $bytes)
    $freeBlocks = @(Get-FreeBlocks $bytes)
    if($freeDir.Count -lt $neededExtents) {
        throw "Not enough directory entries. Need $neededExtents, have $($freeDir.Count)."
    }
    if($freeBlocks.Count -lt $neededBlocks) {
        throw "Not enough free blocks. Need $neededBlocks, have $($freeBlocks.Count)."
    }

    $paddedLength = $neededBlocks * $BlockSize
    $padded = New-Object byte[] $paddedLength
    for($i = 0; $i -lt $padded.Length; $i++) {
        $padded[$i] = [byte]$PadByte
    }
    [Array]::Copy($source, 0, $padded, 0, $source.Length)

    for($b = 0; $b -lt $neededBlocks; $b++) {
        $block = $freeBlocks[$b]
        $dest = Get-BlockOffset $block
        [Array]::Copy($padded, $b * $BlockSize, $bytes, $dest, $BlockSize)
    }

    $remainingRecords = $records
    $blockCursor = 0
    for($extent = 0; $extent -lt $neededExtents; $extent++) {
        $extentRecords = [Math]::Min(128, $remainingRecords)
        $extentBlocks = [int][Math]::Ceiling($extentRecords / 8.0)
        $dirIndex = $freeDir[$extent]
        $blocks = @()
        for($i = 0; $i -lt $extentBlocks; $i++) {
            $blocks += $freeBlocks[$blockCursor++]
        }
        Write-DirectoryEntry $bytes $dirIndex $cpmName $User $extent $extentRecords $blocks
        $remainingRecords -= $extentRecords
    }

    Save-ImageBytes $bytes
    Write-Host ("Imported {0} as {1} user={2} bytes={3} records={4} blocks={5}" -f $Path,$cpmName.Display,$User,$source.Length,$records,$neededBlocks)
}

function Export-File {
    if([string]::IsNullOrWhiteSpace($Name)) {
        throw "-Name is required for Export."
    }
    $bytes = Get-ImageBytes
    $cpmName = ConvertTo-CpmName $Name
    $entries = @(Find-FileEntries $bytes $cpmName $User)
    if($entries.Count -eq 0) {
        throw "$($cpmName.Display) not found for user $User."
    }
    $recordCount = ($entries | Measure-Object Rc -Sum).Sum
    $outBytes = New-Object byte[] ($recordCount * 128)
    $destOffset = 0
    foreach($entry in $entries) {
        $remaining = $entry.Rc * 128
        foreach($block in $entry.Blocks) {
            if($remaining -le 0) {
                break
            }
            $copy = [Math]::Min($BlockSize, $remaining)
            [Array]::Copy($bytes, (Get-BlockOffset $block), $outBytes, $destOffset, $copy)
            $destOffset += $copy
            $remaining -= $copy
        }
    }
    $outPath = if($Out) { $Out } else { Join-Path (Get-Location) $cpmName.Display }
    [System.IO.File]::WriteAllBytes($outPath, $outBytes)
    Write-Host ("Exported {0} user={1} to {2} bytes={3}" -f $cpmName.Display,$User,$outPath,$outBytes.Length)
}

function Delete-File {
    if([string]::IsNullOrWhiteSpace($Name)) {
        throw "-Name is required for Delete."
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
    Write-Host ("Deleted {0} user={1} extents={2}" -f $cpmName.Display,$User,$entries.Count)
}

switch($Command) {
    'Info' { Show-Info }
    'List' { Show-List }
    'Import' { Import-File }
    'Export' { Export-File }
    'Delete' { Delete-File }
}
