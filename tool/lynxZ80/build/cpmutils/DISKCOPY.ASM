; Lynx-Z80 CP/M 2.2 DISKCOPY.COM
; Multi-drive disk copy using Z80 DMA and MB8877A FDC.
; Optimized for Z80 (MacroAssembler AS)

        CPU     Z80

BDOS    EQU     0005H
CONOUT  EQU     0002H
PRINT   EQU     0009H
RDCON   EQU     0001H
WBOOT   EQU     0000H

DMA_P   EQU     028H
FDCSTS  EQU     02CH
FDCCMD  EQU     02CH
FDCTRK  EQU     02DH
FDCSEC  EQU     02EH
FDCDAT  EQU     02FH
PIOBD   EQU     031H
PIOAC   EQU     032H
PIOBC   EQU     033H

FIRSTTRK EQU    0
LASTTRK  EQU    76
LASTSEC  EQU    26
MAXDRV   EQU    4
BUFFER   EQU    08000H

        ORG     0100H

START:
        LD      SP, 08000H      ; Set stack below buffer
        LD      DE, MSG_HELLO
        LD      C, PRINT
        CALL    BDOS
        CALL    ASK_DRIVES
        JR      NZ, EXIT
        LD      DE, MSG_START
        LD      C, PRINT
        CALL    BDOS
        CALL    GETYES
        JR      NZ, EXIT

        CALL    HW_INIT
        XOR     A
        LD      (TRACK), A

TRACK_LOOP:
        CALL    SELECT_SRC
        CALL    READ_TRACK
        OR      A
        JR      NZ, RERR

        CALL    SELECT_DST
        CALL    WRITE_TRACK
        OR      A
        JR      NZ, WERR

        LD      E, '.'
        LD      C, CONOUT
        CALL    BDOS

        LD      A, (TRACK)
        INC     A
        LD      (TRACK), A
        CP      LASTTRK+1
        JR      NZ, TRACK_LOOP

        LD      DE, MSG_DONE
        LD      C, PRINT
        CALL    BDOS
        JP      WBOOT

RERR:
        LD      DE, MSG_RERR
        JR      ERR_EXIT
WERR:
        LD      DE, MSG_WERR
ERR_EXIT:
        LD      C, PRINT
        CALL    BDOS
EXIT:
        JP      WBOOT

GETYES:
        LD      C, RDCON
        CALL    BDOS
        AND     05FH
        CP      'Y'
        RET

HW_INIT:
        LD      A, 00FH
        OUT     (PIOAC), A
        OUT     (PIOBC), A
        CALL    SELECT_SRC
        RET

SELECT_SRC:
        LD      A, (SRC_DRIVE)
        JR      SEL_COMM
SELECT_DST:
        LD      A, (DST_DRIVE)
SEL_COMM:
        OR      008H
        OUT     (PIOBD), A
        RET

ASK_DRIVES:
        LD      DE, MSG_SRC
        LD      C, PRINT
        CALL    BDOS
        CALL    READ_DRIVE
        CP      0FFH
        JR      Z, ASK_BAD
        LD      (SRC_DRIVE), A

        LD      DE, MSG_DST
        LD      C, PRINT
        CALL    BDOS
        CALL    READ_DRIVE
        CP      0FFH
        JR      Z, ASK_BAD
        LD      (DST_DRIVE), A

        LD      B, A
        LD      A, (SRC_DRIVE)
        CP      B
        JR      Z, ASK_SAME
        XOR     A
        RET

ASK_BAD:
        LD      DE, MSG_BAD
        JR      ASK_FAIL
ASK_SAME:
        LD      DE, MSG_SAME
ASK_FAIL:
        LD      C, PRINT
        CALL    BDOS
        OR      1
        RET

READ_DRIVE:
        LD      C, RDCON
        CALL    BDOS
        AND     05FH
        CP      'A'
        JR      C, DRIVE_BAD
        CP      'A'+MAXDRV
        JR      NC, DRIVE_BAD
        SUB     'A'
        RET
DRIVE_BAD:
        LD      A, 0FFH
        RET

READ_TRACK:
        CALL    SEEK_TRACK
        RET     NZ
        LD      HL, BUFFER
        LD      B, LASTSEC
        LD      A, 1
        LD      (SECTOR), A
READ_T1:
        PUSH    BC
        CALL    READ_SECTOR_DMA
        POP     BC
        RET     NZ
        LD      DE, 128
        ADD     HL, DE
        LD      A, (SECTOR)
        INC     A
        LD      (SECTOR), A
        DJNZ    READ_T1
        XOR     A
        RET

WRITE_TRACK:
        CALL    SEEK_TRACK
        RET     NZ
        LD      HL, BUFFER
        LD      B, LASTSEC
        LD      A, 1
        LD      (SECTOR), A
