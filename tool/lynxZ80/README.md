# eLynxZ80 Build Tools

`tool/lynxZ80/` には、eLynxZ80 用 ROM、CP/M 2.2 ランタイム、システムディスクなどを生成する補助スクリプトがあります。

## 1. スクリプト一覧

| スクリプト | 役割 | 主な出力 |
| --- | --- | --- |
| `build_ipl_rom.ps1` | IPL/BIOS ROM をアセンブルし、検証・配置 | `bin/IPL.ROM` |
| `build_subcpu_rom.ps1` | サブ CPU ROM をアセンブル | `../../src/vm/Lynxz80/build/SUBCPU.ROM` |
| `build_fontrom.ps1` | TrueType フォントから文字 ROM を生成 | `build/font/FONT.ROM` |
| `build_cpm22_env.ps1` | CP/M 2.2 ソースとコマンドを展開・準備 | CP/M ソース、COM ファイル |
| `build_cpm22_runtime.ps1` | CCP + BDOS + resident BIOS を 8 KB にまとめる | `bin/CPM22_RUNTIME.BIN` |
| `build_cpm22_system_disk.ps1` | 起動可能な CP/M 2.2 ディスクを生成 | `bin/CPM22_SYSTEM.2d` |
| `ROMCPY.ps1` | ROM をエミュレータの Debug / Release 出力へコピー | `vc++2017/bin/x86/...` |
| `diskeditor.ps1` | 旧ディスク形式の CP/M ファイル操作 | 指定したイメージを更新 |

## 2. IPL/BIOS ROM

### build_ipl_rom.ps1

入力:

```text
tool/lynxZ80/build/bios/bios.asm
```

生成される ROM は 8192 bytes です。

既定値には開発環境固有のパスが含まれるため、通常は引数を指定して実行してください。

```powershell
.\build_ipl_rom.ps1 `
  -AswPath "C:\path\to\asw.exe" `
  -P2BinPath "C:\path\to\p2bin.exe" `
  -EmulatorBinRoot "C:\path\to\vc++2017\bin"
