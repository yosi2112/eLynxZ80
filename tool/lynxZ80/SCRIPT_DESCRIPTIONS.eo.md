# Priskriboj de la iloskriptoj de lynxZ80

Amplekso: `<repo>\tool\lynxZ80\*.ps1` kaj `<repo>\tool\lynxZ80\*.c`

Dum la kontrolo, la cela dosierujo enhavis dek du `.ps1`-dosierojn. Neniuj `.c`-dosieroj estis trovitaj.

## Konstruaj skriptoj

| Dosiero | Celo | Ĉefaj enigoj | Ĉefaj eligoj |
|---|---|---|---|
| `buildall.ps1` | Supra konstrua enirpunkto por ROM-oj, la CP/M-disko kaj CP/M-utilaĵoj. Ĝi kontrolas la bezonatajn arkivojn en `tool\lynxZ80\build\arch` kaj certigas, ke `asw.exe` kaj `p2bin.exe` estas disponeblaj en `PATH`. | `tool\lynxZ80\build\arch\cpm2-asm.zip`, `tool\lynxZ80\build\arch\cpm22-b.zip`, unuopaj konstruskriptoj | ROM/IMG/COM-artefaktoj sub `src\vm\Lynxz80\build` |
| `build_biosrom.ps1` | Konstruas la ĉefan BIOS-ROM. Ĝi asemblas `biosrom.asm` kaj `cpm22bios_runtime.asm`, poste surmetas la runtime-BIOS-fenestron en la ROM-bildon. | `build\bios\biosrom.asm`, `build\bios\cpm22bios_runtime.asm`, `asw.exe`, `p2bin.exe` | `IPL.ROM` |
| `build_subcpu_rom.ps1` | Konstruas la ROM-on de la sub-CPU. | `build\subcpu\subcpurom.asm`, `asw.exe`, `p2bin.exe` | `SUBCPU.ROM` |
| `build_diag_roms.ps1` | Konstruas diagnozajn ROM-ojn por la ĉefa kaj suba CPU-oj. Kun `-Install`, ĝi ankaŭ kopias ilin al la normalaj ROM-nomoj. | `build\diag\diag_main.asm`, `build\diag\diag_subcpu.asm`, `asw.exe`, `p2bin.exe` | `DIAGMAIN.ROM`, `DIAGSUB.ROM`, laŭvole `IPL.ROM`, `SUBCPU.ROM` |
| `build_cpm22_disk.ps1` | Konstruas la sisteman diskbildon de CP/M 2.2. Ĝi elpakas la CP/M-fontan arkivon kiam necesas, vokas `correct_nmemonic.ps1` por `CPM22.Z80`, elpakas la normkomandan arkivon, kombinas la preparitan CP/M-fonton kun la LynxZ80 runtime-BIOS, kaj flikas la BIOS-salttabelon. | `tool\lynxZ80\build\arch\cpm2-asm.zip`, `tool\lynxZ80\build\arch\cpm22-b.zip`, `src\vm\Lynxz80\build\bios\cpm22bios_runtime.asm`, `asw.exe`, `p2bin.exe` | `CPM22_SYSTEM.IMG`, preparita `src\vm\Lynxz80\build\cpm22disk\CPM22_z80.ASM`, elpakita `tool\lynxZ80\build\cpm22-b` |
| `build_cpm_utils.ps1` | Konvertas lokajn CP/M-utilaĵojn al COM-dosieroj, poste importas ilin kaj eventualajn lokajn normkomandojn en `CPM22_SYSTEM.IMG`. | `src\vm\Lynxz80\build\cpmutils\*.ASM`, normaj COM-dosieroj el `tool\lynxZ80\build\cpm22-b`, `diskeditor.ps1` | Ĝisdatigita `CPM22_SYSTEM.IMG`, `src\vm\Lynxz80\build\cpmutils\*.COM` |
| `build_gvram_test_disk.ps1` | Konstruas la GVRAM-testan COM-dosieron, kopias la CP/M-sisteman diskon, kaj kreas startigeblan testan diskbildon. | `build\gvramtest\GVRAMTST.ASM`, `README.TXT`, `CPM22_SYSTEM.IMG`, `diskeditor.ps1` | `GVRAM_TEST_BOOT.IMG`, `build\gvramtest\GVRAMTST.COM` |
| `build_fontrom.ps1` | Generas la LynxZ80 `FONT.ROM` el TrueType-tiparo. Tipargrando, X/Y-delokigoj, sojlo kaj apartaj bankaj eligoj povas esti agorditaj. | `build\font\KH-Dot-Dougenzaka-16.ttf` aŭ tiparo donita per `-FontPath` | `build\font\FONT.ROM`, laŭvole apartaj bankaj dosieroj |

