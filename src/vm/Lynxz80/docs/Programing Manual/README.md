# LynxZ80Sim Programing Manual

LynxZ80Sim の実装・移植・デバッグ作業で参照するプログラミング資料群。

## Index

| Directory | 内容 |
|---|---|
| `CP-M BIOS call reference` | CP/M 2.2 BIOSジャンプベクタ、各BIOSコール、DPH/DPB、実装チェックリスト。 |
| `GDC4Dummies` | uPD7220A系GDC操作の入門資料、I/Oポート、コマンド投入、VRAM描画、デバッグ観点。 |
| `SYSinfo` | LynxZ80Sim のシステム構成図、メインCPU系/サブCPU系/表示系のブロック別概要。 |

## 使い分け

- CP/M の起動、BDOSからBIOSへの呼出、ディスクI/Oを確認する場合は `CP-M BIOS call reference` を参照する。
- 文字GDC/グラフィックGDC、VRAM描画、表示が出ない問題を追う場合は `GDC4Dummies` を参照する。
- VM全体のデバイス構成、回路図対応、データの流れを確認する場合は `SYSinfo` を参照する。

