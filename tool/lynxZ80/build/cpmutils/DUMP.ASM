; Small CP/M 2.2 DUMP.COM compatible utility.
; Usage: DUMP filename
; Optimized for Z80 (MacroAssembler AS)

        CPU     Z80

BDOS    EQU     0005H
WBOOT   EQU     0000H
PRINT   EQU     0009H
OPENF   EQU     000FH
READF   EQU     0014H
SETDMAF EQU     001AH
CONOUT  EQU     0002H

FCB     EQU     005CH
DMA_B   EQU     0080H
CR      EQU     0DH
LF      EQU     0AH

        ORG     0100H

START:
        LD      DE, FCB
        LD      C, OPENF
        CALL    BDOS
        INC     A
        JR      Z, NOFILE

        LD      DE, DMA_B
        LD      C, SETDMAF
        CALL    BDOS
        LD      HL, 0
        LD      (ADDR), HL

READLP:
        LD      DE, FCB
        LD      C, READF
        CALL    BDOS
        OR      A
        JR      NZ, DONE

        LD      HL, DMA_B
        LD      B, 8            ; 8 lines of 16 bytes per 128-byte record
LINELP:
        PUSH    BC
        PUSH    HL
        CALL    PRINTADDR
        POP     HL
        LD      B, 16
BYTELP:
        LD      A, (HL)
        PUSH    BC
        PUSH    HL
        CALL    HEXA
        LD      E, ' '
        LD      C, CONOUT
        CALL    BDOS
        LD      HL, (ADDR)
        INC     HL
        LD      (ADDR), HL
        POP     HL
        POP     BC
        INC     HL
        DJNZ    BYTELP
        CALL    CRLF
        POP     BC
        DJNZ    LINELP
        JR      READLP

NOFILE:
        LD      DE, MSG_NOFILE
        LD      C, PRINT
        CALL    BDOS
DONE:
        JP      WBOOT

PRINTADDR:
        LD      HL, (ADDR)
        LD      A, H
        CALL    HEXA
        LD      A, L
        CALL    HEXA
        LD      E, ':'
        LD      C, CONOUT
        CALL    BDOS
        LD      E, ' '
        LD      C, CONOUT
        JP      BDOS

HEXA:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    HEXN
        POP     AF
HEXN:
        AND     00FH
        CP      10
        JR      C, HEX_DIG
        ADD     A, 7
HEX_DIG:
        ADD     A, '0'
        LD      E, A
        LD      C, CONOUT
        JP      BDOS

CRLF:
        LD      E, 0DH
        LD      C, CONOUT
        CALL    BDOS
        LD      E, 0AH
        LD      C, CONOUT
        JP      BDOS

MSG_NOFILE: DB      'No file', CR, LF, '$'
ADDR:       DW      0
