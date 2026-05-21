# List of Applications Required to Build LynxZ80

## Essential Applications

| Purpose               | Application / Tool                                  | Expected Path / Condition                                      | Usage                                    |
|-----------------------|-----------------------------------------------------|----------------------------------------------------------------|------------------------------------------|
| Script Execution      | Windows PowerShell 7.6 or later                     | `powershell.exe` must be executable                            | All `.ps1` scripts, and any calls to `powershell -ExecutionPolicy Bypass -File ...` inside scripts |
| Z80 Assembler         | Macro Assembler AS                                  | Must be installed and on the `PATH`                            | All build scripts using `asw.exe`        |
| AS Output Conversion  | `p2bin.exe`                                         | Same as above                                                  | All build scripts using `asw.exe`        |
| C++ Core Build        | Distribution build environment:<br />Visual Studio 2019 / Build Tools 2019 | Distribution build environment:<br />Platform Toolset `v141`   | `<repo>\vc++2017\lynxz80.vcxproj`        |
| Windows SDK           | Distribution build environment:<br />Windows 10 SDK | Distribution build environment:<br />`10.0.18362.0`            | `<repo>\vc++2017\lynxz80.vcxproj`        |

## Standard Libraries Used for C++ Linking

The `lynxz80.vcxproj` project links the following Windows standard libraries, which are usually included in the Visual Studio C++ toolchain and Windows SDK.

| Library         | Purpose                       |
|-----------------|------------------------------|
| `winmm.lib`     | Windows Multimedia API        |
| `imm32.lib`     | Input Method Manager API      |

## External Data / Source Dependencies

These are not applications, but if the relevant files are missing, the build scripts will stop.

| Purpose                         | File Name / Detail                   | Required  | Usage                                   |
|----------------------------------|--------------------------------------|-----------|-----------------------------------------|
| CP/M 2.2 ASM source (unofficial) | cpm2-asm.zip CPM22.Z80               | Required  | `tool\lynxZ80\build_cpm22_disk.ps1`     |
| CP/M Standard Command Binaries   | cpm22-b.zip (everything except DISKMAINT.COM) | Optional (incorporated if present) | `tool\lynxZ80\build_cpm_utils.ps1`      |
| LynxZ80 build ASM Set            | `<repo>\src\vm\Lynxz80\build\...`    | Required  | ROM / disk image generation scripts     |

## Output Location

Build artifacts (ROMs and disk images) are output to:

```
<repo>\src\vm\Lynxz80\build
```

`ROMCPY.ps1` copies generated ROM images to:

```
<repo>\vc++2017\bin\x86\Debug
<repo>\vc++2017\bin\x86\Release
```

`build_cpm_utils.ps1` copies the updated `CPM22_SYSTEM.IMG` to the Debug directory:

```
<repo>\vc++2017\bin\x86\Debug\CPM22_SYSTEM.IMG
```
