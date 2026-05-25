# Lynx Emulator 'eLynxZ80' on Common Source Code Project

yosi with OpenAI Codex  
Version 1.0 Beta 1(260521)

## 1. What is this?

'eLynxZ80' is an emulator implementation for "Lynx", the dual Z80 CP/M machine created by Chiaki Nakajima, built on Takeda Toshiya's "Common Source Code Project".

This package contains the Lynx virtual machine implementation, a Visual Studio project, and support tools for generating BIOS/sub-CPU ROMs, a font ROM, and a CP/M 2.2 disk image.

Most of the code was created in collaboration with Codex (AI). The only material received from the Lynx author was the circuit diagram; the ROM source code, except for FONT.ROM, was also created in collaboration with AI.

For details about the "Common Source Code Project", see [Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html).

## 2. Why does it have a different name?

The original machine emulated here is "Lynx", the dual Z80 CP/M machine created by Chiaki Nakajima. However, the name "Lynx" alone can easily be confused with ATARI LYNX and with other computers or emulators using the same name.

For that reason, this emulator uses the distribution name 'eLynxZ80', combining "e" for emulator with Z80, the core CPU family of the target machine. Due to historical project naming, the source tree and project files may still contain spellings such as "LynxZ80" and "lynxz80"; these all refer to the same emulator.

For the original Lynx, see the author's page "[Dual Z80 CP/M system [Lynx]](https://www.chiaki.cc/Lynx/index_en.htm)".

## 3. What do I need?

'eLynxZ80' requires the following items.

### 3.1 Hardware

Operation is intended for Windows 10 or later, 32/64-bit editions.

### 3.2 Executable and ROM image files

To start the emulator, place the following files in the same folder as the executable file `lynxz80.exe`.

- `IPL.ROM`  
  IPL/BIOS ROM for the main CPU.
- `SUBCPU.ROM`  
  ROM for the sub CPU.
- `FONT.ROM`  
  Font ROM for display output. If this file is not present, the emulator uses its built-in initial values, but using a generated file is recommended for correct display behaviour.

### 3.3 Disk image file

To boot CP/M 2.2, insert the generated disk image `CPM22_SYSTEM.IMG` as a floppy disk.

The machine assumes a two-drive configuration.

## 4. What keys do I press?

'eLynxZ80' treats PC keyboard input as serial input.

| Key | Input |
| - | - |
| `A-Z` | Letter keys |
| `0-9` | Number keys |
| `Enter` | CR |
| `BackSpace` | BS |
| `Tab` | HT |
| `Esc` | ESC |
| `Space` | Space |
| `Delete` | DEL |
| `Ctrl+A` - `Ctrl+Z` | Control codes |

Symbol keys are translated to ASCII characters equivalent to a US keyboard layout. Caps Lock and Kana Lock states are also held on the emulator side.

## 5. How do I build it?

The source files included in this package can be built by overlaying them onto the "Common Source Code Project" source tree. Open `vc++2017/lynxz80.vcxproj` in Visual Studio.

The distributed project settings assume the following environment.

- Visual Studio 2019 / Build Tools 2019
- Platform Toolset `v141`
- Windows 10 SDK `10.0.18362.0`
- `winmm.lib` / `imm32.lib`

The following tools are required to generate ROMs and CP/M disk images.

- Windows PowerShell
- Macro Assembler AS (`asw.exe`)
- `p2bin.exe`

AS can be obtained from the following pages.

- [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/)

Support scripts are located under `tool/lynxZ80`.

| Script | Description |
| - | - |
| `buildall.ps1` | Generates the BIOS ROM, sub-CPU ROM, CP/M 2.2 disk, and CP/M utilities in sequence. |
| `build_biosrom.ps1` | Generates `src/vm/Lynxz80/build/IPL.ROM`. |
| `build_subcpu_rom.ps1` | Generates `src/vm/Lynxz80/build/SUBCPU.ROM`. |
| `build_fontrom.ps1` | Generates `src/vm/Lynxz80/build/font/FONT.ROM`. |
| `ROMCPY.ps1` | Copies generated ROMs to `vc++2017/bin/x86/Debug` or `vc++2017/bin/x86/Release`. |

Generating the font ROM requires `KH-Dot-Dougenzaka-16.ttf` separately. This repository does not redistribute the font file or generated font ROM data. To build the font ROM, download `KH-Dot-Dougenzaka-16.ttf` separately from its distribution site and place it under `tool/lynxZ80/build/font`, or pass its location with `build_fontrom.ps1` and `-FontPath`.

`KH-Dot-Dougenzaka-16.ttf` is licensed separately under the SIL Open Font License 1.1. Generated font ROM data derived from that font should be treated under the same licence when redistributed.

The font can be obtained from the following pages.

- [KH Dot Font Series](http://jikasei.me/font/kh-dotfont/)
- [KH Dot Font - Font Meme](https://fontmeme.com/fonts/kh-dot-font/)

Generating the CP/M 2.2 disk also requires `cpm2-asm.zip` and `cpm22-b.zip`. Place these files in `tool/lynxZ80/build/arch`.

CP/M-related files can be obtained from the following pages.

- [The Unofficial CP/M Web Site](http://www.cpm.z80.de/)

For the Lynx machine itself, also see the following pages.

- [放課後の電子工作　～　会社でハンダ付け、自宅でもハンダ付け　～](https://www.chiaki.cc/)
- [Dual Z80 CP/M system [Lynx]](https://www.chiaki.cc/Lynx/index_en.htm)

## 6. Copyright notice

This package contains source files based on the "Common Source Code Project" and source files added for Lynx Z80.

Use and redistribution are governed by the copyright notices in each source file and by the methods and conditions specified by the maintainer of the "Common Source Code Project".

External archives and standard command files related to CP/M 2.2 are covered by separate rights and conditions. Users must confirm the lawful source and terms of use for those materials themselves.

## 7. Contact

X (formerly Twitter): <https://x.com/yosi2112>

For the "Common Source Code Project", see [Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html).
