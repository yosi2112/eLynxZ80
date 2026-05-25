# Manlibro de PowerDiff.ps1

`PowerDiff.ps1` estas simpla diff/patch-ilo funkcianta en PowerShell. Ĝi komparas dosierojn aŭ dosierujojn, montras diferencojn, skribas diff-protokolojn, kreas unified diff-flikdosierojn, kaj aplikas flikojn.

## Baza sintakso

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 <Left> <Right> [options]
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch <patch> -TargetPath <target> [options]
```

`Left` kaj `Right` estas la kompara fonto kaj celo. Ambaŭ devas esti dosieroj, aŭ ambaŭ devas esti dosierujoj.

## Dosiera komparo

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt
```

Por tekstaj dosieroj, diferencoj estas montrataj linio post linio. La montrado similas al unified diff-formato, kun maldekstra linionumero, dekstra linionumero kaj teksto kune.

Por binaraj dosieroj, SHA-256-haketoj estas komparataj. Se la enhavo malsamas, ambaŭ haketoj estas montrataj.

## Dosieruja komparo

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new
```

Defaŭlte, nur dosieroj rekte sub la donitaj dosierujoj estas komparataj. Uzu `-Recurse` por inkluzivi subdosierujojn.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse
```

Dosieruja komparo uzas ĉi tiujn markojn.

| Marko | Signifo |
|---|---|
| `-` | Ekzistas nur ĉe la flanko `Left` |
| `+` | Ekzistas nur ĉe la flanko `Right` |
| `~` | Ekzistas ĉe ambaŭ flankoj, sed enhavo aŭ atributoj malsamas |

Post komparo, resumo montras `Only Left`, `Only Right`, `Changed` kaj `Same`.

## Enhava komparo

Por dosieruja komparo, la defaŭlta ŝanĝokontrolo uzas dosiergrandon kaj modifan tempon. Uzu `-Content` por kompari dosierenhavon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content
```

Uzu `-Hash` por kontroli ŝanĝojn per haketo.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Hash
```

Kiam `-PatchPath` estas specifita, enhava komparo ankaŭ estas farata por generi la flikon.

## Ignorado de blankspaco

`-IgnoreWhitespace` traktas ripetitan blankspacon kiel unu spacon kaj ignoras komencan kaj finan blankspacon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -IgnoreWhitespace
```

Ĉi tiu opcio influas linian komparon. La eligata teksto restas la originala linienhavo.

## Kuntekstaj linioj

Uzu `-Context` por agordi kiom da ĉirkaŭaj kuntekstaj linioj estas montrataj antaŭ kaj post ĉiu diferenco. La defaŭlto estas `3`.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -Context 5
```

La valida intervalo estas `0` ĝis `50`.

## Eligo al dosiero

Uzu `-OutputPath` por konservi la diff-montradon en dosieron.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content -OutputPath .\diff.log
```

Kolora konzola eligo estas malŝaltita kiam `-OutputPath` estas specifita.

Uzu `-NoColor` por malŝalti nur koloran eligon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -NoColor
```

## Flikkreado

Uzu `-PatchPath` por krei unified diff-flikdosieron.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch
```

Aldonoj, forigoj kaj ĝisdatigoj de tekstaj dosieroj estas skribitaj en la flikon. Aldonoj, forigoj kaj ĝisdatigoj de binaraj dosieroj ne estas inkluzivitaj.

Fliko ankaŭ povas esti kreita por unu sola dosiero.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt -PatchPath .\file.patch
```

## Flikapliko

Uzu `-ApplyPatch` kaj `-TargetPath` por apliki flikon al cela dosierujo.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old
```

La relativaj vojoj `a/` kaj `b/` en la fliko estas solvataj sub `TargetPath`. Pro sekureco, vojoj ekster `TargetPath` estas rifuzataj.

## Sekurkopioj

Dum flikapliko, sekurkopioj estas defaŭlte kreataj antaŭ ol dosieroj estas ŝanĝitaj. La defaŭlta sekurkopia loko estas:

```text
<TargetPath>\.PowerDiffBackup\<yyyyMMdd_HHmmss>\
```

Uzu `-BackupRoot` por specifi la sekurkopian celon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -BackupRoot .\backup
```

Uzu `-NoBackup` por apliki flikon sen krei sekurkopiojn.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
```

## Kontrolo de anstataŭigo kaj forigo

Dum flikapliko, aldono de dosiero malsukcesas se la cela dosiero jam ekzistas. Uzu `-Force` por permesi anstataŭigon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -Force
```

Forigo de mankanta dosiero ankaŭ normale malsukcesas. Kun `-Force`, tia forigo estas preterlasita.

## Elirkodoj

Uzu `-ExitCode` por redoni rezultan kodon.

| Elirkodo | Signifo |
|---|---|
| `0` | Neniu diferenco, aŭ fliko sukcese aplikita |
| `1` | Diferencoj trovitaj |
| `2` | Eraro |

Ekzemplo:

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -ExitCode
```

Uzu tion por CI aŭ bata prilaborado kiam diferencokontrolo devas esti aŭtomatigita.

## Oftaj ekzemploj

Kontroli dosieran diferencon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old.txt .\new.txt
```

Rekursie kompari dosierujojn kaj montri enhavajn diferencojn.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -Content
```

Krei flikon el dosierujaj diferencoj.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 .\old .\new -Recurse -PatchPath .\changes.patch
```

Apliki flikon.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old
```

Apliki flikon sen sekurkopioj.

```powershell
powershell -ExecutionPolicy Bypass -File .\PowerDiff.ps1 -ApplyPatch .\changes.patch -TargetPath .\old -NoBackup
```

## Notoj

- Flikkreado kaj flikapliko celas tekstajn dosierojn. Binaraj dosieroj estas komparataj per haketo en la diff-montrado, sed ne estas inkluzivitaj en flikoj.
- Grandaj tekstaj dosieroj povas preterlasi detalan linian komparon kaj uzi SHA-256-komparon anstataŭe.
- Flikapliko kontrolas, ke la celaj dosierlinioj kongruas kun la flika kunteksto. Se ili ne kongruas, aplikado malsukcesas.
- `-NoBackup` reduktas restaŭrajn eblojn. Konservu la defaŭltan sekurkopian konduton krom se la celaj dosieroj povas esti fidinde regeneritaj.
