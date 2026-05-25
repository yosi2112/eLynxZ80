# lynxZ80 Tool Script Descriptions

Scope: `<repo>\tool\lynxZ80\*.ps1` and `<repo>\tool\lynxZ80\*.c`

At the time of inspection, the target directory contains twelve `.ps1` files. No `.c` files were found.

## Build Scripts

| File | Purpose | Main inputs | Main outputs |
|---|---|---|---|
| `buildall.ps1` | Top-level build entry point for ROMs, the CP/M disk, and CP/M utilities. It checks the required archives in `tool\lynxZ80\build\arch` and verifies that `asw.exe` and `p2bin.exe` are available on `PATH`. | `tool\lynxZ80\build\arch\cpm2-asm.zip`, `tool\lynxZ80\build\arch\cpm22-b.zip`, individual build scripts | ROM/IMG/COM artefacts under `src\vm\Lynxz80\build` |
| `build_biosrom.ps1` | Builds the main BIOS ROM. It assembles `biosrom.asm` and `cpm22bios_runtime.asm`, then overlays the runtime BIOS window into the ROM image. | `build\bios\biosrom.asm`, `build\bios\cpm22bios_runtime.asm`, `asw.exe`, `p2bin.exe` | `IPL.ROM` |
| `build_subcpu_rom.ps1` | Builds the sub-CPU ROM. | `build\subcpu\subcpurom.asm`, `asw.exe`, `p2bin.exe` | `SUBCPU.ROM` |
| `build_diag_roms.ps1` | Builds diagnostic ROMs for the main and sub CPUs. With `-Install`, it also copies them to the normal ROM names. | `build\diag\diag_main.asm`, `build\diag\diag_subcpu.asm`, `asw.exe`, `p2bin.exe` | `DIAGMAIN.ROM`, `DIAGSUB.ROM`, optionally `IPL.ROM`, `SUBCPU.ROM` |
| `build_cpm22_disk.ps1` | Builds the CP/M 2.2 system disk image. It extracts the CP/M source archive when needed, invokes `correct_nmemonic.ps1` for `CPM22.Z80`, extracts the standard command archive, combines the prepared CP/M source with the LynxZ80 runtime BIOS, and patches the BIOS jump table. | `tool\lynxZ80\build\arch\cpm2-asm.zip`, `tool\lynxZ80\build\arch\cpm22-b.zip`, `src\vm\Lynxz80\build\bios\cpm22bios_runtime.asm`, `asw.exe`, `p2bin.exe` | `CPM22_SYSTEM.IMG`, prepared `src\vm\Lynxz80\build\cpm22disk\CPM22_z80.ASM`, extracted `tool\lynxZ80\build\cpm22-b` |
| `build_cpm_utils.ps1` | Converts local CP/M utilities to COM files, then imports them and any repo-local standard commands into `CPM22_SYSTEM.IMG`. | `src\vm\Lynxz80\build\cpmutils\*.ASM`, standard COM files from `tool\lynxZ80\build\cpm22-b`, `diskeditor.ps1` | Updated `CPM22_SYSTEM.IMG`, `src\vm\Lynxz80\build\cpmutils\*.COM` |
| `build_gvram_test_disk.ps1` | Builds the GVRAM test COM file, copies the CP/M system disk, and creates a bootable test disk image. | `build\gvramtest\GVRAMTST.ASM`, `README.TXT`, `CPM22_SYSTEM.IMG`, `diskeditor.ps1` | `GVRAM_TEST_BOOT.IMG`, `build\gvramtest\GVRAMTST.COM` |
| `build_fontrom.ps1` | Generates the LynxZ80 `FONT.ROM` from a TrueType font. Font size, X/Y offsets, threshold, and per-bank output can be configured. | `build\font\KH-Dot-Dougenzaka-16.ttf` or a font supplied with `-FontPath` | `build\font\FONT.ROM`, optionally per-bank files |

## Helper Tools

| File | Purpose | Main operations |
|---|---|---|
| `diskeditor.ps1` | Edits files inside a CP/M disk image. It provides `Help`, `Info`, `List`, `Import`, `Export`, and `Delete`. | Uses `-Image` to select the disk image, then imports, exports, lists, or deletes CP/M files. |
| `ROMCPY.ps1` | Copies generated ROMs into the Visual C++ runtime output directories. With `-diag`, it installs diagnostic ROMs into the Debug output. | Copies `IPL.ROM`, `SUBCPU.ROM`, `DIAGMAIN.ROM`, and `DIAGSUB.ROM` |
| `correct_nmemonic.ps1` | Converts Intel 8080-style `M` register notation in `CPM22.Z80` into Z80-style `(HL)`, then renames the result to `CPM22_z80.ASM`. | Backs up the original file and rewrites mnemonic notation |
| `PowerDiff.ps1` | PowerShell diff/patch utility. It supports file or folder comparison, recursive comparison, patch creation, and patch application. | Options include `-Recurse`, `-Content`, `-Hash`, `-PatchPath`, `-ApplyPatch`, and `-TargetPath` |

## Typical Build Order

For a normal build, `buildall.ps1` invokes the individual scripts in this order.

1. `build_biosrom.ps1`
2. `build_subcpu_rom.ps1`
3. `ROMCPY.ps1`
4. `build_cpm22_disk.ps1`
5. `build_cpm_utils.ps1`

Run `build_diag_roms.ps1`, `build_gvram_test_disk.ps1`, `build_fontrom.ps1`, or `correct_nmemonic.ps1` separately when those outputs are required.

## Notes

- `asw.exe` and `p2bin.exe` are required by the Z80-related build scripts.
- `build_fontrom.ps1` requires `KH-Dot-Dougenzaka-16.ttf` separately to generate `FONT.ROM`. This repository does not redistribute the font file or generated font ROM data. Obtain the font from [KH Dot Font Series](http://jikasei.me/font/kh-dotfont/) or [KH Dot Font - Font Meme](https://fontmeme.com/fonts/kh-dot-font/), then place it in `tool\lynxZ80\build\font` or pass it with `-FontPath`.
- `KH-Dot-Dougenzaka-16.ttf` is licensed separately under the SIL Open Font License 1.1. Generated font ROM data derived from that font should be treated under the same licence when redistributed.
- Place `cpm2-asm.zip` and `cpm22-b.zip` in `tool\lynxZ80\build\arch`. `build_cpm22_disk.ps1` extracts them when needed.
- If `cpm2-asm.zip` contains `CPM22.Z80`, `build_cpm22_disk.ps1` calls `correct_nmemonic.ps1` to create `CPM22_z80.ASM`.
- Standard CP/M commands are extracted to `tool\lynxZ80\build\cpm22-b`. `build_cpm_utils.ps1` imports them when that folder exists.
- `diskeditor.ps1` has no default image. If `-Image` is omitted, it displays help.
