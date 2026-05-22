param(
    [switch]$diag,
    [ValidateSet('Debug', 'Release')]
    [string]$Target = 'Release'
)

$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$vmRoot = Join-Path $repoRoot 'src\vm\Lynxz80'
$srcDir = Join-Path $vmRoot 'build'
$debugDir = Join-Path $repoRoot 'vc++2017\bin\x86\Debug'
$releaseDir = Join-Path $repoRoot 'vc++2017\bin\x86\Release'

function Copy-RomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceName,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir,

        [string]$DestinationName = $SourceName
    )

    $source = Join-Path $srcDir $SourceName
    if(!(Test-Path -LiteralPath $source)) {
        throw "ROM source not found: $source"
    }

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    $destination = Join-Path $DestinationDir $DestinationName
    Copy-Item -LiteralPath $source -Destination $destination -Force
    Write-Host "Copied $source -> $destination"
}

if($diag) {
    Copy-RomFile -SourceName 'DIAGMAIN.ROM' -DestinationDir $debugDir -DestinationName 'IPL.ROM'
    Copy-RomFile -SourceName 'DIAGSUB.ROM' -DestinationDir $debugDir -DestinationName 'SUBCPU.ROM'
    Write-Host 'Installed diagnostic ROMs to Debug only.'
    return
} elseif($Target == 'Release') {
    Copy-RomFile -SourceName 'IPL.ROM' -DestinationDir $releaseDir
    Copy-RomFile -SourceName 'SUBCPU.ROM' -DestinationDir $releaseDir
    return
} elseif($Target == 'Debug') {
    Copy-RomFile -SourceName 'IPL.ROM' -DestinationDir $debugDir
    Copy-RomFile -SourceName 'SUBCPU.ROM' -DestinationDir $debugDir
    return
}
