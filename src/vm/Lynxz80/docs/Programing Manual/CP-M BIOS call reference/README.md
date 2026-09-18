# CP/M 2.2 BIOS Call Reference

この文書は、CP/M 2.2 BIOS の標準インターフェースと、eLynxZ80 の現行 BIOS 実装をまとめたリファレンスです。

対象ソース:

```text
tool/lynxZ80/build/bios/bios.asm
tool/lynxZ80/build_cpm22_runtime.ps1
tool/lynxZ80/build_cpm22_system_disk.ps1
```

## 1. BIOS の位置付け

CP/M 2.2 は、CCP、BDOS、BIOS から構成されます。BIOS はハードウェア依存部分を受け持ち、コンソール I/O、ディスク選択、セクタ I/O などを BDOS へ提供します。

BIOS の先頭には 17 個のジャンプエントリを配置します。各エントリは 3 bytes です。

```asm
BOOT:    JP BIOS_BOOT
WBOOT:   JP BIOS_WBOOT
CONST:   JP BIOS_CONST
CONIN:   JP BIOS_CONIN
CONOUT:  JP BIOS_CONOUT
LIST:    JP BIOS_LIST
PUNCH:   JP BIOS_PUNCH
READER:  JP BIOS_READER
HOME:    JP BIOS_HOME
SELDSK:  JP BIOS_SELDSK
SETTRK:  JP BIOS_SETTRK
SETSEC:  JP BIOS_SETSEC
SETDMA:  JP BIOS_SETDMA
READ:    JP BIOS_READ
WRITE:   JP BIOS_WRITE
PRSTAT:  JP BIOS_PRSTAT
SECTRN:  JP BIOS_SECTRN
```

`PRSTAT` は一般的な CP/M 資料で `LISTST` と記載されるエントリ、`SECTRN` は `SECTRAN` と記載されるエントリに相当します。

## 2. BIOS コール一覧

| No. | Offset | エントリ | 入力 | 出力 | 機能 |
| ---: | ---: | --- | --- | --- | --- |
| 0 | `00h` | `BOOT` | なし | 戻らない | コールドブート |
| 1 | `03h` | `WBOOT` | なし | 戻らない | ウォームブート |
| 2 | `06h` | `CONST` | なし | `A=00h/FFh` | コンソール入力状態 |
| 3 | `09h` | `CONIN` | なし | `A=文字` | コンソール入力 |
| 4 | `0Ch` | `CONOUT` | `C=文字` | なし | コンソール出力 |
| 5 | `0Fh` | `LIST` | `C=文字` | なし | リストデバイス出力 |
| 6 | `12h` | `PUNCH` | `C=文字` | なし | 補助出力 |
| 7 | `15h` | `READER` | なし | `A=文字` | 補助入力 |
| 8 | `18h` | `HOME` | なし | なし | トラック 0 を選択 |
| 9 | `1Bh` | `SELDSK` | `C=drive`, `E=login flag` | `HL=DPH` | ドライブ選択 |
| 10 | `1Eh` | `SETTRK` | `BC=track` | なし | トラック設定 |
| 11 | `21h` | `SETSEC` | `BC=sector` | なし | 論理セクタ設定 |
| 12 | `24h` | `SETDMA` | `BC=address` | なし | DMA アドレス設定 |
| 13 | `27h` | `READ` | 事前設定値 | `A=status` | 128-byte 論理セクタ読込 |
| 14 | `2Ah` | `WRITE` | `C=write type` | `A=status` | 128-byte 論理セクタ書込 |
| 15 | `2Dh` | `PRSTAT` | なし | `A=00h/FFh` | リストデバイス状態 |
| 16 | `30h` | `SECTRN` | `BC=logical`, `DE=XLT` | `HL=physical` | セクタ変換 |

## 3. コンソール I/O

現行 BIOS はコンソール I/O に Z80 SIO を使用します。

キーボード入力はエミュレータ側で SIO-B へ供給されます。BIOS の `CONST` / `CONIN` はこの経路から CP/M のコンソール入力を処理します。

`CONOUT` は通常のコンソール文字出力に加えて、サブ CPU との MINSUB 経路を使用する表示制御にも関係します。

`LIST` と `PUNCH` は現行 BIOS では実質的にスタブです。`PRSTAT` は `FFh` を返します。

## 4. ディスク I/O

### 4.1 ドライブ

eLynxZ80 は 2 ドライブを実装しています。

| CP/M | エミュレータ |
| --- | --- |
| A: | Drive 0 |
| B: | Drive 1 |

