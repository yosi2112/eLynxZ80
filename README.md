# eLynxZ80

eLynxZ80 は、中島千明氏が製作したデュアル Z80 CP/M マシン「Lynx」を、武田俊也氏の Common Source Code Project（CSCP）上で再現するエミュレータです。

本リポジトリには、Lynx 固有の仮想マシン実装、Visual Studio プロジェクト、IPL/BIOS・サブ CPU ROM・フォント ROM・CP/M 2.2 システムディスクを生成するためのソースおよび補助ツールが含まれます。

## 概要

主な実装内容は次のとおりです。

- メイン CPU / サブ CPU: Z80
- メイン CPU クロック: 4 MHz
- メインメモリ: 64 KB
- IPL/BIOS ROM: 8 KB
- サブ CPU ROM: 8 KB
- サブ CPU RAM: 2 KB
- 表示: 640 × 400
- GDC: uPD7220 相当を文字表示用・グラフィック表示用に各 1 個
- FDC: MB8877 相当
- フロッピードライブ: 2 ドライブ、2D、300 rpm、FM
- Z80 SIO / CTC / DMA / PIO
- SIO-A 外部シリアル接続（COM1～COM4 または TCP 127.0.0.1:8023）
- ステート保存、デバッガ、画面フィルタ

実装上の表示更新レートは 56.42 fps です。

## リポジトリ構成

| パス | 内容 |
| --- | --- |
| `src/vm/Lynxz80/` | Lynx 固有の仮想マシン実装 |
| `src/vm/Lynxz80/docs/Programing Manual/` | プログラミング資料 |
| `tool/lynxZ80/` | ROM・CP/M イメージ生成などの補助ツール |
| `vc++2017/lynxz80.vcxproj` | Visual Studio プロジェクト |
| `Requirements_JP.md` | ビルドに必要なソフトウェアと外部データ |

> [!NOTE]
> `Programing Manual` はリポジトリ上の既存ディレクトリ名です。文書タイトルでは一般的な綴りの “Programming Manual” を使用しています。

## 動作に必要なファイル

エミュレータ本体 `lynxz80.exe` と同じディレクトリに、次の ROM を配置します。

| ファイル | サイズ | 用途 |
| --- | ---: | --- |
| `IPL.ROM` | 8192 bytes | メイン CPU 用 IPL/BIOS ROM |
| `SUBCPU.ROM` | 8192 bytes | サブ CPU 用 ROM |
| `FONT.ROM` | 8192 bytes | 文字表示用フォント ROM |

`IPL.ROM` または `SUBCPU.ROM` がない場合、エミュレータは暴走を避けるための安全な初期内容で起動しますが、Lynx としての通常動作は行えません。

`FONT.ROM` がない場合、文字パターンは描画されません。通常利用では `FONT.ROM` を用意してください。

CP/M 2.2 を起動する場合は、フロッピーディスクイメージも必要です。現行の生成スクリプトは次のファイルを生成します。

```text
tool/lynxZ80/bin/CPM22_SYSTEM.2d
```

## 起動手順

1. `lynxz80.exe` と同じディレクトリに `IPL.ROM`、`SUBCPU.ROM`、`FONT.ROM` を配置します。
2. エミュレータを起動します。
3. Drive 0（CP/M 上の A:）へ `CPM22_SYSTEM.2d` などの 2D ディスクイメージを挿入します。
4. 必要に応じてリセットします。
5. IPL がシステム領域を読み込み、CP/M 2.2 を起動します。

実装上、ドライブは 2 台です。

## キーボード

キーボード入力は Z80 SIO-B の入力としてエミュレートされます。英数字、記号、制御文字のほか、ALPS AKB-3320 日本語キーボードを意識したカナ入力マッピングを実装しています。

主な入力は次のとおりです。

| PC キー | 入力 |
| --- | --- |
| `A`～`Z` | 英字。Caps Lock / Shift を反映 |
| `0`～`9` | 数字および Shift 記号 |
| `Enter` | CR（0Dh） |
| `Backspace` | BS（08h） |
| `Tab` | HT（09h） |
| `Esc` | ESC（1Bh） |
| `Delete` | DEL（7Fh） |
| `Ctrl+A`～`Ctrl+Z` | 01h～1Ah |
| Caps Lock | 英字大文字状態を切替 |
| カナ入力時 | JIS X 0201 の 8 bit カナコードを入力 |

