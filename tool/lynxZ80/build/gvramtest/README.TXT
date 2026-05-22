LYNX-Z80 GVRAM TEST BOOT DISK

This disk is bootable CP/M 2.2 and contains GVRAMTST.COM.

Run:
  GVRAMTST

GVRAMTST sends a Graphic uPD7220 command stream through MINSUB. It does not
touch the Graphic GDC ports directly from CP/M; SUBCPU.ROM receives proxy
commands and performs the actual GGDC writes.

The test initializes the Graphic GDC, fills visible GVRAM with RGB plane
patterns, then sends VECTW/VECTE arc commands as a drawing-path check.

Generic Graphic uPD7220 proxy:
  ESC G C xx  -> write command byte xx to the Graphic 7220 command port
  ESC G P xx  -> write parameter byte xx to the Graphic 7220 parameter port

xx is two ASCII hex digits, so every byte value from 00H to FFH can be sent.
The MAIN/SUB hardware path does not provide a general byte-wide return channel,
so this proxy covers write-side 7220 command streams.
