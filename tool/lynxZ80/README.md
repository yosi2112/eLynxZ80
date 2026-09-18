# eLynxZ80 Build Tools

`tool/lynxZ80/` には、eLynxZ80 用 ROM、CP/M 2.2 ランタイム、システムディスクを生成・配置する PowerShell スクリプトがあります。

## 1. 前提ツール

主に次のツールを使用します。

| ツール | 用途 |
| --- | --- |
| Windows PowerShell / PowerShell | `.ps1` の実行 |
| Macro Assembler AS (`asw.exe`) | Z80 ソースのアセンブル |
| `p2bin.exe` | AS の出力を ROM / COM / バイナリへ変換 |
| Git | `build_cpm22_env.ps1` で CP/M ソースへパッチを適用 |
| .NET `System.Drawing` | `build_fontrom.ps1` のフォント描画 |

AS と p2bin は PATH から自動検出できます。対応するスクリプトでは `-AswPath`、`-P2BinPath` で明示指定もできます。`build_cpm22_env.ps1` の Git も PATH から検出し、必要なら `-GitPath` で指定できます。

## 2. スクリプト一覧

| スクリプト | 役割 | 主な出力 |
| --- | --- | --- |
| `build_ipl_rom.ps1` | IPL/BIOS ROM をアセンブル、検証、配置 | `bin/IPL.ROM`、`../../src/vm/Lynxz80/build/IPL.ROM` |
| `build_subcpu_rom.ps1` | サブ CPU ROM をアセンブル、検証 | `bin/SUBCPU.ROM`、`../../src/vm/Lynxz80/build/SUBCPU.ROM` |
| `build_fontrom.ps1` | TrueType フォントから文字 ROM を生成 | `build/font/FONT.ROM` |
| `build_cpm22_env.ps1` | CP/M 2.2 ソース、標準コマンド、ローカルユーティリティを準備 | `build/cpm22_runtime/CPM22.ASM`、`bin/cpmutils/*.COM` |
| `build_cpm22_runtime.ps1` | CCP + BDOS + resident BIOS を 8 KB にまとめる | `bin/CPM22_RUNTIME.BIN` |
| `build_cpm22_system_disk.ps1` | 起動可能な CP/M 2.2 ディスクを生成 | `bin/CPM22_SYSTEM.2d` |
| `ROMCPY.ps1` | ROM を Debug / Release 出力へコピー | `vc++2017/bin/<platform>/<configuration>/` |
| `diskeditor.ps1` | CP/M ディスク内のファイルを操作 | 指定したディスクイメージ |

すべての相対パスは、原則としてスクリプト自身の場所を基準に解決されます。別のカレントディレクトリから起動しても、リポジトリ内の入力・出力先は変わりません。

## 3. IPL/BIOS ROM

### build_ipl_rom.ps1

入力:

```text
tool/lynxZ80/build/bios/bios.asm
```

主な出力:

```text
tool/lynxZ80/bin/IPL.ROM
src/vm/Lynxz80/build/IPL.ROM
```

生成サイズは 8192 bytes です。

PATH 上に AS と p2bin がある場合:

```powershell
.\build_ipl_rom.ps1
```

明示指定する場合:

```powershell
.\build_ipl_rom.ps1 `
  -AswPath "C:\path\to\asw.exe" `
  -P2BinPath "C:\path\to\p2bin.exe"
```

既定では `vc++2017/bin/` 以下の `lynxz80.exe` を検索し、その隣にも `IPL.ROM` を配置します。`-NoDeploy` を指定すると、共通出力先への生成だけを行います。

既存 ROM のバックアップを不要とする場合は `-SkipBackup` を指定します。

## 4. サブ CPU ROM

### build_subcpu_rom.ps1

入力:

```text
src/vm/Lynxz80/build/subcpu/subcpurom.asm
```

出力:

```text
src/vm/Lynxz80/build/SUBCPU.ROM
tool/lynxZ80/bin/SUBCPU.ROM
```

生成サイズは 8192 bytes です。

```powershell
.\build_subcpu_rom.ps1
```

AS / p2bin は PATH から検出され、必要なら `-AswPath` / `-P2BinPath` で指定できます。2つの出力は SHA-256 で一致確認されます。

## 5. フォント ROM

### build_fontrom.ps1

既定入力:

```text
tool/lynxZ80/build/font/KH-Dot-Dougenzaka-16.ttf
```

既定出力:

```text
tool/lynxZ80/build/font/FONT.ROM
```

生成サイズは 8192 bytes です。

| オフセット | サイズ | 内容 |
| --- | ---: | --- |
| `0000h-0FFFh` | 4096 bytes | ANK / カタカナ |
| `1000h-1FFFh` | 4096 bytes | ANK / ひらがな |

```powershell
.\build_fontrom.ps1 -FontPath "C:\fonts\KH-Dot-Dougenzaka-16.ttf"
```

`-WriteBankFiles` を指定すると、各 4 KB バンクも個別ファイルとして保存します。

## 6. CP/M 2.2

### 6.1 外部アーカイブ

次のファイルを `build/arch/` に配置します。

```text
cpm2-asm.zip
cpm22-b.zip
```

### 6.2 build_cpm22_env.ps1

