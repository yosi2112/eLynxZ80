$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $toolRoot '..\..')).Path
$root = Join-Path $repoRoot 'src\vm\Lynxz80'
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'
$srcDir = Join-Path $root 'build\cpmutils'
$buildDir = Join-Path $root 'build'
$outDir = Join-Path $buildDir 'cpmutils'
$stdDir = Join-Path $srcDir 'std'
$defaultStdDir = Join-Path $toolRoot 'build\cpm22-b'
$image = Join-Path $buildDir 'CPM22_SYSTEM.IMG'
$diskEditor = Join-Path $toolRoot 'diskeditor.ps1'
$standardCommandNames = @(
    'ASM.COM',
    'DDT.COM',
    'DUMP.COM',
    'ED.COM',
    'LOAD.COM',
    'PIP.COM',
    'STAT.COM',
    'SUBMIT.COM',
    'XSUB.COM'
)
$localUtilityNames = @(
    'MOVCPM6.ASM',
    'DISKCOPY.ASM',
    'DUMP.ASM',
    'FORMAT.ASM'
)

foreach($tool in @($asw, $p2bin)) {
    if(!(Test-Path -LiteralPath $tool)) {
        throw "Required tool not found: $tool"
    }
}
foreach($path in @($srcDir, $image, $diskEditor)) {
    if(!(Test-Path -LiteralPath $path)) {
        throw "Required path not found: $path"
    }
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $stdDir | Out-Null

Push-Location $srcDir
try {
    foreach($asmName in $localUtilityNames) {
        $asm = Get-Item -LiteralPath (Join-Path $srcDir $asmName)
        $cpu = 'z80'
        & $asw '-cpu' $cpu '-L' $asm.FullName
        if($LASTEXITCODE -ne 0) {
            throw "ASW failed for $($asm.Name) with exit code $LASTEXITCODE"
        }

        $obj = Join-Path $srcDir ([IO.Path]::ChangeExtension($asm.Name, '.p'))
        $com = Join-Path $outDir ([IO.Path]::ChangeExtension($asm.Name, '.COM'))
        $raw = Join-Path $outDir ([IO.Path]::ChangeExtension($asm.Name, '.raw'))
        $p2binOutput = & $p2bin $obj $raw '-r' '0x0100-0xffff' 2>&1
        $p2binOutput | ForEach-Object { Write-Host $_ }
        if($LASTEXITCODE -ne 0) {
            throw "p2bin failed for $($asm.Name) with exit code $LASTEXITCODE"
        }

        $rawBytes = [IO.File]::ReadAllBytes($raw)
        $p2binText = ($p2binOutput | Out-String)
        $match = [regex]::Match($p2binText, '\((\d+)\s+Bytes\)')
        if(!$match.Success) {
            throw "Could not determine COM payload size for $($asm.Name)"
        }
        $payloadLength = [int]$match.Groups[1].Value
        if($payloadLength -le 0 -or $payloadLength -gt $rawBytes.Length) {
            throw "Invalid COM payload size $payloadLength for $($asm.Name)"
        }

        $comBytes = New-Object byte[] $payloadLength
        [Array]::Copy($rawBytes, 0, $comBytes, 0, $comBytes.Length)
        [IO.File]::WriteAllBytes($com, $comBytes)
        Remove-Item -LiteralPath $raw -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $obj -Force -ErrorAction SilentlyContinue
        Write-Host "Built $com ($($comBytes.Length) bytes)"
    }
}
finally {
    Pop-Location
}

$commands = @{}
foreach($com in Get-ChildItem -LiteralPath $outDir -Filter *.COM -File) {
    $commands[$com.Name.ToUpperInvariant()] = $com.FullName
}
if(Test-Path -LiteralPath $defaultStdDir) {
    foreach($name in $standardCommandNames) {
        $candidate = Join-Path $defaultStdDir $name
        if(Test-Path -LiteralPath $candidate) {
            $commands[$name] = $candidate
        }
    }
}
foreach($com in Get-ChildItem -LiteralPath $stdDir -Filter *.COM -File -ErrorAction SilentlyContinue) {
    $commands[$com.Name.ToUpperInvariant()] = $com.FullName
}

foreach($name in ($commands.Keys | Sort-Object)) {
    powershell -ExecutionPolicy Bypass -File $diskEditor -Image $image -Command Import -Path $commands[$name] -Name $name -Force
}
