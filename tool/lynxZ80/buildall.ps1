$ErrorActionPreference = 'Stop'

$ReqFileName = @("cpm2-asm.zip", "cpm22-b.zip")
$asw = 'asw.exe'
$p2bin = 'p2bin.exe'

function Test-SrcArchive {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir
    )

$missing = @()
    foreach ($name in $ReqFileName) {
        $path = Join-Path -Path $SourceDir -ChildPath $name
        if (-not (Test-Path -Path $path -PathType Leaf)) {
            $missing += $name
        }
    }

if ($missing.Count -gt 0) {
        Write-Error "次のアーカイブが見つかりません: $($missing -join ', ')"
        return $false
    }
    return $true
}

Write-Host $ReqFileName
Write-Host "以上のファイルが存在するか確認しています"
if (-not (Test-SrcArchive "$PSScriptRoot\build\arch")) {
    Write-Error "抜けているファイルがあるため、ビルドを中止しました"
    exit 1
}

Write-Host "ASW/P2BINが存在するか確認しています"
$missingTools = @($asw, $p2bin) | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) }
if ($missingTools.Count -gt 0) {
    Write-Error "PATH上の必須ツールが見つからないため、ビルドを中止しました: $($missingTools -join ', ')"
    exit 1
}

# ビルドスクリプトを順番に実行
& (Join-Path $PSScriptRoot "build_biosrom.ps1")
& (Join-Path $PSScriptRoot "build_subcpu_rom.ps1")
& (Join-Path $PSScriptRoot "ROMCPY.ps1")
& (Join-Path $PSScriptRoot "build_cpm22_disk.ps1")
& (Join-Path $PSScriptRoot "build_cpm_utils.ps1")