```

処理内容:

1. `bios.asm` を AS でアセンブルします。
2. `p2bin.exe` で 0000h～1FFFh の 8 KB ROM を生成します。
3. ROM サイズを検証します。
4. `tool/lynxZ80/bin/IPL.ROM` へコピーします。
5. `EmulatorBinRoot` 以下の `lynxz80.exe` を検索し、その隣へ `IPL.ROM` を配置します。
6. `-SkipBackup` を指定しない場合、既存 ROM と SHA-256 を `archive/` 以下へ退避します。

## 3. サブ CPU ROM

### build_subcpu_rom.ps1

入力:

```text
src/vm/Lynxz80/build/subcpu/subcpurom.asm
```

出力:

```text
src/vm/Lynxz80/build/SUBCPU.ROM
```

ROM サイズは 8192 bytes です。

このスクリプトは `asw.exe` と `p2bin.exe` を相対名のまま `Test-Path` で確認します。PATH 上にあるだけでは事前確認を通過しないため、実行時のカレントディレクトリに両ファイルを置くか、スクリプト側のパス指定を使用環境に合わせて変更してください。

## 4. フォント ROM

### build_fontrom.ps1

既定入力:

```text
tool/lynxZ80/build/font/KH-Dot-Dougenzaka-16.ttf
```

既定出力:

```text
tool/lynxZ80/build/font/FONT.ROM
```

生成される ROM は 8192 bytes で、次の 2 バンクから構成されます。

| オフセット | サイズ | 内容 |
| --- | ---: | --- |
| `0000h-0FFFh` | 4096 bytes | ANK / カタカナ |
| `1000h-1FFFh` | 4096 bytes | ANK / ひらがな |

使用例:

```powershell
.\build_fontrom.ps1 -FontPath "C:\fonts\KH-Dot-Dougenzaka-16.ttf"
```

`-WriteBankFiles` を指定すると、各 4 KB バンクも個別ファイルとして保存します。

## 5. CP/M 2.2

### 5.1 外部アーカイブ

次のファイルを `build/arch/` に配置します。

```text
cpm2-asm.zip
cpm22-b.zip
```

### 5.2 build_cpm22_env.ps1

このスクリプトは、外部アーカイブの展開、`CPM22.Z80` へのパッチ適用、標準コマンドとローカルユーティリティの準備を行う目的で用意されています。

ただし、現行ツリーでは一部の固定パスが実際のディレクトリ名と一致していません。具体的には `build\util`、`build\bin\cpmutil` を参照する箇所があります。

そのため、このスクリプトは現時点では「無変更で実行できる一括セットアップ」として扱わず、実行前にパスを確認してください。

### 5.3 build_cpm22_runtime.ps1

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

処理では CP/M の CCP / BDOS と eLynxZ80 用 resident BIOS を結合し、BIOS コード領域・cold boot 表示領域・BIOS ワーク領域の重なりを検証します。

このスクリプトも AS / p2bin の既定パスとして `E:\aswcurr\bin` を使用するため、別環境ではパスの変更が必要です。

### 5.4 build_cpm22_system_disk.ps1

入力:

```text
bin/CPM22_RUNTIME.BIN
bin/cpmutils/*.COM   （存在する場合）
```

出力:

```text
bin/CPM22_SYSTEM.2d
```

ディスク形式:

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

ランタイムはディスク先頭の予約領域へ書き込まれ、`bin/cpmutils/` に COM ファイルがあれば CP/M ディレクトリへ順次追加されます。

## 6. ROM の配置

### ROMCPY.ps1

通常 ROM:

```powershell
.\ROMCPY.ps1 -Target Debug
.\ROMCPY.ps1 -Target Release
```

診断 ROM:

```powershell
.\ROMCPY.ps1 -diag
```

`-diag` は `DIAGMAIN.ROM` と `DIAGSUB.ROM` を Debug ディレクトリへ、それぞれ `IPL.ROM`、`SUBCPU.ROM` の名前で配置します。

> [!IMPORTANT]
> `ROMCPY.ps1` は入力 ROM を `src/vm/Lynxz80/build/` から読みます。一方、`build_ipl_rom.ps1` の既定出力は `tool/lynxZ80/bin/IPL.ROM` です。現行では自動的に同じ場所へ揃う構成ではありません。

## 7. diskeditor.ps1

`diskeditor.ps1` は次のコマンドを備えています。

```text
Help
Info
List
Import
Export
Delete
```

ただし、このツールが前提とするディスク形式は次のとおりです。

```text
77 tracks
26 sectors/track
128 bytes/sector
2 reserved tracks
1024 bytes/block
64 directory entries
```

これは `build_cpm22_system_disk.ps1` が生成する現行 `CPM22_SYSTEM.2d` の形式とは異なります。現行システムディスクの編集には使用しないでください。

## 8. 診断・テスト用ソース

`build/diag/` にはメイン CPU / サブ CPU 用診断 ROM ソース、`build/gvramtest/` には CP/M 上から MINSUB 経由で Graphics GDC へコマンドを送るテストプログラムがあります。

GVRAM テストのプロキシコマンドは次の形式です。

```text
ESC G C xx    Graphics GDC command byte
ESC G P xx    Graphics GDC parameter byte
```

`xx` は 00h～FFh の 2 桁 ASCII 16 進数です。

## 9. 既知の注意事項

現状のツール群は、開発途中のディレクトリ変更と個別スクリプトの更新時期が一致していない部分があります。特に次の点を確認してください。

- AS / p2bin の指定方法がスクリプトごとに異なります。`build_subcpu_rom.ps1` は相対名を `Test-Path` するため、PATH 登録だけでは不足します。
- CP/M ユーティリティのディレクトリ名が `cpmutil` / `cpmutils`、`build/util` / `build/cpmutils` で混在しています。
- `IPL.ROM` の生成先と `ROMCPY.ps1` の入力先が一致していません。
- `diskeditor.ps1` は旧ディスク形式用です。

ビルド手順を自動化する場合は、これらのパスを統一してから使用することを推奨します。