記号キーは Windows の仮想キーコードを基準に実装されており、日本語キーボード向けの配置を含みます。

## エミュレータ本体のビルド

本リポジトリは CSCP の共通ソース一式を含んでいません。`vc++2017/lynxz80.vcxproj` は CSCP の `src/common.cpp`、`src/emu.cpp`、各種デバイス実装などを参照するため、CSCP のソースツリーへ本リポジトリのファイルを重ねて配置してビルドします。

プロジェクトに記録されている設定は次のとおりです。

| 項目 | 設定 |
| --- | --- |
| Visual Studio | Visual Studio 2019 / Build Tools 2019 を想定 |
| Platform Toolset | `v141` |
| Windows SDK | `10.0.18362.0` |
| 構成 | Debug / Release |
| プラットフォーム | Win32 / x64 |
| 追加リンク | `winmm.lib`, `imm32.lib` |

詳細は [Requirements_JP.md](Requirements_JP.md) を参照してください。

## ROM・CP/M イメージの生成

現行の補助スクリプトは `tool/lynxZ80/` にあります。

主要なスクリプトは次のとおりです。

| スクリプト | 用途 |
| --- | --- |
| `build_ipl_rom.ps1` | `IPL.ROM` の生成と配置 |
| `build_subcpu_rom.ps1` | `SUBCPU.ROM` の生成 |
| `build_fontrom.ps1` | `FONT.ROM` の生成 |
| `build_cpm22_env.ps1` | CP/M 2.2 ソース・標準コマンドの準備 |
| `build_cpm22_runtime.ps1` | `CPM22_RUNTIME.BIN` の生成 |
| `build_cpm22_system_disk.ps1` | `CPM22_SYSTEM.2d` の生成 |
| `ROMCPY.ps1` | ROM の x86/x64 Debug / Release ディレクトリへのコピー |
| `diskeditor.ps1` | 現行および旧形式 CP/M ディスクイメージ編集ツール |

ROM / CP/M 用スクリプトは現行ディレクトリ構成へ統一され、AS / p2bin などは PATH から検出できます。詳細な引数、生成先、互換モードは [tool/lynxZ80/README.md](tool/lynxZ80/README.md) を参照してください。

## 技術資料

- [Programming Manual](src/vm/Lynxz80/docs/Programing%20Manual/README.md)
- [CP/M 2.2 BIOS Call Reference](src/vm/Lynxz80/docs/Programing%20Manual/CP-M%20BIOS%20call%20reference/README.md)
- [uPD7220 GDC Programming Guide](src/vm/Lynxz80/docs/Programing%20Manual/GDC4Dummies/README.md)
- [eLynxZ80 System Information](src/vm/Lynxz80/docs/Programing%20Manual/SYSinfo/README.md)

## 外部データ

### CP/M 2.2

CP/M 2.2 のシステム生成には、次の外部アーカイブを使用します。

- `cpm2-asm.zip`
- `cpm22-b.zip`

これらはリポジトリに含まれません。利用者自身で正当な入手元と利用条件を確認してください。

### フォント

`FONT.ROM` の生成には、既定では `KH-Dot-Dougenzaka-16.ttf` を使用します。フォントファイル自体は本リポジトリに含まれません。

生成方法は [tool/lynxZ80/README.md](tool/lynxZ80/README.md) を参照してください。

## 参考

- [Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html)
- [デュアル Z80 CP/Mマシン Lynx](https://www.chiaki.cc/Lynx/index.htm)
- [放課後の電子工作](https://www.chiaki.cc/)

## ライセンス

本リポジトリのルートには GNU General Public License Version 3 の [LICENSE](LICENSE) が収録されています。

CSCP 由来のファイル、CP/M 関連の外部アーカイブ、フォントその他の第三者成果物には、それぞれ別の著作権表示・利用条件が適用される場合があります。再配布時は各ファイルおよび入手元の条件を確認してください。

## 連絡先

X: <https://x.com/yosi2112>
