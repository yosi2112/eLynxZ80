# lynxZ80 ツールスクリプト説明

対象: `<repo>\tool\lynxZ80\*.ps1` と `<repo>\tool\lynxZ80\*.c`

確認時点では、対象ディレクトリ直下に `.ps1` は12件あります。`.c` ファイルは検出されませんでした。

## ビルド系スクリプト

| ファイル | 目的 | 主な入力 | 主な出力 |
|---|---|---|---|
| `buildall.ps1` | ROM、CP/Mディスク、CP/Mユーティリティを順番に生成する統合ビルド入口です。`tool\lynxZ80\build\arch` 内の必須アーカイブと、PATH上の `asw.exe` / `p2bin.exe` を確認します。 | `tool\lynxZ80\build\arch\cpm2-asm.zip`, `tool\lynxZ80\build\arch\cpm22-b.zip`, 各個別ビルドスクリプト | `src\vm\Lynxz80\build` 配下のROM/IMG/COM関連成果物 |
| `build_biosrom.ps1` | メインBIOS ROMを生成します。`biosrom.asm` と `cpm22bios_runtime.asm` をアセンブルし、ランタイムBIOS領域をROMイメージへ重ねます。 | `build\bios\biosrom.asm`, `build\bios\cpm22bios_runtime.asm`, `asw.exe`, `p2bin.exe` | `IPL.ROM` |
| `build_subcpu_rom.ps1` | サブCPU ROMを生成します。 | `build\subcpu\subcpurom.asm`, `asw.exe`, `p2bin.exe` | `SUBCPU.ROM` |
| `build_diag_roms.ps1` | 診断用のメイン/サブCPU ROMを生成します。`-Install` 指定時は通常ROM名へコピーします。 | `build\diag\diag_main.asm`, `build\diag\diag_subcpu.asm`, `asw.exe`, `p2bin.exe` | `DIAGMAIN.ROM`, `DIAGSUB.ROM`, 任意で `IPL.ROM`, `SUBCPU.ROM` |
| `build_cpm22_disk.ps1` | CP/M 2.2システムディスクイメージを生成します。必要に応じてCP/Mソースアーカイブを展開し、`CPM22.Z80` には `correct_nmemonic.ps1` を適用します。さらに標準コマンドアーカイブを展開し、準備済みCP/M本体とLynxZ80用ランタイムBIOSを組み合わせ、BIOSジャンプテーブルを補正します。 | `tool\lynxZ80\build\arch\cpm2-asm.zip`, `tool\lynxZ80\build\arch\cpm22-b.zip`, `src\vm\Lynxz80\build\bios\cpm22bios_runtime.asm`, `asw.exe`, `p2bin.exe` | `CPM22_SYSTEM.IMG`, 準備済み `src\vm\Lynxz80\build\cpm22disk\CPM22_z80.ASM`, 展開済み `tool\lynxZ80\build\cpm22-b` |
| `build_cpm_utils.ps1` | ローカルCP/MユーティリティをCOM形式に変換し、repo内に配置された標準コマンドと共に `CPM22_SYSTEM.IMG` へ取り込みます。 | `src\vm\Lynxz80\build\cpmutils\*.ASM`, `tool\lynxZ80\build\cpm22-b` の標準COM、`diskeditor.ps1` | 更新済み `CPM22_SYSTEM.IMG`, `src\vm\Lynxz80\build\cpmutils\*.COM` |
| `build_gvram_test_disk.ps1` | GVRAMテスト用COMをビルドし、CP/Mシステムディスクを複製してテスト用ディスクイメージを作ります。 | `build\gvramtest\GVRAMTST.ASM`, `README.TXT`, `CPM22_SYSTEM.IMG`, `diskeditor.ps1` | `GVRAM_TEST_BOOT.IMG`, `build\gvramtest\GVRAMTST.COM` |
| `build_fontrom.ps1` | TrueTypeフォントからLynxZ80用 `FONT.ROM` を生成します。フォントサイズ、X/Yオフセット、しきい値、バンク別出力を指定できます。 | `build\font\KH-Dot-Dougenzaka-16.ttf` または `-FontPath` 指定フォント | `build\font\FONT.ROM`, 任意でバンク別ファイル |

## 補助ツール

| ファイル | 目的 | 主な操作 |
|---|---|---|
| `diskeditor.ps1` | CP/Mディスクイメージ内のファイルを操作するツールです。`Help`, `Info`, `List`, `Import`, `Export`, `Delete` を提供します。 | `-Image` で対象イメージを指定し、COM/TXT等をインポート、エクスポート、削除します。 |
| `ROMCPY.ps1` | 生成済みROMをVisual C++実行ディレクトリへコピーします。`-diag` 指定時は診断ROMをDebug側へ導入します。 | `IPL.ROM`, `SUBCPU.ROM`, `DIAGMAIN.ROM`, `DIAGSUB.ROM` のコピー |
| `correct_nmemonic.ps1` | CP/Mソース `CPM22.Z80` 内の8080形式 `M` レジスタ表記をZ80形式 `(HL)` に変換し、`CPM22_z80.ASM` へリネームします。 | 変換前ファイルのバックアップ、ニーモニック表記変換 |
| `PowerDiff.ps1` | PowerShell製のdiff/patchツールです。ファイルまたはフォルダ比較、再帰比較、パッチ生成、パッチ適用に対応します。 | `-Recurse`, `-Content`, `-Hash`, `-PatchPath`, `-ApplyPatch`, `-TargetPath` など |

## 実行順序の目安

通常ビルドでは `buildall.ps1` が以下の順序で個別スクリプトを呼び出します。

1. `build_biosrom.ps1`
2. `build_subcpu_rom.ps1`
3. `ROMCPY.ps1`
4. `build_cpm22_disk.ps1`
5. `build_cpm_utils.ps1`

必要に応じて `build_diag_roms.ps1`, `build_gvram_test_disk.ps1`, `build_fontrom.ps1`, `correct_nmemonic.ps1` を個別に実行します。

## 注意事項

- `asw.exe` と `p2bin.exe` はZ80関連スクリプトの必須ツールです。
- `build_fontrom.ps1` で `FONT.ROM` を生成するには `KH-Dot-Dougenzaka-16.ttf` が別途必要です。このリポジトリではフォントファイルおよび生成済みフォントROMデータを再配布していません。フォントは [KHドットフォントシリーズ](http://jikasei.me/font/kh-dotfont/) または [KH Dot Font - Font Meme](https://fontmeme.com/fonts/kh-dot-font/) から入手し、`tool\lynxZ80\build\font` に配置するか `-FontPath` で指定してください。
- `KH-Dot-Dougenzaka-16.ttf` は SIL Open Font License 1.1 に基づき別途ライセンスされています。このフォントから生成されたフォントROMデータを再配布する場合、そのデータも同ライセンスに基づくものとして扱ってください。
- `cpm2-asm.zip` と `cpm22-b.zip` は `tool\lynxZ80\build\arch` に置きます。`build_cpm22_disk.ps1` が必要に応じて展開します。
- `cpm2-asm.zip` 内に `CPM22.Z80` がある場合、`build_cpm22_disk.ps1` は `correct_nmemonic.ps1` を呼び出して `CPM22_z80.ASM` を作成します。
- CP/M標準コマンドは `tool\lynxZ80\build\cpm22-b` に展開されます。`build_cpm_utils.ps1` はこのフォルダが存在する場合に取り込みます。
- `diskeditor.ps1` は既定イメージを持ちません。`-Image` 未指定時はヘルプを表示します。
