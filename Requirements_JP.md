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
> 現行スクリプトではツールの探索方法が統一されていません。`build_ipl_rom.ps1` と `build_cpm22_runtime.ps1` は既定値として開発環境固有の `E:\aswcurr\bin\...` を使用します。`build_subcpu_rom.ps1` は `asw.exe` / `p2bin.exe` を相対名のまま `Test-Path` するため、PATH 上にあるだけでは事前確認を通過しません。実行前に各スクリプトのパス条件を使用環境に合わせてください。

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
| `IPL.ROM` | `tool/lynxZ80/bin/IPL.ROM` |
| `SUBCPU.ROM` | `src/vm/Lynxz80/build/SUBCPU.ROM` |
| `FONT.ROM` | `tool/lynxZ80/build/font/FONT.ROM` |
| `CPM22_RUNTIME.BIN` | `tool/lynxZ80/bin/CPM22_RUNTIME.BIN` |
| `CPM22_SYSTEM.2d` | `tool/lynxZ80/bin/CPM22_SYSTEM.2d` |

> [!NOTE]
> 出力先は現在、スクリプト間で完全には統一されていません。`ROMCPY.ps1` は `src/vm/Lynxz80/build/` にある `IPL.ROM` と `SUBCPU.ROM` を入力として扱います。詳細は [tool/lynxZ80/README.md](tool/lynxZ80/README.md) を参照してください。

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

この値は現行 `tool/lynxZ80/build/bios/bios.asm` の DPB と対応しています。

## 6. 既知の不整合

現行ツリーには、開発途中のパス変更に追随していない補助スクリプトがあります。

- `build_cpm22_env.ps1` は `build\util` および `build\bin\cpmutil` を参照しますが、現在のツリーではローカル CP/M ユーティリティのソースは `build/cpmutils/` にあります。
- `build_cpm22_system_disk.ps1` は標準コマンドの入力先として `tool/lynxZ80/bin/cpmutils/` を参照します。
- `diskeditor.ps1` は 77 tracks / 26 sectors / 128 bytes、1 KB block の旧ディスク形式を前提としており、現行の `CPM22_SYSTEM.2d` とは互換ではありません。
- `ROMCPY.ps1` と `build_ipl_rom.ps1` では `IPL.ROM` の既定出力・入力ディレクトリが一致していません。

これらはマニュアル上で隠さず、現行コードの状態として記載しています。
