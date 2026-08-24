; Lynx-Z80 CP/M 2.2 CLS.COM
; Clears the ANSI-capable console and homes the cursor.

        CPU     Z80

BDOS    EQU     0005H
PRINT   EQU     0009H

        ORG     0100H

START:
        LD      DE,CLEAR_SEQUENCE
        LD      C,PRINT
        CALL    BDOS
        RET

CLEAR_SEQUENCE:
        DB      1BH, '[2J', 1BH, '[H', '$'
