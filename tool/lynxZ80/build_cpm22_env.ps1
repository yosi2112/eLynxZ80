[CmdletBinding()]
param(
    [string]$AswPath,
    [string]$P2BinPath,
    [string]$GitPath
)

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$archiveDir = Join-Path $root 'build\arch'
$runtimeDir = Join-Path $root 'build\cpm22_runtime'
$utilitySourceDir = Join-Path $root 'build\cpmutils'
$outDir = Join-Path $root 'bin'
$utilityOutDir = Join-Path $outDir 'cpmutils'

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

function Expand-ArchiveFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if(!(Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        throw "Archive not found: $ArchivePath"
    }

    $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
        Expand-Archive -LiteralPath $ArchivePath -DestinationPath $temporaryDirectory -Force

        $file = Get-ChildItem -Path $temporaryDirectory -Filter $FileName -File -Recurse |
            Select-Object -First 1

        if($null -eq $file) {
            throw "File not found in archive $ArchivePath : $FileName"
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $DestinationPath) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $DestinationPath -Force
    }
    finally {
        if(Test-Path -LiteralPath $temporaryDirectory) {
            Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
        }
    }
}

$asw = Resolve-Executable -ExplicitPath $AswPath -Name 'asw.exe'
$p2bin = Resolve-Executable -ExplicitPath $P2BinPath -Name 'p2bin.exe'
$git = Resolve-Executable -ExplicitPath $GitPath -Name 'git.exe'

New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
New-Item -ItemType Directory -Path $utilityOutDir -Force | Out-Null

$commandArchive = Join-Path $archiveDir 'cpm22-b.zip'
$standardCommands = @(
    'ASM.COM', 'DDT.COM', 'DUMP.COM', 'ED.COM', 'LOAD.COM',
    'PIP.COM', 'STAT.COM', 'SUBMIT.COM', 'XSUB.COM'
)

foreach($fileName in $standardCommands) {
    Expand-ArchiveFile `
        -ArchivePath $commandArchive `
        -FileName $fileName `
        -DestinationPath (Join-Path $utilityOutDir $fileName)
}

$sourceArchive = Join-Path $archiveDir 'cpm2-asm.zip'
$originalSource = Join-Path $runtimeDir 'CPM22.Z80'
$patchedSource = Join-Path $runtimeDir 'CPM22.ASM'
$patchPath = Join-Path $runtimeDir 'patch.diff'

Expand-ArchiveFile `
    -ArchivePath $sourceArchive `
    -FileName 'CPM22.Z80' `
    -DestinationPath $originalSource

if(!(Test-Path -LiteralPath $patchPath -PathType Leaf)) {
    throw "Patch not found: $patchPath"
}

# patch.diff keeps the upstream source name in the old-file header. Work on a
# copy and normalize that header so the patch can be re-applied idempotently.
Copy-Item -LiteralPath $originalSource -Destination $patchedSource -Force
$normalizedPatch = Join-Path $runtimeDir '__CPM22.normalized.patch'
$patchText = Get-Content -LiteralPath $patchPath -Raw
$patchText = [regex]::Replace(
    $patchText,
    '(?m)^---\s+CPM22\.Z80\s*$',
    '--- CPM22.ASM'
)
Set-Content -LiteralPath $normalizedPatch -Value $patchText -Encoding ASCII

Push-Location $runtimeDir
try {
    & $git 'apply' '--check' '-p0' $normalizedPatch
    if($LASTEXITCODE -ne 0) {
        throw "CP/M source patch check failed with exit code $LASTEXITCODE"
    }

    & $git 'apply' '-p0' $normalizedPatch
    if($LASTEXITCODE -ne 0) {
        throw "CP/M source patch failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $normalizedPatch -Force -ErrorAction SilentlyContinue
}

$localUtilities = @('CLS', 'DISKCOPY', 'FORMAT', 'MOVCPM5')
foreach($name in $localUtilities) {
    $source = Join-Path $utilitySourceDir ($name + '.ASM')
    if(!(Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Utility source not found: $source"
    }

    $object = Join-Path $utilitySourceDir ($name + '.p')
    $listing = Join-Path $utilitySourceDir ($name + '.lst')
    $com = Join-Path $utilitySourceDir ($name + '.COM')
    $destination = Join-Path $utilityOutDir ($name + '.COM')

    Push-Location $utilitySourceDir
    try {
        & $asw '-cpu' 'Z80' '-L' (Split-Path -Leaf $source)
        if($LASTEXITCODE -ne 0) {
            throw "ASW failed for $name with exit code $LASTEXITCODE"
        }

        & $p2bin (Split-Path -Leaf $object) (Split-Path -Leaf $com) '-r' '$-$'
        if($LASTEXITCODE -ne 0) {
            throw "p2bin failed for $name with exit code $LASTEXITCODE"
        }

        Copy-Item -LiteralPath $com -Destination $destination -Force
    }
    finally {
        Pop-Location
        Remove-Item -LiteralPath $object,$com -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Built utility $destination"
    if(Test-Path -LiteralPath $listing) {
        Write-Host "Listing       $listing"
    }
}

Write-Host ''
Write-Host 'CP/M 2.2 build environment is ready.'
Write-Host "Patched source $patchedSource"
Write-Host "Utilities     $utilityOutDir"
Write-Host "ASW           $asw"
Write-Host "p2bin         $p2bin"
