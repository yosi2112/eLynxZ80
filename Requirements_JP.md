# LynxZ80 ビルドに必要なアプリ一覧

## 必須アプリ

|用途|アプリ / ツール|想定パス・条件|使用箇所|
|-|-|-|-|
|スクリプト実行|Windows PowerShell 7.6以降|`powershell.exe` が実行可能であること|全 `.ps1`、およびスクリプト内からの `powershell -ExecutionPolicy Bypass -File ...` 呼び出し|
|Z80 アセンブル|Macro Assembler AS|インストール済み<br />かつ<br />PATHが通っている|`asw.exe` を使う全ビルドスクリプト|
|AS 出力のバイナリ変換|`p2bin.exe`|同上|`asw.exe` を使う全ビルドスクリプト|
|C++ 本体ビルド|配布バイナリのビルド環境:<br />Visual Studio 2019 / Build Tools 2019|配布バイナリのビルド環境:<br />Platform Toolset `v141`|`<repo>\vc++2017\lynxz80.vcxproj`|
|Windows SDK|配布バイナリのビルド環境:<br />Windows 10 SDK|配布バイナリのビルド環境:<br />`10.0.18362.0`|`<repo>\vc++2017\lynxz80.vcxproj`|

## C++ リンクで使う標準ライブラリ

`lynxz80.vcxproj` では以下の Windows 標準ライブラリをリンクします。通常は Visual Studio C++ ツールチェーンと Windows SDK に含まれます。

|ライブラリ|用途|
|-|-|
|`winmm.lib`|Windows Multimedia API|
|`imm32.lib`|Input Method Manager API|

## 外部データ / ソース依存

アプリではありませんが、該当ファイルが無い場合はビルドスクリプトが停止します。

|用途|ファイル名|必須度|使用箇所|
|-|-|-|-|
|CP/M 2.2 ASMソース(非公式)|cpm2-asm.zip CPM22.Z80|必須|`tool\lynxZ80\build_cpm22_disk.ps1`|
|CP/M 標準コマンド|cpm22-b.zip DISKMAINT.COM以外すべて|任意。存在する場合のみ取り込み|`tool\lynxZ80\build_cpm_utils.ps1`|
|LynxZ80 ビルド用 ASM 群|`<repo>\src\vm\Lynxz80\build\...`|必須|ROM / ディスク生成スクリプト|

## 生成物の配置

ROM やディスクイメージなどのビルド成果物は以下へ出力されます。

```text
<repo>\src\vm \Lynxz80\build
```

`ROMCPY.ps1` は生成済み ROM を以下へコピーします。

```text
<repo>\vc++2017\bin\x86\Debug
<repo>\vc++2017\bin\x86\Release
```

`build_cpm_utils.ps1` は更新した `CPM22_SYSTEM.IMG` を Debug 側へコピーします。

```text
<repo>\vc++2017\bin\x86\Debug\CPM22_SYSTEM.IMG
```

