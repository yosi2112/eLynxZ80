# eLynxZ80

eLynxZ80 is an emulator for the dual-Z80 CP/M computer “Lynx”, designed by Chiaki Nakajima, implemented on top of Toshiya Takeda's Common Source Code Project (CSCP).

This repository contains the Lynx-specific virtual machine implementation, a Visual Studio project, ROM sources, CP/M 2.2 build sources, and supporting build tools.

## Overview

Current implementation highlights:

- Main CPU and sub CPU: Z80
- CPU clock: 4 MHz
- Main RAM: 64 KB
- IPL/BIOS ROM: 8 KB
- Sub CPU ROM: 8 KB
- Sub CPU RAM: 2 KB
- Display: 640 × 400 at an implementation frame rate of 56.42 fps
- Two uPD7220-compatible GDCs: character and graphics
- MB8877-compatible FDC
- Two 2D floppy drives, 300 rpm, FM
- Z80 SIO, CTC, DMA, and PIO
- SIO-A external serial bridge: COM1–COM4 or TCP 127.0.0.1:8023
- Save states, debugger, and screen filtering

## Repository Layout

| Path | Description |
| --- | --- |
| `src/vm/Lynxz80/` | Lynx-specific virtual machine implementation |
| `src/vm/Lynxz80/docs/Programing Manual/` | Programming documentation |
| `tool/lynxZ80/` | ROM and CP/M build tools |
| `vc++2017/lynxz80.vcxproj` | Visual Studio project |
| `Requirements_EN_US.md` | Build requirements |

> [!NOTE]
> The existing repository directory is named `Programing Manual`. Document titles use the conventional spelling “Programming Manual”.

## Runtime Files

Place the following ROM files next to `lynxz80.exe`.

| File | Size | Purpose |
| --- | ---: | --- |
| `IPL.ROM` | 8192 bytes | Main CPU IPL/BIOS |
| `SUBCPU.ROM` | 8192 bytes | Sub CPU ROM |
| `FONT.ROM` | 8192 bytes | Character font ROM |

If `IPL.ROM` or `SUBCPU.ROM` is missing, the emulator initializes the corresponding ROM area with a safe fallback image to avoid uncontrolled execution. Normal Lynx operation, however, requires the proper ROM files.

If `FONT.ROM` is missing, the current renderer draws blank character patterns. A font ROM is therefore required for normal text display.

The current CP/M system-disk builder generates:

```text
tool/lynxZ80/bin/CPM22_SYSTEM.2d
```

## Starting the Emulator

1. Place `IPL.ROM`, `SUBCPU.ROM`, and `FONT.ROM` next to `lynxz80.exe`.
2. Start the emulator.
3. Insert `CPM22_SYSTEM.2d`, or another compatible 2D image, into Drive 0 (CP/M drive A:).
4. Reset the virtual machine if necessary.
5. The IPL loads the CP/M system area and starts CP/M 2.2.

Two floppy drives are implemented.

## Keyboard

Keyboard input is supplied through emulated Z80 SIO-B. The implementation supports ASCII, control characters, Caps Lock state, and a kana mapping modelled after an ALPS AKB-3320 Japanese keyboard.

| PC key | Input |
| --- | --- |
| `A`–`Z` | Letters with Shift/Caps handling |
| `0`–`9` | Digits and shifted symbols |
| `Enter` | CR (0Dh) |
| `Backspace` | BS (08h) |
| `Tab` | HT (09h) |
| `Esc` | ESC (1Bh) |
| `Delete` | DEL (7Fh) |
| `Ctrl+A`–`Ctrl+Z` | 01h–1Ah |
| Kana mode | 8-bit JIS X 0201 kana codes |

Punctuation mapping is based on Windows virtual-key codes and includes Japanese-keyboard layout handling.

## Building the Emulator

This repository does not contain the complete CSCP common source tree. The Visual Studio project references CSCP files such as `src/common.cpp`, `src/emu.cpp`, and the shared device implementations.

Overlay this repository on a compatible CSCP source tree before building `vc++2017/lynxz80.vcxproj`.

The project currently records the following build settings:

| Item | Setting |
| --- | --- |
| Visual Studio | Visual Studio 2019 / Build Tools 2019 expected |
| Platform Toolset | `v141` |
| Windows SDK | `10.0.18362.0` |
| Configurations | Debug / Release |
| Platforms | Win32 / x64 |
| Link libraries | `winmm.lib`, `imm32.lib` |

See [Requirements_EN_US.md](Requirements_EN_US.md).

## ROM and CP/M Build Tools

Current helper scripts are in `tool/lynxZ80/`.

| Script | Purpose |
| --- | --- |
| `build_ipl_rom.ps1` | Build and deploy `IPL.ROM` |
| `build_subcpu_rom.ps1` | Build `SUBCPU.ROM` |
| `build_fontrom.ps1` | Build `FONT.ROM` |
| `build_cpm22_env.ps1` | Prepare CP/M 2.2 sources and commands |
| `build_cpm22_runtime.ps1` | Build `CPM22_RUNTIME.BIN` |
| `build_cpm22_system_disk.ps1` | Build `CPM22_SYSTEM.2d` |
| `ROMCPY.ps1` | Copy ROMs into x86/x64 Debug/Release output directories |
| `diskeditor.ps1` | Edit current and legacy CP/M disk-image formats |

ROM and CP/M scripts are aligned with the current directory layout and can locate AS/p2bin through PATH. See [tool/lynxZ80/README.md](tool/lynxZ80/README.md) for options, output locations, and compatibility modes.

## External Files

The CP/M build process uses:

```text
cpm2-asm.zip
cpm22-b.zip
```

Place them in `tool/lynxZ80/build/arch/`. They are not included in this repository.

The default font-ROM builder expects:

```text
tool/lynxZ80/build/font/KH-Dot-Dougenzaka-16.ttf
```

The font file is not included in this repository.

## Documentation

- [Programming Manual](src/vm/Lynxz80/docs/Programing%20Manual/README.md)
- [CP/M 2.2 BIOS Call Reference](src/vm/Lynxz80/docs/Programing%20Manual/CP-M%20BIOS%20call%20reference/README.md)
- [uPD7220 GDC Programming Guide](src/vm/Lynxz80/docs/Programing%20Manual/GDC4Dummies/README.md)
- [eLynxZ80 System Information](src/vm/Lynxz80/docs/Programing%20Manual/SYSinfo/README.md)

## References

- [Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html)
- [Dual Z80 CP/M machine Lynx](https://www.chiaki.cc/Lynx/index.htm)
- [Chiaki's electronics site](https://www.chiaki.cc/)

## License

The repository root contains the GNU General Public License Version 3 in [LICENSE](LICENSE).

CSCP-derived files and external CP/M, font, or other third-party material may carry separate copyright notices and terms. Check the applicable source and distribution terms before redistribution.

## Contact

X: <https://x.com/yosi2112>
