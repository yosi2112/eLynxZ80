# Listo de Bezonataj Aplikoj por Konstrui LynxZ80

## Devigaj Aplikoj

| Celo                | Aplikaĵo / Ilo                                  | Atendata Vojo / Kondiĉo                                    | Uzado                                      |
|---------------------|-------------------------------------------------|------------------------------------------------------------|---------------------------------------------|
| Skripta rulado      | Windows PowerShell 7.6 aŭ pli nova              | `powershell.exe` devas esti ebligebla                      | Ĉiuj `.ps1` kaj `powershell -ExecutionPolicy Bypass -File ...` vokoj en skriptoj |
| Z80 Asemblero       | Macro Assembler AS                              | Deve instalita kaj en la `PATH`                            | Ĉiuj skriptoj kiuj uzas `asw.exe`           |
| Konvertado de AS-eligo | `p2bin.exe`                                  | Kiel supre                                                | Ĉiuj skriptoj kiuj uzas `asw.exe`           |
| C++ ĉefa konstruo   | Distribua konstrua medio:<br />Visual Studio 2019 / Build Tools 2019 | Distribua konstrua medio:<br />Platform Toolset `v141`     | `<repo>\vc++2017\lynxz80.vcxproj`           |
| Windows SDK         | Distribua konstrua medio:<br />Windows 10 SDK   | Distribua konstrua medio:<br />`10.0.18362.0`              | `<repo>\vc++2017\lynxz80.vcxproj`           |

## Normaj Bibliotekoj Uzataj por C++ Ligado

La projekto `lynxz80.vcxproj` ligas la jenajn Windows-ajn bibliotekojn, kiuj kutime estas inkluditaj en la Visual Studio C++ ilĉeno kaj Windows SDK.

| Biblioteko      | Celo                             |
|-----------------|----------------------------------|
| `winmm.lib`     | Windows Multimedia API           |
| `imm32.lib`     | Input Method Manager API         |

## Eksteraj Datumoj / Fontodependaĵoj

Ne estas aplikoj, sed se la indikitaj dosieroj mankas, la konstru-skriptoj haltos.

| Celo                           | Dosiernomo / Detalo                 | Bezonata | Uzado                                  |
|--------------------------------|-------------------------------------|----------|-----------------------------------------|
| CP/M 2.2 ASM fonto (neoficiala)| cpm2-asm.zip CPM22.Z80              | Jes      | `tool\lynxZ80\build_cpm22_disk.ps1`    |
| CP/M normaj komandoj           | cpm22-b.zip (ĉio escepte DISKMAINT.COM) | Nedeviga (enmetita se ekzistas) | `tool\lynxZ80\build_cpm_utils.ps1` |
| LynxZ80 konstru ASM-kolekto    | `<repo>\src\vm\Lynxz80\build\...`   | Jes      | ROM / diska bildgenerado-skriptoj                      |

## Loko de Eligaĵoj

Konstruitaj produktoj kiel ROM-oj kaj diskbildoj estas metitaj ĉi tie:

```
<repo>\src\vm\Lynxz80\build
```

`ROMCPY.ps1` kopias la generitajn ROM-dosierojn al:

```
<repo>\vc++2017\bin\x86\Debug
<repo>\vc++2017\bin\x86\Release
```

`build_cpm_utils.ps1` kopias la aktualigitan `CPM22_SYSTEM.IMG` al la Debug-dosierujo:

```
<repo>\vc++2017\bin\x86\Debug\CPM22_SYSTEM.IMG
```
