# Lynx Emulator 'eLynxZ80' on Common Source Code Project

yosi coding with OpenAI Codex  
Version 1.0 Beta 1(260521)

## 1. これはなに？

'eLynxZ80'は、中島千明氏によるデュアル Z80 CP/M マシン "Lynx"を再現するエミュレータを、武田俊也氏による「Common Source Code Project」上にて実装したものです。

本パッケージには、Lynx用の仮想マシン実装、Visual Studio用プロジェクト、BIOS/サブCPU ROM、フォントROM、CP/M 2.2ディスクイメージを生成するための補助ツールが含まれています。

ほとんどのコードはCodex(AI)との共同作業によって作成しました。Lynx作者から提供を受けた資料は回路図のみで、FONT.ROMを除くROMのソースコードもAIとの共同作業によって作成しています。

「Common Source Code Project」については、[Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html)をご覧ください。

## 2. なぜちがうなまえ？

本機の正式な題材は、中島千明氏が製作したデュアル Z80 CP/M マシン "Lynx"です。ただし、"Lynx"という名称だけでは、ATARI LYNXや他の同名コンピュータ/エミュレータと混同される可能性があります。

そのため、本エミュレータでは「エミュレータ」であることを示す "e" と、対象機の中核である Z80 を組み合わせ、配布名を 'eLynxZ80' としました。ソースツリーやプロジェクト名には歴史的な都合で "LynxZ80"、"lynxz80" などの表記も残っていますが、いずれも同じエミュレータを指します。

オリジナルのLynxについては、作者ページ「[デュアル Z80 CP/Mマシン [Lynx]](https://www.chiaki.cc/Lynx/index.htm)」をご覧ください。

## 3. なにがいる？

'eLynxZ80'の動作には、以下のものが必要です。

### 3.1 ハードウェア

Windows 10以降 32/64bit版での動作を想定しています。

### 3.2 実行ファイルとROMイメージファイル

エミュレータを起動するには、以下のファイルを実行ファイル `lynxz80.exe` と同じフォルダに置きます。

- `IPL.ROM`  
  メインCPU用IPL/BIOS ROMです。
- `SUBCPU.ROM`  
  サブCPU用ROMです。
- `FONT.ROM`  
  表示用フォントROMです。ファイルが存在しない場合、内蔵の初期値で動作しますが、正しい表示には生成済みファイルの配置を推奨します。

### 3.3 ディスクイメージファイル

CP/M 2.2を起動する場合は、生成済みディスクイメージ `CPM22_SYSTEM.IMG` をフロッピーディスクとして挿入します。

本体は2ドライブ構成を想定しています。

## 4. なにをおす？

'eLynxZ80'は、PCキーボード入力をシリアル入力として扱います。

| キー | 入力 |
| - | - |
| `A-Z` | 英字キー |
| `0-9` | 数字キー |
| `Enter` | CR |
| `BackSpace` | BS |
| `Tab` | HT |
| `Esc` | ESC |
| `Space` | Space |
| `Delete` | DEL |
| `Ctrl+A` - `Ctrl+Z` | コントロールコード |

記号キーはUS配列相当のASCII文字に変換されます。Caps LockおよびKana Lockの状態もエミュレータ側で保持されます。

## 5. びるどする？

このパッケージに含まれるソースは、「Common Source Code Project」のソースの上に重ねて配置することで、ビルドを行うことができます。`vc++2017/lynxz80.vcxproj` をVisual Studioで開いてください。

配布時のプロジェクト設定では、以下の環境を想定しています。

- Visual Studio 2019 / Build Tools 2019
- Platform Toolset `v141`
- Windows 10 SDK `10.0.18362.0`
- `winmm.lib` / `imm32.lib`

ROMやCP/Mディスクイメージを生成する場合は、以下のツールが必要です。

- Windows PowerShell
- Macro Assembler AS (`asw.exe`)
- `p2bin.exe`

ASは以下から入手できます。

- [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/)

補助スクリプトは `tool/lynxZ80` 以下にあります。

| スクリプト | 内容 |
| - | - |
| `buildall.ps1` | BIOS ROM、サブCPU ROM、CP/M 2.2ディスク、CP/Mユーティリティを順に生成します。 |
| `build_biosrom.ps1` | `src/vm/Lynxz80/build/IPL.ROM` を生成します。 |
| `build_subcpu_rom.ps1` | `src/vm/Lynxz80/build/SUBCPU.ROM` を生成します。 |
| `build_fontrom.ps1` | `src/vm/Lynxz80/build/font/FONT.ROM` を生成します。 |
| `ROMCPY.ps1` | 生成済みROMを `vc++2017/bin/x86/Debug` または `vc++2017/bin/x86/Release` へコピーします。 |

CP/M 2.2ディスク生成には、別途 `cpm2-asm.zip` および `cpm22-b.zip` が必要です。これらは `tool/lynxZ80/build/arch` に配置します。

CP/M関連ファイルは以下から入手できます。

- [The Unofficial CP/M Web Site](http://www.cpm.z80.de/)

Lynx本体については、以下も参照してください。

- [放課後の電子工作　～　会社でハンダ付け、自宅でもハンダ付け　～](https://www.chiaki.cc/)
- [デュアル Z80 CP/Mマシン [Lynx]](https://www.chiaki.cc/Lynx/index.htm)

## 6. 著作権表記

このパッケージには、「Common Source Code Project」を基盤とするソースファイルと、Lynx Z80向けに追加されたソースファイルが含まれています。

使用・再配布は、各ソースファイルの著作権表記、および「Common Source Code Project」管理者が定める方法・条件に従ってください。

CP/M 2.2関連の外部アーカイブおよび標準コマンド類は本パッケージとは別の権利条件に従います。利用者自身で正当な入手元と利用条件を確認してください。

## 7. 連絡先

X(旧Twitter): <https://x.com/yosi2112>

「Common Source Code Project」については、[Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html)をご覧ください。
