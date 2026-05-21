# List of Applications Required to Build LynxZ80

## Essential Applications

| Purpose             | Application / Tool                                   | Expected Path / Condition                                        | Usage                                     |
|---------------------|-----------------------------------------------------|------------------------------------------------------------------|-------------------------------------------|
| Script execution    | Windows PowerShell 7.6 or later                     | `powershell.exe` must be executable                              | All `.ps1`, and for `powershell -ExecutionPolicy Bypass -File ...` calls within scripts |
| Z80 Assembler       | Macro Assembler AS                                  | Must be installed and included in the `PATH`                     | All build scripts using `asw.exe`         |
| AS output conversion| `p2bin.exe`                                         | Same as above                                                    | All build scripts using `asw.exe`         |
| C++ main build      | Distribution build environment: <br />Visual Studio 2019 / Build Tools 2019 | Distribution build environment:<br />Platform Toolset `v141`     | `<repo>\vc++2017\lynxz80.vcxproj`         |
| Windows SDK         | Distribution build environment: <br />Windows 10 SDK | Distribution build environment: <br />`10.0.18362.0`             | `<repo>\vc++2017\lynxz80.vcxproj`         |

## Standard Libraries Used for C++ Linking

The `lynxz80.vcxproj` project links the following standard Windows libraries, which are usually included in the Visual Studio C++ toolchain and Windows SDK.

| Library       | Purpose                       |
|-------------- |------------------------------|
| `winmm.lib`   | Windows Multimedia API        |
| `imm32.lib`   | Input Method Manager API      |

## External Data / Source Dependencies

These are not applications, but if the indicated files are missing, the build scripts will halt.

| Purpose                           | File Name / Detail                  | Required | Usage                                  |
|------------------------------------|-------------------------------------|----------|----------------------------------------|
| CP/M 2.2 ASM source (unofficial)   | cpm2-asm.zip CPM22.Z80              | Required | `tool\lynxZ80\build_cpm22_disk.ps1`    |
| CP/M standard command binaries     | cpm22-b.zip (all except DISKMAINT.COM) | Optional (included only if present) | `tool\lynxZ80\build_cpm_utils.ps1`     |
| LynxZ80 build ASM set              | `<repo>\src\vm\Lynxz80\build\...`   | Required | ROM / disk image generation scripts    |

## Output Placement

Build artefacts such as ROMs and disk images are output to the following directory:

```
<repo>\src\vm\Lynxz80\build
```

`ROMCPY.ps1` copies generated ROMs to:

```
<repo>\vc++2017\bin\x86\Debug
<repo>\vc++2017\bin\x86\Release
```

`build_cpm_utils.ps1` copies the updated `CPM22_SYSTEM.IMG` to the Debug directory:

```
<repo>\vc++2017\bin\x86\Debug\CPM22_SYSTEM.IMG
```
