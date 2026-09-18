# eLynxZ80 — konstruaj postuloj

Ĉi tiu dosiero estas mallongigita Esperanto-resumo. Por la plena aktuala priskribo vidu [Requirements_JP.md](Requirements_JP.md) aŭ [Requirements_EN_US.md](Requirements_EN_US.md).

## Emulilo

La projekto `vc++2017/lynxz80.vcxproj` uzas:

- Visual Studio 2019 / Build Tools 2019
- Platform Toolset `v141`
- Windows SDK `10.0.18362.0`
- `winmm.lib`
- `imm32.lib`

La kompleta CSCP-fontarbo estas bezonata; ĝi ne estas inkluzivita en ĉi tiu deponejo.

## ROM kaj CP/M

La helpaj skriptoj uzas PowerShell, Macro Assembler AS (`asw.exe`), `p2bin.exe`, kaj por la CP/M-prepara paŝo Git.

Eksteraj CP/M-arkivoj:

```text
tool/lynxZ80/build/arch/cpm2-asm.zip
tool/lynxZ80/build/arch/cpm22-b.zip
```

Ĉefaj nunaj eligoj:

```text
tool/lynxZ80/bin/IPL.ROM
tool/lynxZ80/bin/SUBCPU.ROM
src/vm/Lynxz80/build/IPL.ROM
src/vm/Lynxz80/build/SUBCPU.ROM
tool/lynxZ80/build/font/FONT.ROM
tool/lynxZ80/bin/CPM22_RUNTIME.BIN
tool/lynxZ80/bin/CPM22_SYSTEM.2d
```

## Kongrueco

La helpaj skriptoj nun uzas la aktualan dosierujan aranĝon. `diskeditor.ps1` defaŭlte traktas la nunan `CPM22_SYSTEM.2d`-formaton; la malnova 77-traka formato restas disponebla per `-Format Legacy`. AS, p2bin kaj Git estas serĉataj per PATH, kun eblo eksplicite indiki iliajn vojojn en la koncernaj skriptoj.

Vidu [tool/lynxZ80/README.md](tool/lynxZ80/README.md) por detaloj.
