# eLynxZ80 GVRAM Test

This directory contains the CP/M 2.2 graphics-GDC test program `GVRAMTST.COM`.

## Purpose

`GVRAMTST` sends a Graphics uPD7220 command stream from the main CPU through the MINSUB bridge. CP/M does not access the Graphics GDC ports directly. `SUBCPU.ROM` receives the proxy commands and performs the actual GDC writes.

The test:

1. initialises the Graphics GDC;
2. fills the visible GVRAM with RGB-plane patterns; and
3. sends `VECTW` / `VECTE` arc commands to check the drawing path.

## Running the Test

Boot CP/M 2.2 with a disk containing `GVRAMTST.COM`, then run:

```text
GVRAMTST
```

## Graphics GDC Proxy

The current write-side proxy accepts the following command forms:

```text
ESC G C xx
ESC G P xx
```

| Command | Action |
| --- | --- |
| `ESC G C xx` | Write byte `xx` to the Graphics GDC command port |
| `ESC G P xx` | Write byte `xx` to the Graphics GDC parameter port |

`xx` is a two-digit ASCII hexadecimal value from `00` through `FF`.

The current MAIN/SUB communication path does not provide a general byte-wide return channel, so this proxy covers write-side GDC command streams only.

## Related Documentation

See:

```text
src/vm/Lynxz80/docs/Programing Manual/GDC4Dummies/README.md
src/vm/Lynxz80/docs/Programing Manual/SYSinfo/README.md
```
