# eLynxZ80 Programming Manual

このディレクトリには、eLynxZ80 の実装、移植、BIOS 開発、表示処理の解析に使用する技術資料を収録しています。

利用者向けの導入・起動手順は、リポジトリルートの [README.md](../../../../../README.md) を参照してください。

## 文書一覧

| 文書 | 内容 |
| --- | --- |
| [CP/M 2.2 BIOS Call Reference](CP-M%20BIOS%20call%20reference/README.md) | CP/M 2.2 BIOS の標準エントリ、呼出規約、および eLynxZ80 の現行 BIOS / DPB |
| [uPD7220 GDC Programming Guide](GDC4Dummies/README.md) | eLynxZ80 における文字 GDC / グラフィック GDC の I/O、コマンド送出、デバッグ方法 |
| [eLynxZ80 System Information](SYSinfo/README.md) | CPU、メモリマップ、I/O ポート、MINSUB、FDC、表示メモリ、割り込み構成 |

## ソースコードとの対応

技術資料の内容は、主に次のファイルを基準にしています。

```text
src/vm/Lynxz80/LynxZ80.cpp
src/vm/Lynxz80/LynxZ80.h
src/vm/Lynxz80/Membus.cpp
src/vm/Lynxz80/display.cpp
src/vm/Lynxz80/floppy.cpp
src/vm/Lynxz80/keyboard.cpp
src/vm/Lynxz80/serial.cpp
tool/lynxZ80/build/bios/bios.asm
tool/lynxZ80/build/subcpu/subcpurom.asm
```

実装と文書の内容が異なる場合は、現在のソースコードを優先してください。

## 表記

このマニュアルでは、次の表記を使用します。

- 製品名: **eLynxZ80**
- エミュレーション対象: **Lynx**
- メインプロセッサ: **メイン CPU**
- 表示制御用プロセッサ: **サブ CPU**
- 16 進数: 原則として `00h` またはアセンブリソースに合わせて `00H`
- メモリ容量: KB
- ファイルサイズ・セクタサイズ: bytes

> [!NOTE]
> リポジトリ上のディレクトリ名 `Programing Manual` は既存パスとの互換性のため残されています。文書タイトルでは一般的な綴りの “Programming Manual” を使用します。
