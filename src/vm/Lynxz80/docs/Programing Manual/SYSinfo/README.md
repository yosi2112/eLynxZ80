# LynxZ80Sim System Information

LynxZ80Sim のプログラミング用システム情報メモです。本文書は、現在のエミュレータ実装から確認できるメインCPU側のメモリマップとI/Oポート割り当てを中心に整理します。サブCPU側の情報は付録としてまとめます。

この文書の主な参照元は以下です。

- `src/vm/Lynxz80/Membus.cpp`
- `src/vm/Lynxz80/Membus.h`
- `src/vm/Lynxz80/LynxZ80.cpp`
- `src/vm/Lynxz80/LynxZ80.h`
- `src/vm/Lynxz80/display.h`
- `src/vm/Lynxz80/floppy.cpp`

## メインCPUメモリマップ

メインCPUは Z80 で、アドレス空間は 64KB です。実装上は `MEMBUS` が RAM 全域を持ち、起動時および `ROMEN` 有効時のみ 0x0000-0x1fff に ROM を重ねます。

| アドレス範囲 | サイズ | 内容 | R/W | 備考 |
|---|---:|---|---|---|
| `0000h-1FFFh` | 8KB | IPL/BIOS ROM | R | `ROMEN=1` のとき有効。`IPL.ROM`, `MAIN.ROM`, `BOOT.ROM`, `BASIC.ROM` の順で読み込み候補になります。 |
| `0000h-FFFFh` | 64KB | メインRAM | R/W | 常時存在します。ROM有効時は `0000h-1FFFh` の読み出しだけROMに隠れます。 |

### ROMEN

`ROMEN` は FDD制御用 PIO-B の bit 7 から `FLOPPY` 経由で `MEMBUS` へ渡されます。

| 値 | 動作 |
|---:|---|
| `1` | `0000h-1FFFh` をROM読み出しにします。リセット直後の既定値です。 |
| `0` | ROMを外し、`0000h-FFFFh` 全域をRAMとして読み書きします。 |

## メインCPU I/Oポート一覧

メインCPU側のI/Oデコードは、基本的に `20h-3Fh` の範囲だけを対象にします。`3Ch-3Fh` の MINSUB ブリッジだけは先に判定されます。

デコード式は以下です。

```text
I/O decoder enabled: (port & E0h) == 20h
group             : (port >> 2) & 07h
reg               : port & 03h
```

| ポート範囲 | group | デバイス | レジスタ | R/W | 概要 |
|---|---:|---|---|---|---|
| `20h-23h` | 0 | Z80 SIO | `sio_reg(port)` | R/W | シリアル/キーボード系。SIO-B read data/status はキーボードFIFOで補助されます。 |
| `24h-27h` | 1 | Z80 CTC | `port & 03h` | R/W | タイマ/割り込み制御。メインCPUの割り込み系に接続されます。 |
| `28h-2Bh` | 2 | Z80 DMA | 実装上 `0` | R/W | DMA制御。現実装では全レジスタアクセスが `dma->read/write_io8(0)` へ集約されています。 |
| `2Ch-2Fh` | 3 | MB8877 FDC | `port & 03h` | R/W | フロッピーディスクコントローラ。 |
| `30h-33h` | 4 | Z80 PIO | `pio_reg(port)` | R/W | FDD制御ラッチ、ROMEN制御。 |
| `34h-37h` | 5 | 未使用 | - | - | 現実装では未接続です。 |
| `38h-3Bh` | 6 | 未使用 | - | - | 現実装では未接続です。 |
| `3Ch-3Fh` | 7 | MINSUB bridge | bridge | R/W | メインCPUからサブCPUへの通信。 |

未接続ポートの読み出し値は `FFh` です。

## SIOポート詳細

SIOの下位2ビットは、実装内で以下のように入れ替えてから Z80SIO へ渡されます。

```text
sio_reg = ((reg & 01h) << 1) | ((reg & 02h) >> 1)
```

| CPUポート | `reg` | `sio_reg` | 備考 |
|---:|---:|---:|---|
| `20h` | 0 | 0 | Z80SIO 実装側のレジスタ0へ接続 |
| `21h` | 1 | 2 | Z80SIO 実装側のレジスタ2へ接続 |
| `22h` | 2 | 1 | Z80SIO 実装側のレジスタ1へ接続 |
| `23h` | 3 | 3 | Z80SIO 実装側のレジスタ3へ接続 |

キーボード入力は SIO-B 側の読み出しを補助する形で実装されています。

- `sio_reg == 2`: キーボードFIFOにデータがある場合、FIFOから1バイト返します。
- `sio_reg == 3`: キーボードFIFOにデータがある場合、SIOステータスに ready bit 相当の `01h` を立てます。

## FDCポート詳細

`2Ch-2Fh` は MB8877 FDC に接続されます。

| CPUポート | FDC reg | 一般的な意味 | 備考 |
|---:|---:|---|---|
| `2Ch` | 0 | status / command | 読み出しはステータス、書き込みはコマンド。 |
| `2Dh` | 1 | track | トラックレジスタ。 |
| `2Eh` | 2 | sector | セクタレジスタ。 |
| `2Fh` | 3 | data | データレジスタ。 |

FDCの DRQ は Z80DMA、IRQ はメインCPU IRQ へ接続されます。

## PIOポート詳細

PIOも SIO と同様に下位2ビットを入れ替えてから Z80PIO へ渡されます。

```text
pio_reg = ((reg & 01h) << 1) | ((reg & 02h) >> 1)
```

