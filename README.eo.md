# eLynxZ80

eLynxZ80 estas emulilo de la du-Z80 CP/M-komputilo “Lynx”, konstruita sur la Common Source Code Project (CSCP).

Ĉi tiu Esperanto-dosiero estas mallongigita traduko. Por la plena kaj plej aktuala manlibro vidu [README.md](README.md) aŭ [README.en-US.md](README.en-US.md).

## Nuna aranĝo

- Ĉefa CPU kaj sub-CPU: Z80
- Ĉefa memoro: 64 KB
- `IPL.ROM`: 8 KB
- `SUBCPU.ROM`: 8 KB
- `FONT.ROM`: 8 KB
- Ekrano: 640 × 400
- Du uPD7220-kongruaj GDC-oj
- Du 2D disketiloj
- CP/M 2.2

Por normala funkciado metu `IPL.ROM`, `SUBCPU.ROM` kaj `FONT.ROM` apud `lynxz80.exe`.

La nuna CP/M-disk-konstruilo kreas:

```text
tool/lynxZ80/bin/CPM22_SYSTEM.2d
```

La malnova nomo `CPM22_SYSTEM.IMG` ne estas la nuna eligo.

## Konstruado

La deponejo ne enhavas la tutan komunan fontaron de CSCP. La projekto `vc++2017/lynxz80.vcxproj` devas esti uzata kun kongrua CSCP-fontarbo.

Aktualaj helpaj skriptoj troviĝas en `tool/lynxZ80/`.

- `build_ipl_rom.ps1`
- `build_subcpu_rom.ps1`
- `build_fontrom.ps1`
- `build_cpm22_env.ps1`
- `build_cpm22_runtime.ps1`
- `build_cpm22_system_disk.ps1`
- `ROMCPY.ps1`
- `diskeditor.ps1`

Kelkaj skriptoj ankoraŭ enhavas lokajn aŭ malnovajn dosierujojn. Legu [tool/lynxZ80/README.md](tool/lynxZ80/README.md) antaŭ uzo.

## Dokumentaro

- [Programming Manual](src/vm/Lynxz80/docs/Programing%20Manual/README.md)
- [Build requirements](Requirements_EO.md)

## Permesilo

La radika [LICENSE](LICENSE) enhavas GNU General Public License Version 3. Triaj fontoj kaj datumoj povas havi apartajn kondiĉojn.
