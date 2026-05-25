# PowerDiff.ps1 マニュアル

`PowerDiff.ps1` は、PowerShell で動作する簡易 diff/patch ツールです。ファイル同士またはフォルダ同士を比較し、差分表示、差分ログ出力、unified diff 形式のパッチ生成、パッチ適用を行えます。

## 基本構文

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 <Left> <Right> [options]
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch <patch> -TargetPath <target> [options]
```

`Left` と `Right` は、比較元と比較先です。どちらもファイル、またはどちらもフォルダである必要があります。

## ファイル比較

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt
```

テキストファイルの場合は、行単位で差分を表示します。表示形式は unified diff に近い形式ですが、左側行番号、右側行番号、本文を並べて表示します。

バイナリファイルの場合は、SHA-256 ハッシュを比較します。内容が異なる場合は両方のハッシュを表示します。

## フォルダ比較

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new
```

既定では、指定フォルダ直下のファイルを比較します。サブフォルダも含める場合は `-Recurse` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse
```

フォルダ比較では、以下の記号で差分を表示します。

| 記号 | 意味 |
|---|---|
| `-` | `Left` 側にのみ存在 |
| `+` | `Right` 側にのみ存在 |
| `~` | 両方に存在するが内容または属性が異なる |

比較後には、`Only Left`、`Only Right`、`Changed`、`Same` の集計が表示されます。

## 内容比較の指定

フォルダ比較では、既定ではサイズと更新時刻を使って変更有無を判定します。ファイル内容で比較したい場合は `-Content` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content
```

ハッシュで変更有無を判定したい場合は `-Hash` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Hash
```

`-PatchPath` を指定した場合も、パッチ生成のため内容比較が行われます。

## 空白差分の無視

`-IgnoreWhitespace` を指定すると、連続する空白を1つの空白として扱い、前後の空白も無視します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -IgnoreWhitespace
```

この指定は行比較の判定に影響します。出力される本文は元の行内容です。

## コンテキスト行数

差分前後に表示する文脈行数は `-Context` で指定します。既定値は `3` です。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -Context 5
```

指定可能範囲は `0` から `50` です。

## 結果のファイル出力

差分表示をファイルへ保存する場合は `-OutputPath` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content -OutputPath .\diff.log
```

`-OutputPath` 指定時は、コンソールカラー表示は無効になります。

カラー表示だけを無効にしたい場合は `-NoColor` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -NoColor
```

## パッチ生成

`-PatchPath` を指定すると、unified diff 形式のパッチファイルを生成します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch
```

テキストファイルの追加、削除、更新はパッチに出力されます。バイナリファイルの追加、削除、更新はパッチ対象外です。

単一ファイルのパッチも生成できます。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -PatchPath .\file.patch
```

## パッチ適用

`-ApplyPatch` と `-TargetPath` を指定すると、パッチを対象フォルダへ適用します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old
```

パッチ内の `a/` と `b/` の相対パスは、`TargetPath` 配下のパスとして解決されます。安全のため、`TargetPath` の外へ出るパスは拒否されます。

## バックアップ

パッチ適用時は、既定で変更前ファイルのバックアップを作成します。バックアップ先は以下です。

```text
<TargetPath>\.PowerDiffBackup\<yyyyMMdd_HHmmss>\
```

バックアップ先を明示する場合は `-BackupRoot` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -BackupRoot .\backup
```

バックアップを作成しない場合は `-NoBackup` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
```

## 上書きと削除の制御

パッチ適用時、追加対象のファイルが既に存在する場合はエラーになります。上書きを許可する場合は `-Force` を指定します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -Force
```

削除対象のファイルが存在しない場合も通常はエラーになります。`-Force` 指定時は、この削除はスキップされます。

## 終了コード

`-ExitCode` を指定すると、結果に応じて終了コードを返します。

| 終了コード | 意味 |
|---|---|
| `0` | 差分なし、またはパッチ適用成功 |
| `1` | 差分あり |
| `2` | エラー |

例:

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -ExitCode
```

CI やバッチ処理で差分検出を判定したい場合に使用します。

## 代表的な使用例

ファイル差分を確認します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt
```

フォルダを再帰的に比較し、内容差分まで表示します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content
```

フォルダ差分からパッチを作成します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch
```

パッチを適用します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old
```

バックアップなしでパッチを適用します。

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
```

## 注意事項

- パッチ生成と適用はテキストファイルを対象とします。バイナリファイルは差分表示ではハッシュ比較されますが、パッチには含まれません。
- 大きなテキストファイルでは、行単位の詳細比較が省略され、SHA-256 比較に切り替わる場合があります。
- パッチ適用は、対象ファイルの行内容がパッチの文脈行と一致することを確認します。一致しない場合は適用に失敗します。
- `-NoBackup` は復元手段を減らします。確実に再生成できるファイル以外では、通常は既定のバックアップ有効状態を推奨します。
