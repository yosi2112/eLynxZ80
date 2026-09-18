# uPD7220 GDC Programming Guide

この文書は、eLynxZ80 に実装されている文字表示用 GDC とグラフィック表示用 GDC の I/O インターフェース、およびプログラムからの基本的な操作方法をまとめたものです。

同じディレクトリの `gdc_manual_A4_page_01.png` ～ `gdc_manual_A4_page_12.png` は、補助的な図解資料です。

## 1. 構成

eLynxZ80 はサブ CPU 側に 2 個の uPD7220 相当 GDC を接続しています。

| GDC | 用途 | VRAM |
| --- | --- | --- |
| Character GDC | 文字表示 | TVRAM 4096 bytes |
| Graphics GDC | グラフィック表示 | 3 planes × 65536 bytes |

GDC はサブ CPU の I/O 空間へ接続され、メイン CPU / CP/M 側からグラフィック GDC を操作する場合は MINSUB を介したサブ CPU のプロキシ処理を利用できます。

## 2. サブ CPU I/O デコード

サブ CPU 側では、I/O アドレスの一部だけをデコードします。

| 条件 | デバイス |
| --- | --- |
| `(port & 82h) == 00h` | Character GDC |
| `(port & 82h) == 02h` | Graphics GDC |
| `(port & 82h) == 80h` | MINSUB |
| `(port & 82h) == 82h` | 未接続 |

GDC へ渡されるレジスタ番号は `port & 01h` です。

したがって、代表的なポートは次のようになります。

| Port | デバイス | Reg | 書込 | 読込 |
| ---: | --- | ---: | --- | --- |
| `00h` | Character GDC | 0 | parameter | status |
| `01h` | Character GDC | 1 | command | FIFO data |
| `02h` | Graphics GDC | 0 | parameter | status |
| `03h` | Graphics GDC | 1 | command | FIFO data |

部分デコードのため、`04h`～`07h` などにも同じデバイスのエイリアスがあります。通常は上表の代表ポートを使用してください。

## 3. コマンド送出

GDC への基本的な書込みは、コマンドを register 1、パラメータを register 0 へ送る形です。

概念例:

```cpp
write_io8(command_port, command);
write_io8(parameter_port, param0);
write_io8(parameter_port, param1);
```

読込みは register 0 が status、register 1 が FIFO data です。

```cpp
status = read_io8(status_port);
data   = read_io8(data_port);
```

コマンドごとに必要なパラメータ数が異なるため、未完了のコマンド列を残したまま次のコマンドを送らないでください。

## 4. 初期化の基本手順

一般的な初期化では、次の順序で GDC の状態を設定します。

1. RESET
2. SYNC
3. MASTER / SLAVE の設定
4. 必要な表示パラメータの設定
5. START

eLynxZ80 には Character GDC と Graphics GDC の 2 個があるため、初期化対象を取り違えないようにしてください。

## 5. VRAM アクセスと描画

描画処理では、主に次のコマンド群を使用します。

- `CSRW`: current address / cursor position の設定
- `VECTW`: ベクタ描画条件の設定
- `WRITE`: VRAM データ書込み
- `VECTE`: ベクタ描画実行
- `TEXTE`: 文字・パターン描画実行

基本的な流れは次のとおりです。

1. `CSRW` で対象 VRAM 位置を設定します。
2. 必要に応じて `VECTW` で方向、長さ、描画条件を設定します。
3. `WRITE`、`VECTE`、`TEXTE` などを実行します。
4. status を確認し、FIFO / busy 状態に応じて次のコマンドを送ります。

## 6. Graphics GDC の VRAM

Graphics GDC には合計 192 KB の VRAM が接続されています。

```text
plane 0: 00000h-0FFFFh
plane 1: 10000h-1FFFFh
plane 2: 20000h-2FFFFh
```

各 plane は 65536 bytes です。

`display.cpp` は GDC の状態と各 plane のデータを参照し、最終的な画面バッファへ変換します。

## 7. CP/M からの Graphics GDC 操作

`tool/lynxZ80/build/gvramtest/` の `GVRAMTST` は、CP/M 上から MINSUB 経由でサブ CPU に Graphics GDC 操作を依頼します。

プロキシコマンドは次の形式です。

```text
ESC G C xx
ESC G P xx
```

| 形式 | 機能 |
| --- | --- |
| `ESC G C xx` | Graphics GDC の command port へ 1 byte 書込み |
| `ESC G P xx` | Graphics GDC の parameter port へ 1 byte 書込み |

`xx` は `00`～`FF` の 2 桁 ASCII 16 進数です。

現行の MAIN/SUB 通信経路には、汎用の byte-wide 戻りチャネルがないため、このプロキシは書込み側の GDC コマンド列を対象とします。

## 8. デバッグ

Debug ビルドでは GDC 操作を次のログへ記録します。

```text
lynxz80_gdc_txt.log
lynxz80_gdc_grph.log
```

表示異常がある場合は、次を確認してください。

- Character GDC / Graphics GDC のポートを取り違えていないか
- command と parameter の書込み先を逆にしていないか
- 必要なパラメータをすべて送っているか
- GDC の busy / FIFO 状態を無視していないか
- VRAM アドレスが有効範囲内か
- SYNC / START などの初期化が完了しているか
- CP/M から操作する場合、MINSUB と `SUBCPU.ROM` が正常に動作しているか

## 9. 図解資料

| Page | File | 主題 |
| ---: | --- | --- |
| 1 | `gdc_manual_A4_page_01.png` | GDC の概要 |
| 2 | `gdc_manual_A4_page_02.png` | I/O |
| 3 | `gdc_manual_A4_page_03.png` | 初期化 |
| 4 | `gdc_manual_A4_page_04.png` | RESET / SYNC / MASTER / START |
| 5 | `gdc_manual_A4_page_05.png` | カーソル / VRAM address |
| 6 | `gdc_manual_A4_page_06.png` | CSRW / VECTW |
| 7 | `gdc_manual_A4_page_07.png` | VRAM write |
| 8 | `gdc_manual_A4_page_08.png` | vector drawing |
| 9 | `gdc_manual_A4_page_09.png` | text / pattern drawing |
| 10 | `gdc_manual_A4_page_10.png` | status / FIFO |
| 11 | `gdc_manual_A4_page_11.png` | troubleshooting |
| 12 | `gdc_manual_A4_page_12.png` | implementation checklist |

![GDC manual page 1](gdc_manual_A4_page_01.png)

## 10. 実装参照

- `src/vm/Lynxz80/LynxZ80.cpp`
- `src/vm/Lynxz80/display.cpp`
- `src/vm/Lynxz80/display.h`
- `tool/lynxZ80/build/subcpu/subcpurom.asm`
- `tool/lynxZ80/build/gvramtest/GVRAMTST.ASM`
