# PowerDiff.ps1 Manual

`PowerDiff.ps1` is a simple diff/patch tool that runs in PowerShell. It compares files or directories, displays differences, writes diff logs, creates unified diff patch files, and applies patches.

## Basic Syntax

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 <Left> <Right> [options]
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch <patch> -TargetPath <target> [options]
```

`Left` and `Right` are the comparison source and destination. They must both be files, or both be directories.

## File Comparison

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt
```

For text files, differences are shown line by line. The display is close to unified diff format, with left line number, right line number, and text shown together.

For binary files, SHA-256 hashes are compared. If the contents differ, both hashes are displayed.

## Directory Comparison

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new
```

By default, only files directly under the specified directories are compared. Use `-Recurse` to include subdirectories.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse
```

Directory comparison uses these markers.

| Marker | Meaning |
|---|---|
| `-` | Exists only on the `Left` side |
| `+` | Exists only on the `Right` side |
| `~` | Exists on both sides, but content or attributes differ |

After comparison, a summary shows `Only Left`, `Only Right`, `Changed`, and `Same`.

## Content Comparison

For directory comparison, the default change check uses file size and modification time. Use `-Content` to compare file contents.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content
```

Use `-Hash` to check changes by hash.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Hash
```

When `-PatchPath` is specified, content comparison is also performed so the patch can be generated.

## Ignoring Whitespace

`-IgnoreWhitespace` treats repeated whitespace as a single space and ignores leading and trailing whitespace.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -IgnoreWhitespace
```

This option affects line comparison. The output text remains the original line content.

## Context Lines

Use `-Context` to set how many surrounding context lines are shown before and after each difference. The default is `3`.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -Context 5
```

The valid range is `0` to `50`.

## Output Files

Use `-OutputPath` to save the diff display to a file.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content -OutputPath .\diff.log
```

Console color output is disabled when `-OutputPath` is specified.

Use `-NoColor` to disable color output only.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -NoColor
```

## Patch Creation

Use `-PatchPath` to create a unified diff patch file.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch
```

Text file additions, deletions, and updates are written to the patch. Binary file additions, deletions, and updates are not included.

A patch can also be created for a single file.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -PatchPath .\file.patch
```

## Patch Application

Use `-ApplyPatch` and `-TargetPath` to apply a patch to a target directory.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old
```

The `a/` and `b/` relative paths in the patch are resolved under `TargetPath`. For safety, paths outside `TargetPath` are rejected.

## Backups

When applying a patch, backups are created by default before files are changed. The default backup location is:

```text
<TargetPath>\.PowerDiffBackup\<yyyyMMdd_HHmmss>\
```

Use `-BackupRoot` to specify the backup destination.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -BackupRoot .\backup
```

Use `-NoBackup` to apply a patch without creating backups.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
```

## Overwrite and Delete Control

When applying a patch, adding a file fails if the target file already exists. Use `-Force` to allow overwriting.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -Force
```

Deleting a missing file also normally fails. With `-Force`, that deletion is skipped.

## Exit Codes

Use `-ExitCode` to return a result code.

| Exit code | Meaning |
|---|---|
| `0` | No differences, or patch applied successfully |
| `1` | Differences found |
| `2` | Error |

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -ExitCode
```

Use this for CI or batch processing when a difference check must be automated.

## Common Examples

Check a file difference.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt
```

Recursively compare directories and show content differences.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content
```

Create a patch from directory differences.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch
```

Apply a patch.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old
```

Apply a patch without backups.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
```

## Notes

- Patch creation and application target text files. Binary files are compared by hash in the diff display, but are not included in patches.
- Large text files may skip detailed line comparison and fall back to SHA-256 comparison.
- Patch application verifies that target file lines match the patch context. If they do not match, application fails.
- `-NoBackup` reduces recovery options. Keep the default backup behavior unless the target files can be regenerated reliably.
