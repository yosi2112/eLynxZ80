# Lynx Emulator 'eLynxZ80' on Common Source Code Project

Kodita de Yosi per OpenAI Codex  
Versio 1.0 Beta 1(260521)

## 1. Kio estas tio?

'eLynxZ80' estas emulila realigo por "Lynx", la duobla Z80 CP/M-maŝino kreita de Chiaki Nakajima, konstruita sur la "Common Source Code Project" de Takeda Toshiya.

Tiu pakaĵo enhavas la virtual-maŝinan realigon por Lynx, projekton por Visual Studio, kaj helpilojn por generi BIOS/sub-CPU-ROMojn, tiparan ROMon, kaj CP/M 2.2-diskan bildon.

Plejparto de la kodo estis kreita kunlabore kun Codex (AI). La sola materialo ricevita de la Lynx-aŭtoro estis la cirkvitdiagramo; la ROM-fontkodo, krom FONT.ROM, ankaŭ estis kreita kunlabore kun AI.

Pri la "Common Source Code Project", vidu [Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html).

## 2. Kial ĝi havas alian nomon?

La originala maŝino emulata ĉi tie estas "Lynx", la duobla Z80 CP/M-maŝino kreita de Chiaki Nakajima. Tamen, nur la nomo "Lynx" facile povas esti konfuzata kun ATARI LYNX kaj kun aliaj komputiloj aŭ emuliloj uzantaj la saman nomon.

Pro tio ĉi tiu emulilo uzas la distribuan nomon 'eLynxZ80', kombinante "e" por emulilo kun Z80, la centra CPU-familio de la cela maŝino. Pro historiaj projektaj nomoj, la fontarbo kaj projektdosieroj povas ankoraŭ enhavi formojn kiel "LynxZ80" kaj "lynxz80"; ĉiuj indikas la saman emulilon.

Pri la originala Lynx, vidu la aŭtoran paĝon "[Dual Z80 CP/M system [Lynx]](https://www.chiaki.cc/Lynx/index_en.htm)".

## 3. Kio necesas?

'eLynxZ80' bezonas la jenajn erojn.

### 3.1 Aparataro

Funkciado estas celita por Windows 10 aŭ pli nova, 32/64-bitaj eldonoj.

### 3.2 Plenumebla dosiero kaj ROM-bildaj dosieroj

Por lanĉi la emulilon, metu la jenajn dosierojn en la saman dosierujon kiel la plenumebla dosiero `lynxz80.exe`.

- `IPL.ROM`  
  IPL/BIOS-ROM por la ĉefa CPU.
- `SUBCPU.ROM`  
  ROM por la sub-CPU.
- `FONT.ROM`  
  Tipara ROM por ekrana eligo. Se tiu dosiero ne ekzistas, la emulilo uzas siajn enkonstruitajn komencajn valorojn, sed generita dosiero estas rekomendata por ĝusta montrado.

### 3.3 Diska bilddosiero

Por lanĉi CP/M 2.2, enmetu la generitan diskan bildon `CPM22_SYSTEM.IMG` kiel disketon.

La maŝino supozas du-diskan agordon.

## 4. Kiujn klavojn premi?

'eLynxZ80' traktas PC-klavaran enigon kiel serian enigon.

| Klavo | Enigo |
| - | - |
| `A-Z` | Literaj klavoj |
| `0-9` | Ciferaj klavoj |
| `Enter` | CR |
| `BackSpace` | BS |
| `Tab` | HT |
| `Esc` | ESC |
| `Space` | Spaco |
| `Delete` | DEL |
| `Ctrl+A` - `Ctrl+Z` | Stirkodoj |

Simbolaj klavoj estas tradukataj al ASCII-signoj ekvivalentaj al usona klavara aranĝo. La statoj de Caps Lock kaj Kana Lock ankaŭ estas tenataj en la emulilo.

## 5. Kiel konstrui?

La fontdosieroj inkluditaj en tiu pakaĵo povas esti konstruitaj per surmeto al la fontarbo de la "Common Source Code Project". Malfermu `vc++2017/lynxz80.vcxproj` per Visual Studio.

La distribuitaj projektaj agordoj supozas la jenan medion.

- Visual Studio 2019 / Build Tools 2019
- Platform Toolset `v141`
- Windows 10 SDK `10.0.18362.0`
- `winmm.lib` / `imm32.lib`

La jenaj iloj necesas por generi ROMojn kaj CP/M-diskajn bildojn.

- Windows PowerShell
- Macro Assembler AS (`asw.exe`)
- `p2bin.exe`

AS estas akirebla de la jenaj paĝoj.

- [The Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/)

Helpaj skriptoj troviĝas sub `tool/lynxZ80`.

| Skripto | Priskribo |
| - | - |
| `buildall.ps1` | Generas la BIOS-ROMon, sub-CPU-ROMon, CP/M 2.2-diskon, kaj CP/M-utilaĵojn sinsekve. |
| `build_biosrom.ps1` | Generas `src/vm/Lynxz80/build/IPL.ROM`. |
| `build_subcpu_rom.ps1` | Generas `src/vm/Lynxz80/build/SUBCPU.ROM`. |
| `build_fontrom.ps1` | Generas `src/vm/Lynxz80/build/font/FONT.ROM`. |
| `ROMCPY.ps1` | Kopias generitajn ROMojn al `vc++2017/bin/x86/Debug` aŭ `vc++2017/bin/x86/Release`. |

Por generi la CP/M 2.2-diskon, ankaŭ necesas `cpm2-asm.zip` kaj `cpm22-b.zip`. Metu tiujn dosierojn en `tool/lynxZ80/build/arch`.

CP/M-rilataj dosieroj estas akireblaj de la jenaj paĝoj.

- [The Unofficial CP/M Web Site](http://www.cpm.z80.de/)

Pri la Lynx-maŝino mem, vidu ankaŭ la jenajn paĝojn.

- [放課後の電子工作　～　会社でハンダ付け、自宅でもハンダ付け　～](https://www.chiaki.cc/)
- [Dual Z80 CP/M system [Lynx]](https://www.chiaki.cc/Lynx/index_en.htm)

## 6. Kopirajta noto

Tiu pakaĵo enhavas fontdosierojn bazitajn sur la "Common Source Code Project" kaj fontdosierojn aldonitajn por Lynx Z80.

Uzo kaj redistribuo estas regataj de la kopirajtaj notoj en ĉiu fontdosiero kaj de la metodoj kaj kondiĉoj difinitaj de la prizorganto de la "Common Source Code Project".

Eksteraj arkivoj kaj normaj komandosieroj rilataj al CP/M 2.2 estas kovritaj de apartaj rajtoj kaj kondiĉoj. Uzantoj mem devas kontroli la laŭleĝan fonton kaj uzkondiĉojn por tiuj materialoj.

## 7. Kontakto

X (antaŭe Twitter): <https://x.com/yosi2112>

Pri la "Common Source Code Project", vidu [Common Source Code Project](http://takeda-toshiya.my.coocan.jp/common/index.html).
