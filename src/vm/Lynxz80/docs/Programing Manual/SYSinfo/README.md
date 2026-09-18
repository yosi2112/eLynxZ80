# eLynxZ80 System Information

この文書は、現行 eLynxZ80 実装の CPU、メモリ、I/O、表示、フロッピー、MAIN/SUB 通信をまとめた技術リファレンスです。

主な参照ソース:

```text
src/vm/Lynxz80/LynxZ80.cpp
src/vm/Lynxz80/LynxZ80.h
src/vm/Lynxz80/Membus.cpp
src/vm/Lynxz80/display.cpp
src/vm/Lynxz80/floppy.cpp
src/vm/Lynxz80/keyboard.cpp
src/vm/Lynxz80/serial.cpp
```

## 1. 基本仕様

| 項目 | 実装値 |
| --- | --- |
| メイン CPU | Z80 |
| サブ CPU | Z80 |
| CPU clock | 4 MHz |
| frame rate | 56.42 fps |
| lines / frame | 440 |
| 画面 | 640 × 400 |
| GDC horizontal frequency | 24830 Hz |
| フロッピードライブ | 2 |
| drive type | 2D |
| rotation | 300 rpm |
| recording | FM |

## 2. メイン CPU メモリマップ

メイン CPU のアドレス空間は 64 KB です。

`MEMBUS` は 64 KB RAM を常時保持し、ROM が有効な間だけ `0000h-1FFFh` の読込みへ 8 KB IPL ROM を重ねます。

| アドレス | サイズ | 内容 | R/W |
| --- | ---: | --- | --- |
| `0000h-1FFFh` | 8 KB | `IPL.ROM` | R、ROMEN=1 の場合 |
| `0000h-FFFFh` | 64 KB | RAM | R/W |

現行実装で読み込むメイン ROM のファイル名は `IPL.ROM` です。

### 2.1 ROM が見つからない場合

起動時に ROM バッファは HALT を主体とする安全な内容で初期化され、その後 `IPL.ROM` の読込みを試みます。

したがって、ファイルがない場合でもホスト側エミュレータが直ちに異常終了することは避けられますが、Lynx の IPL としては動作しません。

### 2.2 ROMEN

リセット直後は `ROMEN=1` です。

PIO-B bit 7 が FLOPPY インターフェースを介して `MEMBUS` の ROMEN 信号へ接続されています。

| ROMEN | 動作 |
| ---: | --- |
| 1 | `0000h-1FFFh` の読込みを ROM にする |
| 0 | `0000h-FFFFh` を RAM としてアクセスする |

## 3. メイン CPU I/O

メイン I/O デコーダは基本的に `20h-3Fh` を対象とします。`3Ch-3Fh` の MINSUB は優先して判定されます。

```text
decoder enabled : (port & E0h) == 20h
group           : (port >> 2) & 07h
register        : port & 03h
```

| Port | Group | デバイス | 備考 |
| --- | ---: | --- | --- |
| `20h-23h` | 0 | Z80 SIO | serial / keyboard |
| `24h-27h` | 1 | Z80 CTC | timer / interrupt |
| `28h-2Bh` | 2 | Z80 DMA | 現行実装は register 0 へ集約 |
| `2Ch-2Fh` | 3 | MB8877 FDC | status/command, track, sector, data |
| `30h-33h` | 4 | Z80 PIO | floppy control / ROMEN |
| `34h-37h` | 5 | 未接続 | read=`FFh` |
| `38h-3Bh` | 6 | 未接続 | read=`FFh` |
| `3Ch-3Fh` | 7 | MINSUB | main/sub bridge |

## 4. SIO

SIO の下位 2 bit は次のように入れ替えて Z80 SIO 実装へ渡されます。

```text
sio_reg = ((reg & 01h) << 1) | ((reg & 02h) >> 1)
```

| CPU port | SIO reg |
| ---: | ---: |
| `20h` | 0 |
| `21h` | 2 |
| `22h` | 1 |
| `23h` | 3 |

### 4.1 SIO-B: キーボード

エミュレータのキーボード FIFO は SIO-B の読込みを補助します。

- SIO register 2: FIFO にデータがあれば 1 byte 返します。
- SIO register 3: FIFO にデータがあれば ready bit `01h` を立てます。

入力マッピングは ALPS AKB-3320 の日本語キー配列を意識した実装で、ASCII、制御文字、JIS X 0201 カナを扱います。

### 4.2 SIO-A: 外部シリアル

SIO-A は外部シリアルブリッジへ接続されています。

選択可能な現行プリセットは次のとおりです。

| serial type | 接続 |
| ---: | --- |
| 0 | off |
| 1 | COM1, 9600 baud |
| 2 | COM2, 9600 baud |
| 3 | COM3, 9600 baud |
| 4 | COM4, 9600 baud |
| 5 | TCP listen 127.0.0.1:8023 |

既定値は 0（off）です。

## 5. FDC

`2Ch-2Fh` は MB8877 FDC に接続されます。

| Port | Register | 機能 |
| ---: | ---: | --- |
| `2Ch` | 0 | status / command |
| `2Dh` | 1 | track |
| `2Eh` | 2 | sector |
| `2Fh` | 3 | data |

