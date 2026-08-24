; Lynx-Z80 CP/M 2.2 DISKCOPY.COM
; Disk copy through CP/M BIOS calls.
;
; This version deliberately avoids direct FDC, PIO, and DMA port access.
; It copies 40 cylinders x 64 CP/M logical sectors through BIOS
; SELDSK/SETTRK/SETSEC/SETDMA/READ/WRITE.
; The target disk must already be formatted.

        CPU     Z80

BDOS    EQU     0005H
WBOOT   EQU     0000H
CONOUT  EQU     0002H
PRINT   EQU     0009H
RDCON   EQU     0001H

BIOS_WBOOT_VEC EQU 0001H

BIOS_HOME_OFF  EQU 24
BIOS_SELDSK_OFF EQU 27
BIOS_SETTRK_OFF EQU 30
BIOS_SETSEC_OFF EQU 33
BIOS_SETDMA_OFF EQU 36
BIOS_READ_OFF  EQU 39
BIOS_WRITE_OFF EQU 42

FIRSTTRK EQU    0
LASTTRK  EQU    39
LASTSEC  EQU    64
MAXDRV   EQU    2
BUFFER   EQU    08000H
SECSIZE  EQU    128

CR       EQU    0DH
LF       EQU    0AH
ESC      EQU    1BH

        ORG     0100H

START:
        LD      SP, BUFFER
        LD      DE, MSG_HELLO
        CALL    PSTR
        CALL    ASK_DRIVES
        JR      NZ, EXIT
        LD      DE, MSG_START
        CALL    PSTR
        CALL    GETYES
        JR      NZ, EXIT

        XOR     A
        LD      (TRACK), A

TRACK_LOOP:
        CALL    SHOW_TRACK_BEGIN
        CALL    READ_TRACK
        OR      A
        JR      NZ, RERR

        CALL    WRITE_TRACK
        OR      A
        JR      NZ, WERR

        CALL    SHOW_TRACK_DONE

        LD      A, (TRACK)
        INC     A
        LD      (TRACK), A
        CP      LASTTRK+1
        JR      NZ, TRACK_LOOP

        LD      DE, MSG_DONE
        CALL    PSTR
        JP      WBOOT

RERR:
        LD      DE, MSG_RERR
        JR      ERR_EXIT
WERR:
        LD      DE, MSG_WERR
ERR_EXIT:
        CALL    PSTR
        CALL    PRINT_STATUS
EXIT:
        JP      WBOOT

GETYES:
        LD      C, RDCON
        CALL    BDOS
        AND     05FH
        CP      'Y'
        RET

ASK_DRIVES:
        LD      DE, MSG_SRC
        CALL    PSTR
        CALL    READ_DRIVE
        CP      0FFH
        JR      Z, ASK_BAD
        LD      (SRC_DRIVE), A

        LD      DE, MSG_DST
        CALL    PSTR
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
        CALL    PSTR
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
        LD      HL, BUFFER
        LD      (DMA_PTR), HL
        LD      A, 1
        LD      (SECTOR), A
        LD      B, LASTSEC
READ_T1:
        PUSH    BC
        LD      A, (SRC_DRIVE)
        CALL    BIOS_SELDSK
        JR      NZ, READ_FAIL
        CALL    BIOS_SET_POS
        CALL    BIOS_READ
        OR      A
        JR      NZ, READ_FAIL
        CALL    ADVANCE_DMA_SECTOR
        POP     BC
        DJNZ    READ_T1
        XOR     A
        RET
READ_FAIL:
        LD      (ERRSTAT), A
        POP     BC
        OR      1
        RET

WRITE_TRACK:
        LD      HL, BUFFER
        LD      (DMA_PTR), HL
        LD      A, 1
        LD      (SECTOR), A
        LD      B, LASTSEC
WRITE_T1:
        PUSH    BC
        LD      A, (DST_DRIVE)
        CALL    BIOS_SELDSK
        JR      NZ, WRITE_FAIL
        CALL    BIOS_SET_POS
        CALL    BIOS_WRITE
        OR      A
        JR      NZ, WRITE_FAIL
        CALL    ADVANCE_DMA_SECTOR
        POP     BC
        DJNZ    WRITE_T1
        XOR     A
        RET
WRITE_FAIL:
        LD      (ERRSTAT), A
        POP     BC
        OR      1
        RET

BIOS_SET_POS:
        LD      A, (TRACK)
        LD      C, A
        LD      B, 0
        CALL    BIOS_SETTRK
        LD      A, (SECTOR)
        LD      C, A
        LD      B, 0
        CALL    BIOS_SETSEC
        LD      BC, (DMA_PTR)
        JP      BIOS_SETDMA