`SELDSK` は選択したドライブの DPH を返し、無効なドライブでは `HL=0000h` を返します。

### 4.2 READ / WRITE

BDOS と BIOS の間では 128-byte 論理セクタ単位でデータを受け渡します。

`READ` / `WRITE` は eLynxZ80 の FDC 経路を使用して実ディスクイメージへアクセスします。現行 BIOS では FDC 操作に失敗した場合 `A=01h`、成功した場合 `A=00h` を返します。

## 5. DPH

現行 BIOS は A: / B: 用に `DPH0` と `DPH1` を持ち、両方が共通の `DPB0` とセクタ変換表を参照します。

構造は次の標準 CP/M 2.2 DPH 形式です。

| Offset | Field | 内容 |
| ---: | --- | --- |
| `00h` | XLT | セクタ変換表 |
| `02h` | scratch 1 | BDOS 作業領域 |
| `04h` | scratch 2 | BDOS 作業領域 |
| `06h` | scratch 3 | BDOS 作業領域 |
| `08h` | DIRBUF | 128-byte ディレクトリバッファ |
| `0Ah` | DPB | Disk Parameter Block |
| `0Ch` | CSV | チェックベクタ |
| `0Eh` | ALV | アロケーションベクタ |

## 6. 現行 DPB

`bios.asm` の `DPB0` は次の値です。

| Field | 値 | 意味 |
| --- | ---: | --- |
| SPT | 64 | 1 シリンダあたり 64 × 128-byte 論理セクタ |
| BSH | 4 | 2 KB allocation block |
| BLM | 15 | block mask |
| EXM | 1 | extent mask |
| DSM | 151 | 最大データブロック番号 |
| DRM | 127 | 最大ディレクトリエントリ番号 |
| AL0 | `C0h` | ディレクトリ用予約ブロック |
| AL1 | `00h` | 同上 |
| CKS | 32 | directory check vector size |
| OFF | 2 | 予約シリンダ数 |

この DPB は `build_cpm22_system_disk.ps1` のディスク形式と対応します。

### 6.1 物理ディスク形式

| 項目 | 値 |
| --- | ---: |
| シリンダ | 40 |
| 面 | 2 |
| セクタ / 面 | 16 |
| 物理セクタ | 256 bytes |
| 1 シリンダ | 8192 bytes |
| 総容量 | 327680 bytes |
| システム予約 | 2 シリンダ |
| allocation block | 2048 bytes |
| directory entries | 128 |

物理 1 シリンダは 2 sides × 16 sectors × 256 bytes = 8192 bytes です。CP/M の 128-byte 論理セクタでは SPT=64 になります。

## 7. セクタ変換

現行 BIOS の `SECTRAN` テーブルは 1～64 の連続値で、実質的にインターリーブなしの順次マッピングです。

`BIOS_SECTRN` は変換テーブルアドレスが 0 の場合には identity mapping として処理します。

## 8. BIOS ワーク領域

resident BIOS の生成時、`build_cpm22_runtime.ps1` は BIOS のワーク領域を `F900h` から配置し、コード領域や cold boot 表示領域と重ならないことを検証します。

主なワーク領域には次が含まれます。

- DPH scratch
- CSV
- ALV
- DIRBUF
- 現在ドライブ / トラック / セクタ / DMA アドレスなどの BIOS 状態

## 9. コールドブートとウォームブート

CP/M ソースへ適用する `patch.diff` は、コールドブート時だけ sign-on を表示する処理を追加します。

ウォームブートは `CBASE+3` から入り、cold boot 専用 sign-on を再表示しません。

現行パッチの sign-on は eLynxZ80 / Lynx 向け CP/M 2.2 であることを表示します。

## 10. 実装確認項目

BIOS を変更した場合は、最低限次を確認してください。

- 17 個の BIOS ジャンプエントリの順序が変わっていないこと
- `BOOT` / `WBOOT` がページゼロを正しく設定すること
- `CONST` が非ブロッキングであること
- `CONIN` / `CONOUT` で CP/M コンソール I/O が動作すること
- A: / B: の DPH が有効であること
- `SETTRK` / `SETSEC` / `SETDMA` の値が `READ` / `WRITE` に反映されること
- DPB が `CPM22_SYSTEM.2d` の形式と一致すること
- cold boot / warm boot の双方が正常に CCP へ到達すること

## 11. 参考資料

- Digital Research, *CP/M 2.2 Alteration Guide*
- John Elliott, *CP/M information archive: BIOS*
