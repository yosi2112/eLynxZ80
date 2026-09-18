# eLynxZ80 Build Requirements

This document describes the current requirements for building the eLynxZ80 emulator, ROM images, and CP/M 2.2 system disk.

## 1. Emulator Build

The settings recorded in `vc++2017/lynxz80.vcxproj` are:

| Item | Setting |
| --- | --- |
| IDE / Build Tools | Visual Studio 2019 / Build Tools 2019 expected |
| Platform Toolset | `v141` |
| Windows SDK | `10.0.18362.0` |
| Configurations | Debug / Release |
| Platforms | Win32 / x64 |
| Additional libraries | `winmm.lib`, `imm32.lib` |

### Common Source Code Project

This repository does not contain the full CSCP common source tree. The project references files such as:

```text
src/common.cpp
src/config.cpp
src/emu.cpp
src/fileio.cpp
src/vm/z80.cpp
src/vm/upd7220.cpp
src/win32/winmain.cpp
...
```

Overlay the eLynxZ80 files on a compatible CSCP source tree before building.

## 2. ROM and CP/M Tools

The PowerShell helper scripts use the following tools.

| Tool | Purpose |
| --- | --- |
| Windows PowerShell / PowerShell | Run `.ps1` scripts |
| Macro Assembler AS (`asw.exe`) | Assemble Z80 sources |
| `p2bin.exe` | Convert AS output to ROM/binary images |
| Git | Apply the CP/M source patch in `build_cpm22_env.ps1` |
| .NET `System.Drawing` | Render glyphs in `build_fontrom.ps1` |

> [!IMPORTANT]
> Tool lookup is not yet consistent across all scripts. `build_ipl_rom.ps1` and `build_cpm22_runtime.ps1` contain developer-local defaults under `E:\aswcurr\bin`, while other scripts refer directly to `asw.exe` and `p2bin.exe`. Review or override the paths before use.

## 3. External Files

Place the following archives in `tool/lynxZ80/build/arch/`:

```text
cpm2-asm.zip
cpm22-b.zip
```

| Archive | Use |
| --- | --- |
| `cpm2-asm.zip` | Supplies `CPM22.Z80` |
| `cpm22-b.zip` | Supplies standard CP/M commands including ASM, DDT, ED, LOAD, PIP, STAT, SUBMIT, and XSUB |

The archives are not distributed in this repository.

The default font builder expects:

```text
tool/lynxZ80/build/font/KH-Dot-Dougenzaka-16.ttf
```

Use `-FontPath` to select a font from another location.

## 4. Current Build Outputs

| Output | Default location |
| --- | --- |
| `IPL.ROM` | `tool/lynxZ80/bin/IPL.ROM` |
| `SUBCPU.ROM` | `src/vm/Lynxz80/build/SUBCPU.ROM` |
| `FONT.ROM` | `tool/lynxZ80/build/font/FONT.ROM` |
| `CPM22_RUNTIME.BIN` | `tool/lynxZ80/bin/CPM22_RUNTIME.BIN` |
| `CPM22_SYSTEM.2d` | `tool/lynxZ80/bin/CPM22_SYSTEM.2d` |

> [!NOTE]
> Output locations are not yet fully standardised between scripts. `ROMCPY.ps1` expects `IPL.ROM` and `SUBCPU.ROM` under `src/vm/Lynxz80/build/`, while `build_ipl_rom.ps1` writes its primary copy under `tool/lynxZ80/bin/`.

## 5. Current CP/M System-Disk Format

`build_cpm22_system_disk.ps1` generates a disk with these parameters:

| Item | Value |
| --- | ---: |
| Cylinders | 40 |
| Sides | 2 |
| Sectors per side | 16 |
| Physical sector size | 256 bytes |
| Total size | 327680 bytes |
| CP/M logical SPT | 64 × 128 bytes |
| Reserved cylinders | 2 |
| Allocation block | 2048 bytes |
| Directory entries | 128 |
| DSM | 151 |
| DRM | 127 |

These values correspond to the DPB in the current `tool/lynxZ80/build/bios/bios.asm`.

## 6. Known Path and Format Mismatches

The repository currently contains a few helper scripts that have not been fully aligned after directory/layout changes.

- `build_cpm22_env.ps1` refers to `build\util` and `build\bin\cpmutil`, while the current tree contains local utility sources under `build/cpmutils/`.
- `build_cpm22_system_disk.ps1` looks for optional COM files under `tool/lynxZ80/bin/cpmutils/`.
- `diskeditor.ps1` targets an older 77-track, 26-sector, 128-byte-sector, 1 KB-block format and is not compatible with the current `CPM22_SYSTEM.2d`.
- `ROMCPY.ps1` and `build_ipl_rom.ps1` use different default locations for `IPL.ROM`.

See [tool/lynxZ80/README.md](tool/lynxZ80/README.md) for the current tool-by-tool details.
