; Lynx-Z80 CP/M 2.2 DISKCOPY.COM
; Disk copy through the Lynx FDC.
;
; 2D geometry: 40 tracks, 2 sides, 16 sectors/side, 256 bytes/sector.
; Sector numbering is sequential with a sector gap/interleave of 1.
; Reading physical sectors here avoids the resident BIOS logical-sector
; mapping and copies the complete 8 KB track pair without missing a side.
; The target disk must already be formatted.

        CPU     Z80

BDOS    EQU     0005H
WBOOT   EQU     0000H
CONOUT  EQU     0002H
PRINT   EQU     0009H
RDCON   EQU     0001H

FDC_CMD_PORT   EQU 02CH
FDC_TRK_PORT   EQU 02DH
FDC_SEC_PORT   EQU 02EH
FDC_DATA_PORT  EQU 02FH
PIO_PORT_A_DATA EQU 030H
PIO_PORT_B_DATA EQU 031H

FIRSTTRK EQU    0
LASTTRK  EQU    39
SIDES    EQU    2
PHYSSEC  EQU    16
SECGAP   EQU    1
SECSIZE  EQU    256
MAXDRV   EQU    2
BUFFER   EQU    08000H
SIDEB    EQU    040H

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
        LD      A, (SRC_DRIVE)
        LD      (ACTIVE_DRIVE), A
        XOR     A
        CALL    READ_SIDE
        OR      A
        RET     NZ
        LD      A, SIDEB
        CALL    READ_SIDE
        OR      A
        RET

WRITE_TRACK:
        LD      HL, BUFFER
        LD      A, (DST_DRIVE)
        LD      (ACTIVE_DRIVE), A
        XOR     A
        CALL    WRITE_SIDE
        OR      A
        RET     NZ
        LD      A, SIDEB
        CALL    WRITE_SIDE
        OR      A
        RET

READ_SIDE:
        LD      (SIDE), A
        CALL    FDC_SELECT
        CALL    FDC_SEEK
        JR      C, DISK_IO_FAIL
        LD      B, PHYSSEC
        LD      C, SECGAP
READ_PHYS_LOOP:
        PUSH    BC
        CALL    FDC_READ_PHYS
        POP     BC
        JR      C, DISK_IO_FAIL
        INC     C
        DJNZ    READ_PHYS_LOOP
        XOR     A
        RET

WRITE_SIDE:
        LD      (SIDE), A
        CALL    FDC_SELECT
        CALL    FDC_SEEK
        JR      C, DISK_IO_FAIL
        LD      B, PHYSSEC
        LD      C, SECGAP
WRITE_PHYS_LOOP:
        PUSH    BC
        CALL    FDC_WRITE_PHYS
        POP     BC
        JR      C, DISK_IO_FAIL
        INC     C
        DJNZ    WRITE_PHYS_LOOP
        XOR     A
        RET

DISK_IO_FAIL:
        LD      (ERRSTAT), A
        LD      A, 1
        RET

FDC_SELECT:
        LD      A, (ACTIVE_DRIVE)
        OR      A
        LD      A, 008H
        JR      Z, FDC_SELECT_CTRL
        LD      A, 005H
FDC_SELECT_CTRL:
        OUT     (PIO_PORT_B_DATA), A
        LD      A, (SIDE)
        OR      010H
        OUT     (PIO_PORT_A_DATA), A
        XOR     A
        OUT     (FDC_SEC_PORT), A
        RET

FDC_SEEK:
        LD      A, (TRACK)
        OR      A
        JR      NZ, FDC_SEEK_TRACK
        LD      A, 008H
        OUT     (FDC_CMD_PORT), A
        CALL    FDC_WAIT_NOT_BUSY
        RET     C
        JR      FDC_STORE_TRACK
FDC_SEEK_TRACK:
        OUT     (FDC_DATA_PORT), A
        LD      A, 018H
        OUT     (FDC_CMD_PORT), A
        CALL    FDC_WAIT_NOT_BUSY
        RET     C
FDC_STORE_TRACK:
        LD      A, (TRACK)
        OUT     (FDC_TRK_PORT), A
        OR      A
        RET

FDC_READ_PHYS:
        LD      A, C
        LD      (SECTOR), A
        LD      A, C
        OUT     (FDC_SEC_PORT), A
        LD      A, 088H
        OUT     (FDC_CMD_PORT), A
        LD      B, 0
FDC_READ_BYTE_LOOP:
        IN      A, (FDC_CMD_PORT)
        BIT     1, A
        JR      NZ, FDC_READ_BYTE_READY
        BIT     0, A
        JR      NZ, FDC_READ_BYTE_LOOP
        SCF
        RET
FDC_READ_BYTE_READY:
        IN      A, (FDC_DATA_PORT)
        LD      (HL), A
        INC     HL
        DJNZ    FDC_READ_BYTE_LOOP
        JP      FDC_WAIT_NOT_BUSY

FDC_WRITE_PHYS:
        LD      A, C
        LD      (SECTOR), A
        LD      A, C
        OUT     (FDC_SEC_PORT), A
        LD      A, 0A8H
        OUT     (FDC_CMD_PORT), A
        LD      B, 0
FDC_WRITE_BYTE_LOOP:
        IN      A, (FDC_CMD_PORT)
        BIT     1, A
        JR      NZ, FDC_WRITE_BYTE_READY
        BIT     0, A
        JR      NZ, FDC_WRITE_BYTE_LOOP
        SCF
        RET
FDC_WRITE_BYTE_READY:
        LD      A, (HL)
        OUT     (FDC_DATA_PORT), A
        INC     HL
        DJNZ    FDC_WRITE_BYTE_LOOP
        JP      FDC_WAIT_NOT_BUSY

FDC_WAIT_NOT_BUSY:
        LD      DE, 0FFFFH
FDC_WAIT_NOT_BUSY_LOOP:
        IN      A, (FDC_CMD_PORT)
        CP      0FFH
        JR      Z, FDC_WAIT_FAIL
        BIT     0, A
        JR      Z, FDC_WAIT_DONE
        DEC     DE
        LD      A, D
        OR      E
        JR      NZ, FDC_WAIT_NOT_BUSY_LOOP
FDC_WAIT_FAIL:
        SCF
        RET
FDC_WAIT_DONE:
        AND     098H
        JR      Z, FDC_WAIT_OK
        SCF
        RET
FDC_WAIT_OK:
        OR      A
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
        DB      'Geometry: 2D, 40 tracks, 2 sides, 16 x 256-byte sectors', CR, LF
        DB      'Sector gap/interleave: 1. Target disk must be formatted.', CR, LF
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
ACTIVE_DRIVE: DB    0
SIDE:      DB      0
TRACK:     DB      0
SECTOR:    DB      1
ERRSTAT:   DB      0