## Helpaj iloj

| Dosiero | Celo | Ĉefaj operacioj |
|---|---|---|
| `diskeditor.ps1` | Redaktas dosierojn ene de CP/M-diskbildo. Ĝi provizas `Help`, `Info`, `List`, `Import`, `Export` kaj `Delete`. | Uzas `-Image` por elekti la diskbildon, poste importas, eksportas, listigas aŭ forigas CP/M-dosierojn. |
| `ROMCPY.ps1` | Kopias generitajn ROM-ojn en la rultempajn dosierujojn de Visual C++. Kun `-diag`, ĝi instalas diagnozajn ROM-ojn en la Debug-eligon. | Kopias `IPL.ROM`, `SUBCPU.ROM`, `DIAGMAIN.ROM` kaj `DIAGSUB.ROM` |
| `correct_nmemonic.ps1` | Konvertas Intel 8080-stilan `M`-registran notacion en `CPM22.Z80` al Z80-stila `(HL)`, poste renomas la rezulton al `CPM22_z80.ASM`. | Sekurkopias la originalan dosieron kaj reskribas la mnemonikan notacion |
| `PowerDiff.ps1` | PowerShell-a diff/patch-ilo. Ĝi subtenas dosieran aŭ dosierujan komparon, rekursian komparon, flikgeneradon kaj flikaplikon. | Opcioj inkluzivas `-Recurse`, `-Content`, `-Hash`, `-PatchPath`, `-ApplyPatch` kaj `-TargetPath` |

## Tipa konstrua ordo

Por normala konstruo, `buildall.ps1` vokas la unuopajn skriptojn en ĉi tiu ordo.

1. `build_biosrom.ps1`
2. `build_subcpu_rom.ps1`
3. `ROMCPY.ps1`
4. `build_cpm22_disk.ps1`
5. `build_cpm_utils.ps1`

Rulu `build_diag_roms.ps1`, `build_gvram_test_disk.ps1`, `build_fontrom.ps1` aŭ `correct_nmemonic.ps1` aparte kiam tiuj eligoj estas bezonataj.

## Notoj

- `asw.exe` kaj `p2bin.exe` estas bezonataj de la Z80-rilataj konstruskriptoj.
- `build_fontrom.ps1` bezonas `KH-Dot-Dougenzaka-16.ttf` aparte por generi `FONT.ROM`. Ĉi tiu deponejo ne redistribuas la tipardosieron aŭ generitajn tipar-ROM-datumojn. Akiru la tiparon el [KH Dot Font Series](http://jikasei.me/font/kh-dotfont/) aŭ [KH Dot Font - Font Meme](https://fontmeme.com/fonts/kh-dot-font/), poste metu ĝin en `tool\lynxZ80\build\font` aŭ donu ĝin per `-FontPath`.
- `KH-Dot-Dougenzaka-16.ttf` estas aparte licencita laŭ la SIL Open Font License 1.1. Generitaj tipar-ROM-datumoj derivitaj de tiu tiparo devas esti traktataj laŭ la sama permesilo kiam redistribuitaj.
- Metu `cpm2-asm.zip` kaj `cpm22-b.zip` en `tool\lynxZ80\build\arch`. `build_cpm22_disk.ps1` elpakas ilin kiam necesas.
- Se `cpm2-asm.zip` enhavas `CPM22.Z80`, `build_cpm22_disk.ps1` vokas `correct_nmemonic.ps1` por krei `CPM22_z80.ASM`.
- Normaj CP/M-komandoj estas elpakitaj al `tool\lynxZ80\build\cpm22-b`. `build_cpm_utils.ps1` importas ilin kiam tiu dosierujo ekzistas.
- `diskeditor.ps1` ne havas defaŭltan diskbildon. Se `-Image` estas preterlasita, ĝi montras helpon.
