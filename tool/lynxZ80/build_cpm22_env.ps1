 $zipPath = 'build\arch\cpm22-b.zip'
 $destination = 'build\bin\cpmutil'
 $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
 $fileNames = @(
	 'ASM.COM', 'DDT.COM', 'DUMP.COM', 'ED.COM', 'LOAD.COM',
	 'PIP.COM', 'STAT.COM', 'SUBMIT.COM', 'XSUB.COM'
 )

try {
	New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
	New-Item -ItemType Directory -Path $destination -Force | Out-Null
	Expand-Archive -LiteralPath $zipPath -DestinationPath $temporaryDirectory -Force

	foreach ($fileName in $fileNames) {
		$file = Get-ChildItem -Path $temporaryDirectory -Filter $fileName -File -Recurse |
			Select-Object -First 1

		if ($null -eq $file) {
			throw "ZIP内にファイルが見つかりません: $fileName"
		}

		Move-Item -LiteralPath $file.FullName -Destination (Join-Path $destination $fileName) -Force
	}
}
finally {
	if (Test-Path -LiteralPath $temporaryDirectory) {
		Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
	}
}
$zipPath = 'build\arch\cpm2-asm.zip'
$destination = 'build\cpm22_runtime\CPM22.Z80'
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())

try {
	New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
	Expand-Archive -LiteralPath $zipPath -DestinationPath $temporaryDirectory -Force

	$file = Get-ChildItem -Path $temporaryDirectory -Filter 'CPM22.Z80' -File -Recurse |
		Select-Object -First 1

	if ($null -eq $file) {
		throw 'ZIP内にファイルが見つかりません: CPM22.Z80'
	}

	New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
	Get-Content -LiteralPath $file.FullName -Raw | Set-Content -LiteralPath $destination
}
finally {
	if (Test-Path -LiteralPath $temporaryDirectory) {
		Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
	}
}

git apply --no--index --directory=build\cpm22_runtime build\cpm22_runtime\patch.diff

$fileNames = @(
	 'CLS', 'DISKCOPY', 'FORMAT', 'MOVCPM5'
)

foreach ($fileName in $fileNames) {
	$source = Join-Path 'build\util' $fileName
	$destination = Join-Path 'build\bin\cpmutil' $fileName

	if (-not (Test-Path -LiteralPath $source)) {
		throw "ファイルが見つかりません: $source"
	}

	asw -cpu Z80 -L $source.asm
	p2bin $source.p $source.com -r $-$
	Remove-Item -LiteralPath $source.p -Force
	Move-Item -LiteralPath $source.com -Destination $destination -Force
}