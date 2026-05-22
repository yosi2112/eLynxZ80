$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$root = Join-Path $repoRoot 'src\vm\Lynxz80'
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'
$buildDir = Join-Path $root 'build'
$srcDir = Join-Path $root 'build\gvramtest'
$outDir = Join-Path $buildDir 'gvramtest'
$baseImage = Join-Path $buildDir 'CPM22_SYSTEM.IMG'
$outImage = Join-Path $buildDir 'GVRAM_TEST_BOOT.IMG'
$backupDir = Join-Path $buildDir 'archive\old_versions\bin_backup\gvramtest'
$diskEditor = Join-Path $toolRoot 'diskeditor.ps1'

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool)) {
        throw "Required tool not found: $tool"
    }
}
foreach($path in @($srcDir, $baseImage, $diskEditor)) {
    if(!(Test-Path -LiteralPath $path)) {
        throw "Required path not found: $path"
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

if(Test-Path -LiteralPath $outImage) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupImage = Join-Path $backupDir "GVRAM_TEST_BOOT_$stamp.IMG"
    Copy-Item -LiteralPath $outImage -Destination $backupImage -Force
    Write-Host "Backed up existing image to $backupImage"
}

Push-Location $srcDir
try {
    $asm = Join-Path $srcDir 'GVRAMTST.ASM'
    & $asw '-cpu' 'z80' '-L' $asm
    if($LASTEXITCODE -ne 0) {
        throw "ASW failed for GVRAMTST.ASM with exit code $LASTEXITCODE"
    }

    $obj = Join-Path $srcDir 'GVRAMTST.p'
    $raw = Join-Path $outDir 'GVRAMTST.raw'
    $com = Join-Path $outDir 'GVRAMTST.COM'
    $p2binOutput = & $p2bin $obj $raw '-r' '0x0100-0xffff' 2>&1
    $p2binOutput | ForEach-Object { Write-Host $_ }
    if($LASTEXITCODE -ne 0) {
        throw "p2bin failed for GVRAMTST.p with exit code $LASTEXITCODE"
    }
    $match = [regex]::Match(($p2binOutput | Out-String), '\((\d+)\s+Bytes\)')
    if(!$match.Success) {
        throw 'Could not determine GVRAMTST.COM payload size.'
    }
    $payloadLength = [int]$match.Groups[1].Value
    $rawBytes = [IO.File]::ReadAllBytes($raw)
    $comBytes = New-Object byte[] $payloadLength
    [Array]::Copy($rawBytes, 0, $comBytes, 0, $payloadLength)
    [IO.File]::WriteAllBytes($com, $comBytes)
    Remove-Item -LiteralPath $raw,$obj -Force -ErrorAction SilentlyContinue
    Write-Host "Built $com ($payloadLength bytes)"
}
finally {
    Pop-Location
}

Copy-Item -LiteralPath $baseImage -Destination $outImage -Force

powershell -ExecutionPolicy Bypass -File $diskEditor -Image $outImage -Command Import -Path (Join-Path $outDir 'GVRAMTST.COM') -Name 'GVRAMTST.COM' -Force
powershell -ExecutionPolicy Bypass -File $diskEditor -Image $outImage -Command Import -Path (Join-Path $srcDir 'README.TXT') -Name 'README.TXT' -Force

Write-Host "Generated $outImage"
Write-Host 'This image is not copied to the emulator Debug directory and is not used for auto-insert.'
