$ErrorActionPreference = 'Stop'

$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$diskDir = Join-Path $toolRoot 'build\cpm22disk'
$source = Join-Path $diskDir 'CPM22.Z80'
$outputName = 'CPM22_z80.ASM'
$output = Join-Path $diskDir $outputName
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $diskDir ("CPM22.Z80.original.$timestamp.bak")

if(!(Test-Path -LiteralPath $source)) {
    throw "Required source not found: $source"
}

New-Item -ItemType Directory -Force -Path $diskDir | Out-Null

Write-Host "Backing up original: $backup"
Copy-Item -LiteralPath $source -Destination $backup -Force

$originalText = [IO.File]::ReadAllText($source, [Text.Encoding]::ASCII)
$newline = if($originalText.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $originalText -split "`r?`n", -1
$replacementCount = 0

$convertedLines = foreach($line in $lines) {
    $commentIndex = $line.IndexOf(';')
    if($commentIndex -ge 0) {
        $codePart = $line.Substring(0, $commentIndex)
        $commentPart = $line.Substring($commentIndex)
    } else {
        $codePart = $line
        $commentPart = ''
    }

    $matches = [regex]::Matches($codePart, '(?<![A-Za-z0-9_.$?@])M(?![A-Za-z0-9_.$?@])')
    $replacementCount += $matches.Count
    $convertedCode = [regex]::Replace($codePart, '(?<![A-Za-z0-9_.$?@])M(?![A-Za-z0-9_.$?@])', '(HL)')
    $convertedCode + $commentPart
}

$convertedText = [string]::Join($newline, $convertedLines)

Write-Host "Replacing 8080 M register notation with Z80 (HL): $replacementCount occurrence(s)"
[IO.File]::WriteAllText($source, $convertedText, [Text.Encoding]::ASCII)

if(Test-Path -LiteralPath $output) {
    Write-Host "Removing existing output before rename: $output"
    Remove-Item -LiteralPath $output -Force
}

Rename-Item -LiteralPath $source -NewName $outputName

Write-Host "Done: $output"
Write-Host "Backup: $backup"