WRITE_T1:
        PUSH    BC
        CALL    WRITE_SECTOR_DMA
        POP     BC
        RET     NZ
        LD      DE, 128
        ADD     HL, DE
        LD      A, (SECTOR)
        INC     A
        LD      (SECTOR), A
        DJNZ    WRITE_T1
        XOR     A
        RET

SEEK_TRACK:
        LD      A, (TRACK)
        OR      A
        JR      NZ, SEEK_TO_N
        LD      A, 008H
        OUT     (FDCCMD), A
        JP      WAIT_FDC
SEEK_TO_N:
        OUT     (FDCTRK), A
        OUT     (FDCDAT), A
        LD      A, 018H
        OUT     (FDCCMD), A
        JP      WAIT_FDC

READ_SECTOR_DMA:
        LD      A, (TRACK)
        OUT     (FDCTRK), A
        LD      A, (SECTOR)
        OUT     (FDCSEC), A
        CALL    DMA_READ_SETUP
        LD      A, 088H
        OUT     (FDCCMD), A
        JP      WAIT_FDC

WRITE_SECTOR_DMA:
        LD      A, (TRACK)
        OUT     (FDCTRK), A
        LD      A, (SECTOR)
        OUT     (FDCSEC), A
        CALL    DMA_WRITE_SETUP
        LD      A, 0A8H
        OUT     (FDCCMD), A
        JP      WAIT_FDC

DMA_READ_SETUP:
        LD      A, 0C3H
        OUT     (DMA_P), A
        LD      A, 079H
        OUT     (DMA_P), A
        LD      A, L
        OUT     (DMA_P), A
        LD      A, H
        OUT     (DMA_P), A
        LD      A, 07FH
        OUT     (DMA_P), A
        LD      A, 000H
        OUT     (DMA_P), A
        LD      A, 014H
        OUT     (DMA_P), A
        LD      A, 028H
        OUT     (DMA_P), A
        LD      A, 0C5H
        OUT     (DMA_P), A
        LD      A, 02FH
        OUT     (DMA_P), A
        LD      A, 08AH
        OUT     (DMA_P), A
        LD      A, 0CFH
        OUT     (DMA_P), A
        LD      A, 087H
        OUT     (DMA_P), A
        RET

DMA_WRITE_SETUP:
        LD      A, 0C3H
        OUT     (DMA_P), A
        LD      A, 079H
        OUT     (DMA_P), A
        LD      A, L
        OUT     (DMA_P), A
        LD      A, H
        OUT     (DMA_P), A
        LD      A, 07FH
        OUT     (DMA_P), A
        LD      A, 000H
        OUT     (DMA_P), A
        LD      A, 014H
        OUT     (DMA_P), A
        LD      A, 028H
        OUT     (DMA_P), A
        LD      A, 0C5H
        OUT     (DMA_P), A
        LD      A, 02FH
        OUT     (DMA_P), A
        LD      A, 08AH
        OUT     (DMA_P), A
        LD      A, 0CFH
        OUT     (DMA_P), A
        LD      A, 005H
        OUT     (DMA_P), A
        LD      A, 0CFH
        OUT     (DMA_P), A
        LD      A, 087H
        OUT     (DMA_P), A
        RET

WAIT_FDC:
        LD      DE, 0FFFFH
WAIT1:
        IN      A, (FDCSTS)
        CP      0FFH
        JR      Z, WAIT_FAIL
        LD      B, A
        AND     001H
        JR      Z, WAIT_DONE
        DEC     DE
        LD      A, D
        OR      E
        JR      NZ, WAIT1
WAIT_FAIL:
        LD      A, 1
        RET

WAIT_DONE:
        LD      A, B
        AND     098H
        RET     NZ
        XOR     A
        RET

MSG_HELLO:
        DB      CR, LF, 'DISKCOPY using Z80 DMA.', CR, LF
        DB      'Supported drives: A: B: C: D:', CR, LF, '$'
MSG_SRC:  DB      'Source drive? $'
MSG_DST:  DB      CR, LF, 'Target drive? $'
MSG_START:
        DB      CR, LF, 'Insert disks. Copy 77 tracks. Start (Y/N)? $'
MSG_BAD:  DB      CR, LF, 'Bad drive. Use A-D.', CR, LF, '$'
MSG_SAME: DB      CR, LF, 'Source and target must be different.', CR, LF, '$'
MSG_DONE: DB      CR, LF, 'Disk copy complete.', CR, LF, '$'
MSG_RERR: DB      CR, LF, 'Read error - aborted.', CR, LF, '$'
MSG_WERR: DB      CR, LF, 'Write error - aborted.', CR, LF, '$'

CR      EQU     0DH
LF      EQU     0AH

SRC_DRIVE: DB      0
DST_DRIVE: DB      1
TRACK:     DB      0
SECTOR:    DB      1
