<#
.SYNOPSIS
  ファイルまたはフォルダーを比較し、差分表示・パッチ生成・パッチ適用を行う PowerShell 製 diff/patch ツール。

.EXAMPLE
  .\PowerDiff.ps1 .\old.txt .\new.txt

.EXAMPLE
  .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch

.EXAMPLE
  .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old

.EXAMPLE
  .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
#>

param(
    [Parameter(Position = 0)]
    [string]$Left,

    [Parameter(Position = 1)]
    [string]$Right,

    [switch]$Recurse,
    [switch]$Content,
    [switch]$Hash,
    [switch]$IgnoreWhitespace,

    [ValidateRange(0, 50)]
    [int]$Context = 3,

    [string]$OutputPath,
    [switch]$NoColor,
    [switch]$ExitCode,

    [string]$PatchPath,
    [string]$ApplyPatch,
    [string]$TargetPath = ".",

    [switch]$NoBackup,
    [string]$BackupRoot,
    [switch]$Force
)

$script:OutLines = New-Object System.Collections.Generic.List[string]
$script:PatchLines = New-Object System.Collections.Generic.List[string]
$script:HasDifference = $false
$script:UseColor = (-not $NoColor) -and ([string]::IsNullOrWhiteSpace($OutputPath))
$script:BackupDir = $null
$script:BackedUpFiles = @{}

function Write-Diff {
    param(
        [string]$Text = "",
        [ValidateSet("Normal", "Header", "Add", "Remove", "Info", "Same")]
        [string]$Kind = "Normal"
    )

    $script:OutLines.Add($Text) | Out-Null

    if ($script:UseColor) {
        switch ($Kind) {
            "Header" { Write-Host $Text -ForegroundColor Cyan }
            "Add"    { Write-Host $Text -ForegroundColor Green }
            "Remove" { Write-Host $Text -ForegroundColor Red }
            "Info"   { Write-Host $Text -ForegroundColor Yellow }
            "Same"   { Write-Host $Text -ForegroundColor DarkGray }
            default  { Write-Host $Text }
        }
    }
    else {
        Write-Host $Text
    }
}