| CPUポート | `reg` | `pio_reg` | 備考 |
|---:|---:|---:|---|
| `30h` | 0 | 0 | Z80PIO 実装側のレジスタ0へ接続 |
| `31h` | 1 | 2 | Z80PIO 実装側のレジスタ2へ接続 |
| `32h` | 2 | 1 | Z80PIO 実装側のレジスタ1へ接続 |
| `33h` | 3 | 3 | Z80PIO 実装側のレジスタ3へ接続 |

PIOのポートA/Bは `FLOPPY` デバイスへ接続されます。

### PIO-A

| bit | 信号 | 備考 |
|---:|---|---|
| 0 | 未接続 | 実装では `0` 扱いです。 |
| 6 | `DISK2 SENS` | FDC の side register へ反映されます。 |
| その他 | 未整理 | 現実装では FDD制御に直接使っていません。 |

### PIO-B

| bit | 信号 | 備考 |
|---:|---|---|
| 0-1 | drive select | `00b` drive 0、`01b` drive 1。 |
| 2 | drive 1 ready/motor 条件 | drive 1 選択時の ready 判定に使います。 |
| 3 | drive 0 ready/motor 条件 | drive 0 選択時の ready 判定に使います。 |
| 4-6 | 未接続 | 実装ではマスクされます。 |
| 7 | `ROMEN` | `1` でROM有効、`0` でRAM全域化。 |

## MINSUB ブリッジ

`3Ch-3Fh` はメインCPUとサブCPUの通信ブリッジです。実装では `port & FCh == 3Ch` で選択されます。

### メインCPU側

| 操作 | 内容 |
|---|---|
| read | ステータスを返します。 |
| write | 書き込んだ1バイトをサブCPU向けデータとして保持し、DR full を立てます。 |

ステータスビット:

| bit | 名称 | 意味 |
|---:|---|---|
| 0 | `SUB_BUSY` | サブCPUが busy として通知している状態です。 |
| 1 | `DR_FULL` | メインからサブへのデータレジスタが埋まっています。 |

## 付録A: サブCPUメモリマップ

サブCPUも Z80 です。現実装では、サブROMとサブRAMのみをメモリ空間へ配置しています。表示用VRAMはサブCPUメモリへ直接マップされず、GDC経由で操作します。

| アドレス範囲 | サイズ | 内容 | R/W | 備考 |
|---|---:|---|---|---|
| `0000h-1FFFh` | 8KB | SUBCPU ROM | R | `SUBCPU.ROM` を読み込みます。未配置時は自己ジャンプ+HALT埋めの安全値になります。 |
| `8000h-87FFh` | 2KB | サブRAM | R/W | サブCPU作業領域です。 |
| その他 | - | 未接続 | - | 現実装では明示マップされていません。 |

## 付録B: 表示メモリ

表示メモリは `DISPLAY` が保持し、uPD7220 GDC へVRAMポインタとして接続されます。

| 領域 | サイズ | 接続先 | 備考 |
|---|---:|---|---|
| TVRAM | `1000h` bytes | Character GDC | 文字コード/属性の格納領域です。 |
| GVRAM plane 0 | `10000h` bytes | Graphics GDC | グラフィック面0。 |
| GVRAM plane 1 | `10000h` bytes | Graphics GDC | グラフィック面1。 |
| GVRAM plane 2 | `10000h` bytes | Graphics GDC | グラフィック面2。 |
| FONT ROM buffer | `2000h` bytes | DISPLAY | `FONT.ROM` を読み込みます。CPUメモリ空間には直接見えません。 |

## 付録C: サブCPU I/Oポート

サブCPU側は `addr & 82h` の部分デコードで、文字GDC、グラフィックGDC、MINSUBブリッジへ振り分けます。このため、同じデバイスに複数のエイリアスポートがあります。

| 条件 | 主なポート例 | デバイス | レジスタ | R/W | 備考 |
|---|---|---|---|---|---|
| `(port & 82h) == 00h` | `00h`, `01h`, `04h`, `05h` ... | Character GDC | `port & 01h` | R/W | 文字表示用 uPD7220。 |
| `(port & 82h) == 02h` | `02h`, `03h`, `06h`, `07h` ... | Graphics GDC | `port & 01h` | R/W | グラフィック表示用 uPD7220。 |
| `(port & 82h) == 80h` | `80h`, `81h`, `84h`, `85h` ... | MINSUB bridge | bridge | R/W | メインCPUとの通信。 |
| `(port & 82h) == 82h` | `82h`, `83h`, `86h`, `87h` ... | 未接続 | - | - | 読み出しは `FFh`。 |

### サブCPU側 MINSUB

| 操作 | 内容 |
|---|---|
| read | メインCPUからのデータがあれば1バイト返し、DR full を下げます。データがなければ `00h` を返します。 |
| write | bit 0 を `SUB_BUSY` として保持します。 |

## 付録D: 割り込みと接続概要

| 接続 | 内容 |
|---|---|
| CTC -> main CPU | メインCPU割り込み制御。 |
| SIO -> main CPU | シリアル/キーボード系割り込み。 |
| PIO -> main CPU | FDD制御系割り込み。 |
| DMA -> main CPU | DMA割り込み。 |
| FDC IRQ -> main CPU | FDC割り込み。 |
| FDC DRQ -> DMA | FDCデータ要求。 |
| Character GDC VSYNC -> sub CPU IRQ | 文字GDCのVSYNCをサブCPU IRQへ接続。 |

## 注意事項

- 本文書は現時点のエミュレータ実装から作成した早見表です。実機回路図の全信号を完全に転記したものではありません。
- サブCPU側I/Oは部分デコードのため、代表ポート以外にも多数のエイリアスがあります。
- `ROMEN`、FDC ready 条件、MINSUBステータスは、CP/M起動やBIOS実装に影響する重要点です。
