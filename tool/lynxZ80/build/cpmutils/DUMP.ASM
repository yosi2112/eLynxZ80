; FILE DUMP PROGRAM, READS AN INPUT FILE AND PRINTS IN HEX.
; Behaviour follows the Digital Research CP/M 2.2 DUMP utility.
;
; The CCP-provided FCB is copied out of page zero and all subsequent file I/O
; uses program-local FCB/DMA storage.

        CPU     Z80

        ORG     0100H

BDOS        EQU     0005H          ; DOS entry point
TYPEF       EQU     2              ; console output function
PRINTF      EQU     9              ; buffer print function
BRKF        EQU     11             ; break-key status function
OPENF       EQU     15             ; file open function
READF       EQU     20             ; sequential read function
SETDMAF     EQU     26             ; set DMA address function

SYSTEM_FCB  EQU     005CH          ; CCP-supplied first FCB

CR          EQU     0DH
LF          EQU     0AH
FCBCR       EQU     FCB+32         ; current (next) record number

START:
        ; Preserve the argument FCB before any BDOS call, then avoid page zero.
        LD      HL,SYSTEM_FCB
        LD      DE,FCB
        LD      BC,36
        LDIR

        ; Save the CCP stack and use a private stack while DUMP runs.
        LD      HL,0
        ADD     HL,SP
        LD      (OLDSP),HL
        LD      SP,STKTOP

        CALL    SETUP
        CP      0FFH
        JR      NZ,OPENOK

        LD      DE,OPNMSG
        CALL    ERR
        JR      FINIS

OPENOK:
        LD      A,80H
        LD      (IBP),A            ; force an initial record read
        LD      HL,0               ; first displayed file offset

GLOOP:
        PUSH    HL
        CALL    GNB
        POP     HL
        JR      C,FINIS
        LD      B,A

        LD      A,L
        AND     0FH
        JR      NZ,NONUM

        CALL    CRLF
        CALL    BREAK
        RRCA
        JR      C,FINIS

        LD      A,H
        CALL    PHEX
        LD      A,L
        CALL    PHEX
NONUM:
        INC     HL
        LD      A,' '
        CALL    PCHAR
        LD      A,B
        CALL    PHEX
        JR      GLOOP

FINIS:
        CALL    CRLF
        LD      HL,(OLDSP)
        LD      SP,HL
        RET

BREAK:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        LD      C,BRKF
        CALL    BDOS
        POP     BC
        POP     DE
        POP     HL
        RET

PCHAR:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        LD      C,TYPEF
        LD      E,A
        CALL    BDOS
        POP     BC
        POP     DE
        POP     HL
        RET

CRLF:
        LD      A,CR
        CALL    PCHAR
        LD      A,LF
        CALL    PCHAR
        RET

PNIB:
        AND     0FH
        CP      10
        JR      NC,P10
        ADD     A,'0'
        JR      PRN
P10:
        ADD     A,'A'-10
PRN:
        CALL    PCHAR
        RET

PHEX:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    PNIB
        POP     AF
        CALL    PNIB
        RET

ERR:
        LD      C,PRINTF
        CALL    BDOS
        RET

GNB:
        LD      A,(IBP)
        CP      80H
        JR      NZ,G0
        CALL    DISKR
        OR      A
        JR      Z,G0
        SCF
        RET

G0:
        LD      E,A
        LD      D,0
        INC     A
        LD      (IBP),A
        LD      HL,DMA_B
        ADD     HL,DE
        LD      A,(HL)
        OR      A                  ; clear carry
        RET

SETUP:
        XOR     A
        LD      (FCBCR),A
        LD      DE,DMA_B
        LD      C,SETDMAF
        CALL    BDOS
        LD      DE,FCB
        LD      C,OPENF
        CALL    BDOS
        RET

DISKR:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        LD      DE,FCB
        LD      C,READF
        CALL    BDOS
        POP     BC
        POP     DE
        POP     HL
        RET

SIGNON: DB      'FILE DUMP VERSION 1.4$'
OPNMSG: DB      CR,LF,'NO INPUT FILE PRESENT ON DISK$'

IBP:    DB      0,0
OLDSP:  DW      0

        DS      64                 ; reserve a 32-level private stack
STKTOP:
FCB:    DS      36
DMA_B:  DS      128

        END