function Resolve-ExistingPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "パスが見つかりません: $Path"
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-FullPathSafe {
    param([string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $base = $BasePath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $baseUri = New-Object System.Uri($base)
    $fullUri = New-Object System.Uri($FullPath)

    return [System.Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($fullUri).ToString()
    ).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Test-BinaryFile {
    param([string]$Path)

    $bufferSize = 8192
    $buffer = New-Object byte[] $bufferSize

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $read = $stream.Read($buffer, 0, $bufferSize)
        for ($i = 0; $i -lt $read; $i++) {
            if ($buffer[$i] -eq 0) {
                return $true
            }
        }
        return $false
    }
    finally {
        $stream.Dispose()
    }
}

function Get-Sha256 {
    param([string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Normalize-Line {
    param([string]$Line)

    if ($IgnoreWhitespace) {
        return (($Line -replace '\s+', ' ').Trim())
    }

    return $Line
}

function Read-TextLines {
    param([string]$Path)

    try {
        return @(Get-Content -LiteralPath $Path -ErrorAction Stop)
    }
    catch {
        throw "テキストとして読み込めませんでした: $Path"
    }
}

function Write-TextLines {
    param(
        [string]$Path,
        [string[]]$Lines
    )

    $parent = Split-Path -Parent $Path

    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent | Out-Null
        }
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function New-LineDiffOperations {
    param(
        [string[]]$LeftLines,
        [string[]]$RightLines
    )

    $m = $LeftLines.Count
    $n = $RightLines.Count

    $maxCells = 4000000
    if (([int64]$m * [int64]$n) -gt $maxCells) {
        return $null
    }

    $leftNorm = New-Object System.Collections.Generic.List[string]
    foreach ($line in $LeftLines) {
        $leftNorm.Add((Normalize-Line $line)) | Out-Null
    }

    $rightNorm = New-Object System.Collections.Generic.List[string]
    foreach ($line in $RightLines) {
        $rightNorm.Add((Normalize-Line $line)) | Out-Null
    }

    $dp = New-Object 'int[][]' ($m + 1)
    for ($i = 0; $i -le $m; $i++) {
        $dp[$i] = New-Object 'int[]' ($n + 1)
    }

    for ($i = $m - 1; $i -ge 0; $i--) {
        for ($j = $n - 1; $j -ge 0; $j--) {
            if ($leftNorm[$i] -eq $rightNorm[$j]) {
                $dp[$i][$j] = $dp[$i + 1][$j + 1] + 1
            }
            elseif ($dp[$i + 1][$j] -ge $dp[$i][$j + 1]) {
                $dp[$i][$j] = $dp[$i + 1][$j]
            }
            else {
                $dp[$i][$j] = $dp[$i][$j + 1]
            }
        }
    }

    $ops = New-Object System.Collections.Generic.List[object]
    $li = 0
    $ri = 0

    while (($li -lt $m) -and ($ri -lt $n)) {
        if ($leftNorm[$li] -eq $rightNorm[$ri]) {
            $ops.Add([pscustomobject]@{
                Op        = " "
                LeftLine  = $li + 1
                RightLine = $ri + 1
                Text      = $LeftLines[$li]
            }) | Out-Null
            $li++
            $ri++
        }
        elseif ($dp[$li + 1][$ri] -ge $dp[$li][$ri + 1]) {
            $ops.Add([pscustomobject]@{
                Op        = "-"
                LeftLine  = $li + 1
                RightLine = $null
                Text      = $LeftLines[$li]
            }) | Out-Null
            $li++
        }
        else {
            $ops.Add([pscustomobject]@{
                Op        = "+"
                LeftLine  = $null
                RightLine = $ri + 1
                Text      = $RightLines[$ri]
            }) | Out-Null
            $ri++
        }
    }

    while ($li -lt $m) {
        $ops.Add([pscustomobject]@{
            Op        = "-"
            LeftLine  = $li + 1
            RightLine = $null
            Text      = $LeftLines[$li]
        }) | Out-Null
        $li++
    }

    while ($ri -lt $n) {
        $ops.Add([pscustomobject]@{
            Op        = "+"
            LeftLine  = $null
            RightLine = $ri + 1
            Text      = $RightLines[$ri]
        }) | Out-Null
        $ri++
    }

    return $ops
}

function New-UnifiedPatchForLines {
    param(
        [string[]]$LeftLines,
        [string[]]$RightLines,
        [string]$LeftName,
        [string]$RightName
    )

    $ops = New-LineDiffOperations -LeftLines $LeftLines -RightLines $RightLines

    if ($null -eq $ops) {
        return @()
    }

    $changeIndexes = @()
    for ($i = 0; $i -lt $ops.Count; $i++) {
        if ($ops[$i].Op -ne " ") {
            $changeIndexes += $i
        }
    }

    if ($changeIndexes.Count -eq 0) {
        return @()
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("--- $LeftName") | Out-Null
    $lines.Add("+++ $RightName") | Out-Null

    $ranges = @()
    $current = $null

    foreach ($idx in $changeIndexes) {
        $start = [Math]::Max(0, $idx - $Context)
        $end = [Math]::Min($ops.Count - 1, $idx + $Context)

        if ($null -eq $current) {
            $current = [pscustomobject]@{ Start = $start; End = $end }
        }
        elseif ($start -le ($current.End + 1)) {
            if ($end -gt $current.End) {
                $current.End = $end
            }
        }
        else {
            $ranges += $current
            $current = [pscustomobject]@{ Start = $start; End = $end }
        }
    }

    if ($null -ne $current) {
        $ranges += $current
    }

    foreach ($range in $ranges) {
        $hunk = @($ops[$range.Start..$range.End])

        $leftNums = @($hunk | Where-Object { $_.Op -ne "+" -and $null -ne $_.LeftLine } | Select-Object -ExpandProperty LeftLine)
        $rightNums = @($hunk | Where-Object { $_.Op -ne "-" -and $null -ne $_.RightLine } | Select-Object -ExpandProperty RightLine)

        $leftCount = @($hunk | Where-Object { $_.Op -ne "+" }).Count
        $rightCount = @($hunk | Where-Object { $_.Op -ne "-" }).Count

        if ($leftCount -eq 0) {
            $leftStart = 0
        }
        else {
            $leftStart = ($leftNums | Measure-Object -Minimum).Minimum
        }

        if ($rightCount -eq 0) {
            $rightStart = 0
        }
        else {
            $rightStart = ($rightNums | Measure-Object -Minimum).Minimum
        }

        $lines.Add(("@@ -{0},{1} +{2},{3} @@" -f $leftStart, $leftCount, $rightStart, $rightCount)) | Out-Null

        foreach ($op in $hunk) {
            $lines.Add(("{0}{1}" -f $op.Op, $op.Text)) | Out-Null
        }
    }

    return @($lines)
}

function Add-PatchForTextFiles {
    param(
        [string[]]$LeftLines,
        [string[]]$RightLines,
        [string]$LeftName,
        [string]$RightName
    )

    $patch = New-UnifiedPatchForLines `
        -LeftLines $LeftLines `
        -RightLines $RightLines `
        -LeftName $LeftName `
        -RightName $RightName

    foreach ($line in $patch) {
        $script:PatchLines.Add($line) | Out-Null
    }
}

function Show-FileDiff {
    param(
        [string]$LeftFile,
        [string]$RightFile,
        [string]$DisplayName = "",
        [string]$PatchLeftName = "",
        [string]$PatchRightName = ""
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = "$LeftFile <-> $RightFile"
    }

    if ([string]::IsNullOrWhiteSpace($PatchLeftName)) {
        $PatchLeftName = "a/$([System.IO.Path]::GetFileName($LeftFile))"
    }

    if ([string]::IsNullOrWhiteSpace($PatchRightName)) {
        $PatchRightName = "b/$([System.IO.Path]::GetFileName($RightFile))"
    }

    Write-Diff ""
    Write-Diff "=== $DisplayName ===" "Header"

    if ((Test-BinaryFile $LeftFile) -or (Test-BinaryFile $RightFile)) {
        $leftHash = Get-Sha256 $LeftFile
        $rightHash = Get-Sha256 $RightFile

        if ($leftHash -eq $rightHash) {
            Write-Diff "バイナリ一致: $DisplayName" "Same"
        }
        else {
            $script:HasDifference = $true
            Write-Diff "バイナリ差分あり: $DisplayName" "Info"
            Write-Diff "- Left  SHA256: $leftHash" "Remove"
            Write-Diff "+ Right SHA256: $rightHash" "Add"

            if (-not [string]::IsNullOrWhiteSpace($PatchPath)) {
                Write-Diff "パッチ生成はスキップしました: バイナリファイルは未対応です。" "Info"
            }
        }

        return
    }

    $leftLines = Read-TextLines $LeftFile
    $rightLines = Read-TextLines $RightFile

    if (-not [string]::IsNullOrWhiteSpace($PatchPath)) {
        Add-PatchForTextFiles `
            -LeftLines $leftLines `
            -RightLines $rightLines `
            -LeftName $PatchLeftName `
            -RightName $PatchRightName
    }

    $ops = New-LineDiffOperations -LeftLines $leftLines -RightLines $rightLines

    if ($null -eq $ops) {
        $leftHash = Get-Sha256 $LeftFile
        $rightHash = Get-Sha256 $RightFile

        if ($leftHash -eq $rightHash) {
            Write-Diff "一致: $DisplayName" "Same"
        }
        else {
            $script:HasDifference = $true
            Write-Diff "差分あり: $DisplayName" "Info"
            Write-Diff "ファイルが大きいため、行単位の詳細比較は省略しました。" "Info"
            Write-Diff "- Left  SHA256: $leftHash" "Remove"
            Write-Diff "+ Right SHA256: $rightHash" "Add"
        }

        return
    }

    $changeIndexes = @()
    for ($i = 0; $i -lt $ops.Count; $i++) {
        if ($ops[$i].Op -ne " ") {
            $changeIndexes += $i
        }
    }

    if ($changeIndexes.Count -eq 0) {
        Write-Diff "差分はありません。" "Same"
        return
    }

    $script:HasDifference = $true

    Write-Diff "--- $LeftFile" "Remove"
    Write-Diff "+++ $RightFile" "Add"

    $ranges = @()
    $current = $null

    foreach ($idx in $changeIndexes) {
        $start = [Math]::Max(0, $idx - $Context)
        $end = [Math]::Min($ops.Count - 1, $idx + $Context)

        if ($null -eq $current) {
            $current = [pscustomobject]@{ Start = $start; End = $end }
        }
        elseif ($start -le ($current.End + 1)) {
            if ($end -gt $current.End) {
                $current.End = $end
            }
        }
        else {
            $ranges += $current
            $current = [pscustomobject]@{ Start = $start; End = $end }
        }
    }

    if ($null -ne $current) {
        $ranges += $current
    }

    foreach ($range in $ranges) {
        $hunk = @($ops[$range.Start..$range.End])

        $leftNums = @($hunk | Where-Object { $_.Op -ne "+" -and $null -ne $_.LeftLine } | Select-Object -ExpandProperty LeftLine)
        $rightNums = @($hunk | Where-Object { $_.Op -ne "-" -and $null -ne $_.RightLine } | Select-Object -ExpandProperty RightLine)

        $leftStart = 1
        $rightStart = 1

        if ($leftNums.Count -gt 0) {
            $leftStart = ($leftNums | Measure-Object -Minimum).Minimum
        }

        if ($rightNums.Count -gt 0) {
            $rightStart = ($rightNums | Measure-Object -Minimum).Minimum
        }

        $leftCount = @($hunk | Where-Object { $_.Op -ne "+" }).Count
        $rightCount = @($hunk | Where-Object { $_.Op -ne "-" }).Count

        Write-Diff ""
        Write-Diff ("@@ -{0},{1} +{2},{3} @@" -f $leftStart, $leftCount, $rightStart, $rightCount) "Header"
        Write-Diff ("   {0,6} {1,6} | {2}" -f "Left", "Right", "Text") "Header"

        foreach ($op in $hunk) {
            switch ($op.Op) {
                " " {
                    Write-Diff ("   {0,6} {1,6} | {2}" -f $op.LeftLine, $op.RightLine, $op.Text) "Same"
                }
                "-" {
                    Write-Diff ("-  {0,6} {1,6} | {2}" -f $op.LeftLine, "", $op.Text) "Remove"
                }
                "+" {
                    Write-Diff ("+  {0,6} {1,6} | {2}" -f "", $op.RightLine, $op.Text) "Add"
                }
            }
        }
    }
}

function Get-DirectoryFileMap {
    param([string]$Root)

    $map = @{}
    $files = Get-ChildItem -LiteralPath $Root -File -Recurse:$Recurse

    foreach ($file in $files) {
        $rel = Get-RelativePath -BasePath $Root -FullPath $file.FullName
        $map[$rel] = $file
    }

    return $map
}

function Compare-Directories {
    param(
        [string]$LeftDir,
        [string]$RightDir
    )

    Write-Diff "=== フォルダー比較 ===" "Header"
    Write-Diff "Left : $LeftDir"
    Write-Diff "Right: $RightDir"

    $leftMap = Get-DirectoryFileMap $LeftDir
    $rightMap = Get-DirectoryFileMap $RightDir

    $allKeys = @($leftMap.Keys + $rightMap.Keys | Sort-Object -Unique)

    $onlyLeft = 0
    $onlyRight = 0
    $changed = 0
    $same = 0

    foreach ($key in $allKeys) {
        $inLeft = $leftMap.ContainsKey($key)
        $inRight = $rightMap.ContainsKey($key)

        $patchRel = ($key -replace '\\', '/')

        if ($inLeft -and -not $inRight) {
            $script:HasDifference = $true
            $onlyLeft++
            Write-Diff "- $key" "Remove"

            if (-not [string]::IsNullOrWhiteSpace($PatchPath)) {
                $leftFile = $leftMap[$key].FullName

                if (Test-BinaryFile $leftFile) {
                    Write-Diff "  パッチ生成スキップ: バイナリ削除 $key" "Info"
                }
                else {
                    Add-PatchForTextFiles `
                        -LeftLines (Read-TextLines $leftFile) `
                        -RightLines @() `
                        -LeftName "a/$patchRel" `
                        -RightName "/dev/null"
                }
            }

            continue
        }

        if (-not $inLeft -and $inRight) {
            $script:HasDifference = $true
            $onlyRight++
            Write-Diff "+ $key" "Add"

            if (-not [string]::IsNullOrWhiteSpace($PatchPath)) {
                $rightFile = $rightMap[$key].FullName

                if (Test-BinaryFile $rightFile) {
                    Write-Diff "  パッチ生成スキップ: バイナリ追加 $key" "Info"
                }
                else {
                    Add-PatchForTextFiles `
                        -LeftLines @() `
                        -RightLines (Read-TextLines $rightFile) `
                        -LeftName "/dev/null" `
                        -RightName "b/$patchRel"
                }
            }

            continue
        }

        $lf = $leftMap[$key]
        $rf = $rightMap[$key]

        $isChanged = $false

        if ($Hash -or $Content -or -not [string]::IsNullOrWhiteSpace($PatchPath)) {
            $isChanged = ((Get-Sha256 $lf.FullName) -ne (Get-Sha256 $rf.FullName))
        }
        else {
            $timeDiff = [Math]::Abs(($lf.LastWriteTimeUtc - $rf.LastWriteTimeUtc).TotalSeconds)

            if (($lf.Length -ne $rf.Length) -or ($timeDiff -gt 1)) {
                $isChanged = $true
            }
        }

        if ($isChanged) {
            $script:HasDifference = $true
            $changed++
            Write-Diff "~ $key" "Info"

            if ($Content -or -not [string]::IsNullOrWhiteSpace($PatchPath)) {
                Show-FileDiff `
                    -LeftFile $lf.FullName `
                    -RightFile $rf.FullName `
                    -DisplayName $key `
                    -PatchLeftName "a/$patchRel" `
                    -PatchRightName "b/$patchRel"
            }
        }
        else {
            $same++
        }
    }

    Write-Diff ""
    Write-Diff "=== Summary ===" "Header"
    Write-Diff "Only Left : $onlyLeft"
    Write-Diff "Only Right: $onlyRight"
    Write-Diff "Changed   : $changed"
    Write-Diff "Same      : $same"
}

function Save-Outputs {
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $fullOutput = [System.IO.Path]::GetFullPath($OutputPath)
        Write-TextLines -Path $fullOutput -Lines ([string[]]$script:OutLines)

        Write-Host ""
        Write-Host "出力しました: $fullOutput"
    }

    if (-not [string]::IsNullOrWhiteSpace($PatchPath)) {
        $fullPatch = [System.IO.Path]::GetFullPath($PatchPath)
        Write-TextLines -Path $fullPatch -Lines ([string[]]$script:PatchLines)

        Write-Host ""
        Write-Host "パッチを出力しました: $fullPatch"
    }
}

function Convert-PatchHeaderToRelativePath {
    param([string]$HeaderPath)

    if ($HeaderPath -eq "/dev/null") {
        return $null
    }

    $p = $HeaderPath.Trim()

    if ($p.StartsWith("a/") -or $p.StartsWith("b/")) {
        $p = $p.Substring(2)
    }

    $p = $p -replace '/', [System.IO.Path]::DirectorySeparatorChar

    return $p
}

function Resolve-SafePatchTargetPath {
    param(
        [string]$Root,
        [string]$HeaderPath
    )

    $rel = Convert-PatchHeaderToRelativePath $HeaderPath

    if ($null -eq $rel) {
        return $null
    }

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath((Join-Path $Root $rel))

    if (-not $full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "安全のため、対象フォルダー外へのパッチ適用を拒否しました: $HeaderPath"
    }

    return $full
}

function Ensure-BackupDirectory {
    param([string]$Root)

    if ($NoBackup) {
        return $null
    }

    if ($null -ne $script:BackupDir) {
        return $script:BackupDir
    }

    if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:BackupDir = Join-Path $Root ".PowerDiffBackup\$stamp"
    }
    else {
        $script:BackupDir = [System.IO.Path]::GetFullPath($BackupRoot)
    }

    if (-not (Test-Path -LiteralPath $script:BackupDir)) {
        New-Item -ItemType Directory -Path $script:BackupDir | Out-Null
    }

    return $script:BackupDir
}

function Backup-FileIfNeeded {
    param(
        [string]$FilePath,
        [string]$Root
    )

    if ($NoBackup) {
        return
    }

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return
    }

    $full = [System.IO.Path]::GetFullPath($FilePath)

    if ($script:BackedUpFiles.ContainsKey($full)) {
        return
    }

    $backupDir = Ensure-BackupDirectory -Root $Root
    $rel = Get-RelativePath -BasePath $Root -FullPath $full
    $dest = Join-Path $backupDir $rel
    $parent = Split-Path -Parent $dest

    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }

    Copy-Item -LiteralPath $full -Destination $dest -Force
    $script:BackedUpFiles[$full] = $true

    Write-Diff "バックアップ: $full -> $dest" "Info"
}

function Read-UnifiedPatch {
    param([string]$PatchFile)

    $raw = @(Get-Content -LiteralPath $PatchFile -ErrorAction Stop)
    $files = New-Object System.Collections.Generic.List[object]
    $i = 0

    while ($i -lt $raw.Count) {
        $line = $raw[$i]

        if (-not $line.StartsWith("--- ")) {
            $i++
            continue
        }

        $oldHeader = $line.Substring(4).Trim()
        $i++

        if ($i -ge $raw.Count -or -not $raw[$i].StartsWith("+++ ")) {
            throw "不正なパッチです。+++ 行が見つかりません。"
        }

        $newHeader = $raw[$i].Substring(4).Trim()
        $i++

        $hunks = New-Object System.Collections.Generic.List[object]

        while ($i -lt $raw.Count -and -not $raw[$i].StartsWith("--- ")) {
            if (-not $raw[$i].StartsWith("@@ ")) {
                $i++
                continue
            }

            $header = $raw[$i]

            if ($header -notmatch '^@@ -(?<os>\d+)(,(?<oc>\d+))? \+(?<ns>\d+)(,(?<nc>\d+))? @@') {
                throw "不正な hunk ヘッダーです: $header"
            }

            $oldStart = [int]$Matches.os
            $oldCount = if ($Matches.oc) { [int]$Matches.oc } else { 1 }
            $newStart = [int]$Matches.ns
            $newCount = if ($Matches.nc) { [int]$Matches.nc } else { 1 }

            $i++

            $hunkLines = New-Object System.Collections.Generic.List[object]

            while (
                $i -lt $raw.Count -and
                -not $raw[$i].StartsWith("@@ ") -and
                -not $raw[$i].StartsWith("--- ")
            ) {
                $hunkLine = $raw[$i]

                if ($hunkLine.StartsWith("\ No newline at end of file")) {
                    $i++
                    continue
                }

                if ($hunkLine.Length -eq 0) {
                    throw "不正なパッチ行です。hunk 行は空行でも先頭に空白・+・- のいずれかが必要です。"
                }

                $op = $hunkLine.Substring(0, 1)

                if ($op -notin @(" ", "+", "-")) {
                    throw "不正なパッチ行です: $hunkLine"
                }

                $text = ""
                if ($hunkLine.Length -gt 1) {
                    $text = $hunkLine.Substring(1)
                }

                $hunkLines.Add([pscustomobject]@{
                    Op   = $op
                    Text = $text
                }) | Out-Null

                $i++
            }

            $hunks.Add([pscustomobject]@{
                OldStart = $oldStart
                OldCount = $oldCount
                NewStart = $newStart
                NewCount = $newCount
                Lines    = @($hunkLines)
            }) | Out-Null
        }

        $files.Add([pscustomobject]@{
            OldHeader = $oldHeader
            NewHeader = $newHeader
            Hunks     = @($hunks)
        }) | Out-Null
    }

    return @($files)
}

function Assert-PatchLineMatches {
    param(
        [string[]]$OriginalLines,
        [int]$Index,
        [string]$Expected,
        [string]$Path
    )

    if ($Index -ge $OriginalLines.Count) {
        throw "パッチ適用失敗: $Path の行数が不足しています。"
    }

    if ($OriginalLines[$Index] -ne $Expected) {
        $lineNo = $Index + 1
        throw "パッチ適用失敗: $Path の $lineNo 行目が一致しません。"
    }
}

function Invoke-ApplyHunks {
    param(
        [string[]]$OriginalLines,
        [object[]]$Hunks,
        [string]$PathForMessage
    )

    $result = New-Object System.Collections.Generic.List[string]
    $oldIndex = 0

    foreach ($hunk in $Hunks) {
        $hunkStart = if ($hunk.OldStart -eq 0) { 0 } else { $hunk.OldStart - 1 }

        if ($hunkStart -lt $oldIndex) {
            throw "パッチ適用失敗: hunk が重複しています。"
        }

        while ($oldIndex -lt $hunkStart) {
            if ($oldIndex -ge $OriginalLines.Count) {
                throw "パッチ適用失敗: $PathForMessage の行数が不足しています。"
            }

            $result.Add($OriginalLines[$oldIndex]) | Out-Null
            $oldIndex++
        }

        foreach ($line in $hunk.Lines) {
            switch ($line.Op) {
                " " {
                    Assert-PatchLineMatches `
                        -OriginalLines $OriginalLines `
                        -Index $oldIndex `
                        -Expected $line.Text `
                        -Path $PathForMessage

                    $result.Add($OriginalLines[$oldIndex]) | Out-Null
                    $oldIndex++
                }
                "-" {
                    Assert-PatchLineMatches `
                        -OriginalLines $OriginalLines `
                        -Index $oldIndex `
                        -Expected $line.Text `
                        -Path $PathForMessage

                    $oldIndex++
                }
                "+" {
                    $result.Add($line.Text) | Out-Null
                }
            }
        }
    }

    while ($oldIndex -lt $OriginalLines.Count) {
        $result.Add($OriginalLines[$oldIndex]) | Out-Null
        $oldIndex++
    }

    return @($result)
}

function Apply-UnifiedPatch {
    param(
        [string]$PatchFile,
        [string]$Root
    )

    $patchFull = Resolve-ExistingPath $PatchFile
    $rootFull = [System.IO.Path]::GetFullPath($Root)

    if (-not (Test-Path -LiteralPath $rootFull)) {
        New-Item -ItemType Directory -Path $rootFull | Out-Null
    }

    $filePatches = Read-UnifiedPatch -PatchFile $patchFull

    if ($filePatches.Count -eq 0) {
        Write-Diff "適用できるパッチがありません。" "Info"
        return
    }

    Write-Diff "=== パッチ適用 ===" "Header"
    Write-Diff "Patch : $patchFull"
    Write-Diff "Target: $rootFull"

    if ($NoBackup) {
        Write-Diff "自動バックアップ: OFF" "Info"
    }
    else {
        $dir = Ensure-BackupDirectory -Root $rootFull
        Write-Diff "自動バックアップ: ON"
        Write-Diff "Backup: $dir"
    }

    foreach ($fp in $filePatches) {
        $oldTarget = Resolve-SafePatchTargetPath -Root $rootFull -HeaderPath $fp.OldHeader
        $newTarget = Resolve-SafePatchTargetPath -Root $rootFull -HeaderPath $fp.NewHeader

        $isAdd = ($fp.OldHeader -eq "/dev/null")
        $isDelete = ($fp.NewHeader -eq "/dev/null")

        if ($isDelete) {
            $target = $oldTarget

            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                if ($Force) {
                    Write-Diff "削除対象なし、スキップ: $target" "Info"
                    continue
                }

                throw "削除対象ファイルが見つかりません: $target"
            }

            $original = Read-TextLines $target
            $after = Invoke-ApplyHunks `
                -OriginalLines $original `
                -Hunks $fp.Hunks `
                -PathForMessage $target

            Backup-FileIfNeeded -FilePath $target -Root $rootFull

            Remove-Item -LiteralPath $target -Force
            Write-Diff "- 削除: $target" "Remove"
            continue
        }

        $target = $newTarget

        if ($isAdd) {
            if ((Test-Path -LiteralPath $target -PathType Leaf) -and -not $Force) {
                throw "追加先ファイルが既に存在します。上書きする場合は -Force を指定してください: $target"
            }

            if (Test-Path -LiteralPath $target -PathType Leaf) {
                Backup-FileIfNeeded -FilePath $target -Root $rootFull
            }

            $original = @()
        }
        else {
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                throw "更新対象ファイルが見つかりません: $target"
            }

            Backup-FileIfNeeded -FilePath $target -Root $rootFull
            $original = Read-TextLines $target
        }

        $after = Invoke-ApplyHunks `
            -OriginalLines $original `
            -Hunks $fp.Hunks `
            -PathForMessage $target

        Write-TextLines -Path $target -Lines ([string[]]$after)

        if ($isAdd) {
            Write-Diff "+ 追加: $target" "Add"
        }
        else {
            Write-Diff "~ 更新: $target" "Info"
        }

        $script:HasDifference = $true
    }

    Write-Diff ""
    Write-Diff "パッチ適用が完了しました。" "Header"
}

try {
    if (-not [string]::IsNullOrWhiteSpace($ApplyPatch)) {
        Apply-UnifiedPatch -PatchFile $ApplyPatch -Root $TargetPath
    }
    else {
        if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
            throw "比較する場合は Left と Right を指定してください。パッチ適用の場合は -ApplyPatch を指定してください。"
        }

        $leftPath = Resolve-ExistingPath $Left
        $rightPath = Resolve-ExistingPath $Right

        $leftItem = Get-Item -LiteralPath $leftPath
        $rightItem = Get-Item -LiteralPath $rightPath

        if ($leftItem.PSIsContainer -and $rightItem.PSIsContainer) {
            Compare-Directories -LeftDir $leftItem.FullName -RightDir $rightItem.FullName
        }
        elseif ((-not $leftItem.PSIsContainer) -and (-not $rightItem.PSIsContainer)) {
            Show-FileDiff -LeftFile $leftItem.FullName -RightFile $rightItem.FullName
        }
        else {
            throw "比較対象は、両方ともファイル、または両方ともフォルダーである必要があります。"
        }
    }

    Save-Outputs

    if ($ExitCode) {
        if ($script:HasDifference) {
            exit 1
        }
        else {
            exit 0
        }
    }
}
catch {
    Write-Error $_.Exception.Message

    if ($ExitCode) {
        exit 2
    }
}
