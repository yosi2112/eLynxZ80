# eLynxZ80 ビルド要件

この文書は、eLynxZ80 本体、ROM、および CP/M 2.2 システムディスクをビルドするために必要な環境をまとめたものです。

## 1. エミュレータ本体

`vc++2017/lynxz80.vcxproj` に記録されている構成は次のとおりです。

| 項目 | 設定 |
| --- | --- |
| IDE / Build Tools | Visual Studio 2019 / Build Tools 2019 を想定 |
| Platform Toolset | `v141` |
| Windows SDK | `10.0.18362.0` |
| 構成 | Debug / Release |
| プラットフォーム | Win32 / x64 |
| 追加リンク | `winmm.lib`, `imm32.lib` |

### Common Source Code Project

本リポジトリには CSCP の共通ソース一式は含まれていません。

プロジェクトは、たとえば次のような CSCP 側のファイルを参照します。

```text
src/common.cpp
src/config.cpp
src/emu.cpp
src/fileio.cpp
src/vm/z80.cpp
src/vm/upd7220.cpp
src/win32/winmain.cpp
...
```

したがって、CSCP の対応するソースツリーへ eLynxZ80 のファイルを重ねて配置した状態でビルドしてください。

## 2. ROM / CP/M ビルドツール

補助スクリプトは Windows PowerShell で実行します。

主に次のツールを使用します。

| ツール | 用途 |
| --- | --- |
| Windows PowerShell / PowerShell | `.ps1` の実行 |
| Macro Assembler AS（`asw.exe`） | Z80 ソースのアセンブル |
| `p2bin.exe` | AS の出力を ROM / バイナリへ変換 |
| Git | `build_cpm22_env.ps1` 内の `git apply` |
| .NET `System.Drawing` | `build_fontrom.ps1` のフォント描画 |

> [!IMPORTANT]
> ROM / CP/M 用スクリプトは `asw.exe`、`p2bin.exe`、必要に応じて `git.exe` を PATH から検出します。`build_ipl_rom.ps1`、`build_subcpu_rom.ps1`、`build_cpm22_runtime.ps1`、`build_cpm22_env.ps1` では各ツールのパスを引数で明示指定することもできます。

## 3. 外部ファイル

### CP/M 2.2

`tool/lynxZ80/build/arch/` に次の 2 ファイルを配置します。

```text
cpm2-asm.zip
cpm22-b.zip
```

用途は次のとおりです。

| ファイル | 用途 |
| --- | --- |
| `cpm2-asm.zip` | CP/M 2.2 の `CPM22.Z80` を取得 |
| `cpm22-b.zip` | ASM、DDT、ED、LOAD、PIP、STAT、SUBMIT、XSUB などの標準コマンドを取得 |

これらのアーカイブは本リポジトリに含まれません。

### フォント

`build_fontrom.ps1` の既定値では次のフォントを使用します。

```text
tool/lynxZ80/build/font/KH-Dot-Dougenzaka-16.ttf
```

別の場所にあるフォントを使用する場合は `-FontPath` で指定できます。

## 4. 生成物

現行スクリプトの主な生成物は次のとおりです。

| 生成物 | 既定の出力先 |
| --- | --- |
| `IPL.ROM` | `tool/lynxZ80/bin/IPL.ROM` および `src/vm/Lynxz80/build/IPL.ROM` |
| `SUBCPU.ROM` | `tool/lynxZ80/bin/SUBCPU.ROM` および `src/vm/Lynxz80/build/SUBCPU.ROM` |
| `FONT.ROM` | `tool/lynxZ80/build/font/FONT.ROM` |
| `CPM22_RUNTIME.BIN` | `tool/lynxZ80/bin/CPM22_RUNTIME.BIN` |
| `CPM22_SYSTEM.2d` | `tool/lynxZ80/bin/CPM22_SYSTEM.2d` |

> [!NOTE]
> `IPL.ROM` と `SUBCPU.ROM` は `tool/lynxZ80/bin/` に共通出力を持ち、互換用として `src/vm/Lynxz80/build/` にもコピーされます。`ROMCPY.ps1` は共通出力を優先し、互換配置をフォールバックとして利用します。

## 5. CP/M 2.2 システムディスク仕様

`build_cpm22_system_disk.ps1` が生成する `CPM22_SYSTEM.2d` の形式は次のとおりです。

| 項目 | 値 |
| --- | ---: |
| シリンダ数 | 40 |
| 面数 | 2 |
| 1 面あたりセクタ数 | 16 |
| 物理セクタサイズ | 256 bytes |
| 総容量 | 327680 bytes |
| CP/M 論理 SPT | 64 × 128 bytes |
| 予約シリンダ | 2 |
| ブロックサイズ | 2048 bytes |
| ディレクトリエントリ | 128 |
| DSM | 151 |
| DRM | 127 |
| EXM | 1 |

この値は現行 `tool/lynxZ80/build/bios/bios.asm` の DPB と対応しています。

## 6. スクリプト互換性と補足

補助スクリプトは現行ディレクトリ構成へ更新されています。

- `build_cpm22_env.ps1` は `build/cpmutils/` を入力、`bin/cpmutils/` を出力として使用します。
- `build_cpm22_system_disk.ps1` と `diskeditor.ps1` は、現行 `CPM22_SYSTEM.2d` の 40-cylinder / 2-sided / 2048-byte-block / EXM=1 形式を共通に扱います。
- `diskeditor.ps1 -Format Legacy` を指定すると、従来の 77-track / 26-sector / 128-byte-sector / 1 KB block 形式も扱えます。
- `ROMCPY.ps1` は x86 / x64 と Debug / Release / Both を選択でき、`FONT.ROM` も存在すれば同時に配置します。

詳細は [tool/lynxZ80/README.md](tool/lynxZ80/README.md) を参照してください。
