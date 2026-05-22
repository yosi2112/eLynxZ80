param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$root = Join-Path $repoRoot 'src\vm\Lynxz80'
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'
$buildDir = Join-Path $root 'build'
$outDir = $buildDir
$stage = Join-Path $buildDir 'diag'

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool)) {
        throw "Required tool not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$targets = @(
    @{ Source = 'diag_main.asm';   Stem = 'diag_main';   Out = 'DIAGMAIN.ROM' },
    @{ Source = 'diag_subcpu.asm'; Stem = 'diag_subcpu'; Out = 'DIAGSUB.ROM'  }
)

foreach($target in $targets) {
    $source = Join-Path $stage $target.Source
    if(!(Test-Path -LiteralPath $source)) {
        throw "Build source not found: $source"
    }
}

Push-Location $stage
try {
    foreach($target in $targets) {
        & $asw '-cpu' 'z80' '-L' $target.Source
        if($LASTEXITCODE -ne 0) {
            throw "ASW assembly failed for $($target.Source) with exit code $LASTEXITCODE"
        }

        $object = Join-Path $stage "$($target.Stem).p"
        $romBin = Join-Path $stage "$($target.Stem).bin"
        $romOut = Join-Path $outDir $target.Out

        & $p2bin $object $romBin '-r' '0x0000-0x1fff' '-l' '0xff'
        if($LASTEXITCODE -ne 0) {
            throw "p2bin conversion failed for $($target.Source) with exit code $LASTEXITCODE"
        }

        $romBytes = [System.IO.File]::ReadAllBytes($romBin)
        if($romBytes.Length -ne 8192) {
            throw "Unexpected ROM size for $($target.Out): $($romBytes.Length) bytes"
        }
        [System.IO.File]::WriteAllBytes($romOut, $romBytes)
        Write-Host "Generated $romOut ($($romBytes.Length) bytes)"
    }

    if($Install) {
        Copy-Item -LiteralPath (Join-Path $outDir 'DIAGMAIN.ROM') -Destination (Join-Path $outDir 'IPL.ROM') -Force
        Copy-Item -LiteralPath (Join-Path $outDir 'DIAGSUB.ROM') -Destination (Join-Path $outDir 'SUBCPU.ROM') -Force
        Write-Host "Installed diagnostic ROMs as IPL.ROM and SUBCPU.ROM"
    }

    Get-ChildItem -Path $stage -Filter *.p -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}
finally {
    Pop-Location
}