外部アーカイブを展開し、CP/M 2.2 ソースへ `patch.diff` を適用し、標準 CP/M コマンドと eLynxZ80 用ローカルユーティリティを `bin/cpmutils/` へ準備します。

```powershell
.\build_cpm22_env.ps1
```

必要に応じて:

```powershell
.\build_cpm22_env.ps1 `
  -AswPath "C:\path\to\asw.exe" `
  -P2BinPath "C:\path\to\p2bin.exe" `
  -GitPath "C:\Program Files\Git\cmd\git.exe"
```

ローカルユーティリティのソースは `build/cpmutils/*.ASM` を使用します。生成先は `bin/cpmutils/` に統一されています。

### 6.3 build_cpm22_runtime.ps1

入力:

```text
build/cpm22_runtime/CPM22.ASM
build/bios/bios.asm
```

出力:

```text
bin/CPM22_RUNTIME.BIN
```

生成サイズは 8192 bytes です。

```powershell
.\build_cpm22_runtime.ps1
```

AS / p2bin は PATH から検出され、必要なら `-AswPath` / `-P2BinPath` で指定できます。

### 6.4 build_cpm22_system_disk.ps1

既定入力:

```text
bin/CPM22_RUNTIME.BIN
bin/cpmutils/*.COM
```

既定出力:

```text
bin/CPM22_SYSTEM.2d
```

必要に応じて `-RuntimePath`、`-UtilitiesDir`、`-OutputPath` で変更できます。

現行ディスク形式:

| 項目 | 値 |
| --- | ---: |
| シリンダ | 40 |
| 面 | 2 |
| 1 面あたりセクタ数 | 16 |
| 物理セクタ | 256 bytes |
| 総容量 | 327680 bytes |
| システム予約 | 2 シリンダ |
| CP/M ブロック | 2048 bytes |
| ディレクトリエントリ | 128 |
| EXM | 1 |
| DSM | 151 |

COM ファイルの取り込みは EXM=1 を考慮し、1ファイルが1ディレクトリエントリに収まらない場合も複数エントリへ分割して格納します。`bin/cpmutils/` が存在しない場合は警告を表示し、ユーティリティなしの起動ディスクを生成します。

## 7. ROM の配置

### ROMCPY.ps1

例:

```powershell
.\ROMCPY.ps1 -Target Debug
.\ROMCPY.ps1 -Target Release
.\ROMCPY.ps1 -Target Both
.\ROMCPY.ps1 -Target Both -Platform x64
```

`IPL.ROM` と `SUBCPU.ROM` は `tool/lynxZ80/bin/` を優先し、互換用として `src/vm/Lynxz80/build/` も検索します。

`FONT.ROM` が存在する場合は同時にコピーします。必須扱いにする場合は `-RequireFont` を指定します。

診断 ROM:

```powershell
.\ROMCPY.ps1 -diag
.\ROMCPY.ps1 -diag -Platform x64
```

`-diag` は `DIAGMAIN.ROM` と `DIAGSUB.ROM` を Debug ディレクトリへ、それぞれ `IPL.ROM`、`SUBCPU.ROM` の名前で配置します。

## 8. diskeditor.ps1

既定では現行の `CPM22_SYSTEM.2d` 形式を扱います。

```powershell
.\diskeditor.ps1 -Image .\bin\CPM22_SYSTEM.2d -Command Info
.\diskeditor.ps1 -Image .\bin\CPM22_SYSTEM.2d -Command List
.\diskeditor.ps1 -Image .\bin\CPM22_SYSTEM.2d -Command Import -Path .\HELLO.COM
.\diskeditor.ps1 -Image .\bin\CPM22_SYSTEM.2d -Command Export -Name HELLO.COM
.\diskeditor.ps1 -Image .\bin\CPM22_SYSTEM.2d -Command Delete -Name HELLO.COM
```

現行形式では EXM=1 を考慮してファイルサイズと複数エントリを処理します。

旧ディスク形式も互換モードで利用できます。

```powershell
.\diskeditor.ps1 -Image .\legacy.img -Format Legacy -Command List
```

旧形式は 77 tracks / 26 sectors / 128 bytes、2 reserved tracks、1024 bytes/block、64 directory entries です。

## 9. 推奨ビルド順序

CP/M 2.2 システムディスクまで生成する場合の基本順序です。

```powershell
.\build_ipl_rom.ps1 -NoDeploy
.\build_subcpu_rom.ps1
.\build_fontrom.ps1
.\build_cpm22_env.ps1
.\build_cpm22_runtime.ps1
.\build_cpm22_system_disk.ps1
.\ROMCPY.ps1 -Target Both
```

外部アーカイブ、フォント、AS / p2bin、および Git は各工程より前に用意してください。

## 10. 診断・テスト用ソース

`build/diag/` にはメイン CPU / サブ CPU 用診断 ROM ソース、`build/gvramtest/` には CP/M 上から MINSUB 経由で Graphics GDC へコマンドを送るテストプログラムがあります。

GVRAM テストのプロキシコマンド:

```text
ESC G C xx    Graphics GDC command byte
ESC G P xx    Graphics GDC parameter byte
```

`xx` は 00h～FFh の 2 桁 ASCII 16 進数です。