ADVANCE_DMA_SECTOR:
        LD      HL, (DMA_PTR)
        LD      DE, SECSIZE
        ADD     HL, DE
        LD      (DMA_PTR), HL
        LD      A, (SECTOR)
        INC     A
        LD      (SECTOR), A
        RET

BIOS_SELDSK:
        PUSH    AF
        LD      DE, BIOS_SELDSK_OFF
        CALL    BIOS_VECTOR
        POP     AF
        LD      C, A
        CALL    CALL_BIOS_HL
        LD      A, H
        OR      L
        JR      Z, BIOS_SELDSK_FAIL
        XOR     A
        RET
BIOS_SELDSK_FAIL:
        OR      1
        RET

BIOS_SETTRK:
        PUSH    BC
        LD      DE, BIOS_SETTRK_OFF
        CALL    BIOS_VECTOR
        POP     BC
        JP      CALL_BIOS_HL

BIOS_SETSEC:
        PUSH    BC
        LD      DE, BIOS_SETSEC_OFF
        CALL    BIOS_VECTOR
        POP     BC
        JP      CALL_BIOS_HL

BIOS_SETDMA:
        PUSH    BC
        LD      DE, BIOS_SETDMA_OFF
        CALL    BIOS_VECTOR
        POP     BC
        JP      CALL_BIOS_HL

BIOS_READ:
        LD      DE, BIOS_READ_OFF
        CALL    BIOS_VECTOR
        JP      CALL_BIOS_HL

BIOS_WRITE:
        LD      DE, BIOS_WRITE_OFF
        CALL    BIOS_VECTOR
        LD      C, 0
        JP      CALL_BIOS_HL

BIOS_VECTOR:
        LD      HL, (BIOS_WBOOT_VEC)
        DEC     HL
        DEC     HL
        DEC     HL
        ADD     HL, DE
        RET

CALL_BIOS_HL:
        LD      DE, BIOS_RETURN
        PUSH    DE
        JP      (HL)
BIOS_RETURN:
        RET

PRINT_STATUS:
        LD      DE, MSG_STAT
        CALL    PSTR
        LD      A, (ERRSTAT)
        CALL    PRINT_HEX
        LD      DE, MSG_SECSTAT
        CALL    PSTR
        LD      A, (SECTOR)
        CALL    PRINT_HEX
        JP      CRLF

SHOW_TRACK_BEGIN:
        LD      DE, MSG_TRACK
        CALL    PSTR
        LD      A, (TRACK)
        CALL    PRINT_HEX
        LD      DE, MSG_BUSY
        JP      PSTR

SHOW_TRACK_DONE:
        LD      DE, MSG_OK
        JP      PSTR

PSTR:
        LD      C, PRINT
        JP      BDOS

CRLF:
        LD      E, CR
        LD      C, CONOUT
        CALL    BDOS
        LD      E, LF
        LD      C, CONOUT
        JP      BDOS

PRINT_HEX:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    PRINT_NIB
        POP     AF
PRINT_NIB:
        AND     00FH
        ADD     A, '0'
        CP      '9'+1
        JR      C, PRINT_HEX_OUT
        ADD     A, 7
PRINT_HEX_OUT:
        LD      E, A
        LD      C, CONOUT
        JP      BDOS

MSG_HELLO:
        DB      ESC, '[2J', ESC, '[H'
        DB      'Lynx-Z80 DISKCOPY', CR, LF
        DB      '-----------------', CR, LF
        DB      'Geometry: 40 cyl, 64 CP/M sectors/cyl', CR, LF
        DB      'BIOS sector copy. Target disk must be formatted.', CR, LF
        DB      'Supported drives: A: B:', CR, LF, '$'
MSG_SRC:  DB      'Source drive? $'
MSG_DST:  DB      CR, LF, 'Target drive? $'
MSG_START:
        DB      CR, LF, 'Insert disks. Copy 40 cylinders. Start (Y/N)? $'
MSG_BAD:  DB      CR, LF, 'Bad drive. Use A-B.', CR, LF, '$'
MSG_SAME: DB      CR, LF, 'Source and target must be different.', CR, LF, '$'
MSG_DONE: DB      CR, LF, 'Disk copy complete.', CR, LF, '$'
MSG_RERR: DB      CR, LF, 'Read error - aborted.', CR, LF, '$'
MSG_WERR: DB      CR, LF, 'Write error - aborted.', CR, LF, '$'
MSG_STAT: DB      'BIOS status: $'
MSG_SECSTAT: DB   ' Sector: $'
MSG_TRACK: DB     CR, LF, 'Cylinder $'
MSG_BUSY:  DB     ' ... $'
MSG_OK:    DB     'OK$'

SRC_DRIVE: DB      0
DST_DRIVE: DB      1
TRACK:     DB      0
SECTOR:    DB      1
ERRSTAT:   DB      0
DMA_PTR:   DW      BUFFER