接続:

- FDC IRQ → main CPU IRQ
- FDC IRQ → PIO-A bit 0
- FDC DRQ → Z80 DMA READY

2 台のドライブはいずれも 2D、300 rpm、FM として初期化されます。

## 6. PIO

PIO も SIO と同じレジスタ入替えを行います。

```text
pio_reg = ((reg & 01h) << 1) | ((reg & 02h) >> 1)
```

| CPU port | PIO reg |
| ---: | ---: |
| `30h` | 0 |
| `31h` | 2 |
| `32h` | 1 |
| `33h` | 3 |

PIO-A / B は FLOPPY インターフェースへ接続されます。

### 6.1 PIO-B

| Bit | 用途 |
| ---: | --- |
| 0-1 | drive select |
| 2 | drive 1 ready / motor condition |
| 3 | drive 0 ready / motor condition |
| 4-6 | 現行実装では未使用 |
| 7 | ROMEN |

## 7. MINSUB

メイン CPU とサブ CPU の間には 1-byte データレジスタと状態 bit を持つブリッジがあります。

### 7.1 メイン CPU 側

代表ポートは `3Ch` です。`3Ch-3Fh` が同じブリッジへデコードされます。

メイン CPU が書き込むと:

1. byte が `main_to_sub_data` に保存されます。
2. `DR_FULL` が 1 になります。

メイン CPU が読み込むと status を返します。

| Bit | 名称 | 意味 |
| ---: | --- | --- |
| 0 | `SUB_BUSY` | サブ CPU busy |
| 1 | `DR_FULL` | main→sub data が未読 |

### 7.2 サブ CPU 側

サブ CPU 側の代表ポートは `80h` です。

サブ CPU が読み込むと、データがある場合は 1 byte を返し、`DR_FULL` をクリアします。データがない場合は `00h` を返します。

サブ CPU が書き込む場合、bit 0 が `SUB_BUSY` として保持されます。

## 8. サブ CPU メモリマップ

| アドレス | サイズ | 内容 | R/W |
| --- | ---: | --- | --- |
| `0000h-1FFFh` | 8 KB | `SUBCPU.ROM` | R |
| `8000h-87FFh` | 2 KB | sub RAM | R/W |
| その他 | - | 未接続 | - |

`SUBCPU.ROM` がない場合、ROM バッファは `JP 0000h` と HALT を主体とする安全な初期内容になります。

## 9. サブ CPU I/O

サブ CPU は `addr & 82h` で部分デコードします。

| 条件 | デバイス | GDC reg |
| --- | --- | ---: |
| `(port & 82h) == 00h` | Character GDC | `port & 01h` |
| `(port & 82h) == 02h` | Graphics GDC | `port & 01h` |
| `(port & 82h) == 80h` | MINSUB | - |
| `(port & 82h) == 82h` | 未接続 | - |

代表ポート:

```text
00h Character GDC parameter/status
01h Character GDC command/data
02h Graphics GDC parameter/status
03h Graphics GDC command/data
80h MINSUB
```

部分デコードのため、これらには複数のエイリアスポートがあります。

## 10. 表示メモリ

`DISPLAY` が保持する表示メモリは次のとおりです。

| 領域 | サイズ | 接続 |
| --- | ---: | --- |
| TVRAM | 4096 bytes | Character GDC |
| GVRAM plane 0 | 65536 bytes | Graphics GDC |
| GVRAM plane 1 | 65536 bytes | Graphics GDC |
| GVRAM plane 2 | 65536 bytes | Graphics GDC |
| FONT buffer | 8192 bytes | `FONT.ROM` |

`FONT.ROM` は CPU メモリ空間へ直接マップされません。`DISPLAY` がローカルファイルとして読み込み、文字描画時に参照します。

ファイルを読み込めなかった場合、現行描画コードは文字パターンを 0 として扱うため、文字は表示されません。

## 11. 割り込み接続

| 接続元 | 接続先 |
| --- | --- |
| CTC | main CPU interrupt |
| SIO | main CPU interrupt |
| PIO | main CPU interrupt |
| DMA | main CPU interrupt |
| FDC IRQ | main CPU IRQ |
| FDC IRQ | PIO-A bit 0 |
| FDC DRQ | DMA READY |
| Character GDC VSYNC | sub CPU IRQ |

## 12. Debug ログ

Debug ビルドでは、実装箇所に応じて次のログが生成されます。

```text
lynxz80_main.log
lynxz80_bridge.log
lynxz80_gdc_txt.log
lynxz80_gdc_grph.log
lynxz80_keyboard.log
```

I/O、MINSUB、GDC、キーボードの不具合解析に使用できます。

## 13. 注意事項

- この文書は実機回路図そのものではなく、現行エミュレータ実装の仕様書です。
- サブ CPU I/O は部分デコードのためエイリアスポートがあります。
- ROMEN、MINSUB、FDC ready 条件は CP/M 起動に直接影響します。
- 実装と文書が異なる場合は、現在のソースコードを優先してください。
