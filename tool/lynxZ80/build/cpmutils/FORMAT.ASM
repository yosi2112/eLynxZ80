; Lynx-Z80 CP/M 2.2 FORMAT.COM
; Rewritten against Lynx-Z80 floppy I/F and MB8877 behavior.

        CPU     Z80

BDOS    EQU     0005H
WBOOT   EQU     0000H
CONOUT  EQU     0002H
PRINT   EQU     0009H
RDCON   EQU     0001H

FDCSTS  EQU     02CH
FDCCMD  EQU     02CH
FDCTRK  EQU     02DH
FDCSEC  EQU     02EH
FDCDAT  EQU     02FH
PIOAD   EQU     030H
PIOBD   EQU     031H
PIOAC   EQU     032H
PIOBC   EQU     033H

FIRSTTRK EQU    1
DATATRK  EQU    0
LASTTRK  EQU    39
LASTSEC  EQU    16
MAXDRV   EQU    2
SECSIZE  EQU     0

GAP4     EQU     40
GAP1     EQU     6
GAP2     EQU     11
GAP3     EQU     16

CR       EQU     0DH
LF       EQU     0AH
ESC      EQU     1BH
TAB      EQU     09H

ARGCNT   EQU     0080H
ARGPTR   EQU     0081H

        ORG     0100H

START:
        CALL    PARSEARG
        LD      A, (MODE)
        OR      A
        CALL    Z, MENU
        LD      A, (MODE)
        CP      'S'
        JR      Z, MODE_SYSTEM
        CP      'D'
        JR      Z, MODE_DATA
        JP      EXIT

MODE_SYSTEM:
        LD      A, FIRSTTRK
        LD      (STARTTRK), A
        JR      CONFIRM

MODE_DATA:
        LD      A, DATATRK
        LD      (STARTTRK), A

CONFIRM:
        CALL    DRAW_CONFIRM
        LD      A, (AUTO)
        OR      A
        JR      NZ, DO_FORMAT
        CALL    GETKEY_UP
        CP      'Y'
        JP      NZ, EXIT

DO_FORMAT:
        CALL    DRAW_WORK
        CALL    HW_INIT
        CALL    CHECK_READY
        JP      NZ, FERR

        XOR     A
        LD      (TRACK), A
        CALL    SEEK_TRACK
        JP      NZ, FERR

        LD      A, (STARTTRK)
        LD      (TRACK), A

TRACK_LOOP:
        XOR     A
        LD      (SIDE), A
        CALL    SHOW_TRACK_BEGIN
        CALL    KEEP_DRIVE
        CALL    SEEK_TRACK
        JP      NZ, FERR

        CALL    KEEP_DRIVE
        CALL    FORMAT_TRACK
        JP      NZ, FERR

        LD      A, 040H
        LD      (SIDE), A
        CALL    SHOW_TRACK_BEGIN
        CALL    KEEP_DRIVE
        CALL    SEEK_TRACK
        JP      NZ, FERR

        CALL    KEEP_DRIVE
        CALL    FORMAT_TRACK
        JP      NZ, FERR

        CALL    SHOW_TRACK_DONE
        LD      A, (TRACK)
        INC     A
        LD      (TRACK), A
        CP      LASTTRK+1
        JR      NZ, TRACK_LOOP

        LD      DE, MSG_DONE
        CALL    PSTR
        JP      WBOOT

FERR:
        CALL    FORCE_INTERRUPT
        LD      DE, MSG_ERR
        CALL    PSTR
        LD      A, (ERRSTAT)
        CALL    PHEX
        LD      E, 'H'
        CALL    PCHR
        CALL    CRLF
        JP      WBOOT

EXIT:
        LD      DE, MSG_EXIT
        CALL    PSTR
        JP      WBOOT

; ---------------------------------------------------------------------------
; Command line: FORMAT [A:|B:] [S|D|/S|/D] [/Y]
; ---------------------------------------------------------------------------

PARSEARG:
        LD      A, (ARGCNT)
        OR      A
        RET     Z
        LD      B, A
        LD      HL, ARGPTR

PA_SKIPSP:
        LD      A, B
        OR      A
        RET     Z
        LD      A, (HL)
        CP      ' '
        JR      Z, PA_SKIP1
        CP      TAB
        JR      NZ, PA_GOTCHR
PA_SKIP1:
        INC     HL
        DEC     B
        JR      PA_SKIPSP

PA_GOTCHR:
        CP      '/'
        JR      Z, PA_SWITCH
        CP      '-'
        JR      Z, PA_SWITCH
        AND     05FH
        LD      E, A
        CP      'S'
        JR      Z, PA_LETTER
        CP      'A'
        JR      C, BADARG
        CP      'D'+1
        JR      NC, BADARG

PA_LETTER:
        INC     HL
        DEC     B
        LD      A, B
        OR      A
        JR      Z, PA_LETTER_END
        LD      A, (HL)
        CP      ':'
        JR      Z, PA_DRIVE_COLON
        CP      ' '
        JR      Z, PA_LETTER_END
        CP      TAB
        JR      Z, PA_LETTER_END
        JR      BADARG

PA_DRIVE_COLON:
        LD      A, E
        CP      'A'
        JR      C, BADARG
        CP      'A'+MAXDRV
        JR      NC, BADARG
        SUB     'A'
        LD      (DRIVE), A
        INC     HL
        DEC     B
        JR      PA_SKIPTOKEN

PA_LETTER_END:
        LD      A, E
        CP      'S'
        JR      Z, PA_SETMODE
        CP      'D'
        JR      Z, PA_SETMODE
        CP      'A'
        JR      C, BADARG
        CP      'A'+MAXDRV
        JR      NC, BADARG
        SUB     'A'
        LD      (DRIVE), A
        JR      PA_SKIPTOKEN

PA_SETMODE:
        LD      (MODE), A
        JR      PA_SKIPTOKEN

PA_SWITCH:
        INC     HL
        DEC     B
        LD      A, B
        OR      A
        JR      Z, BADARG
        LD      A, (HL)
        AND     05FH
        CP      'Y'
        JR      Z, PA_SETYES
        CP      'S'
        JR      Z, PA_SETMODE
        CP      'D'
        JR      Z, PA_SETMODE
        JR      BADARG

PA_SETYES:
        LD      A, 1
        LD      (AUTO), A

PA_SKIPTOKEN:
        LD      A, B
        OR      A
        RET     Z
        LD      A, (HL)
        CP      ' '
        JP      Z, PA_SKIPSP
        CP      TAB
        JP      Z, PA_SKIPSP
        INC     HL
        DEC     B
        JR      PA_SKIPTOKEN

BADARG:
        LD      DE, MSG_BADARG
        CALL    PSTR
        JP      WBOOT

; ---------------------------------------------------------------------------
; Menu and screen output
; ---------------------------------------------------------------------------

MENU:
        LD      DE, MSG_MENU
        CALL    PSTR
        CALL    SHOW_MENU_SELECTION
        LD      DE, MSG_MENU_PROMPT
        CALL    PSTR
MENU_KEY:
        CALL    GETKEY_UP
        CP      'S'
        JR      Z, MENU_SET
        CP      'D'
        JR      Z, MENU_SET
        CP      'A'
        JR      Z, MENU_DRIVE_A
        CP      'B'
        JR      Z, MENU_DRIVE_B
        CP      'Q'
        JR      Z, MENU_QUIT
        JR      MENU_KEY
MENU_DRIVE_A:
        XOR     A
        LD      (DRIVE), A
        JR      MENU
MENU_DRIVE_B:
        LD      A, 1
        LD      (DRIVE), A
        JR      MENU
MENU_SET:
        LD      (MODE), A
        RET
MENU_QUIT:
        XOR     A
        LD      (MODE), A
        RET

DRAW_CONFIRM:
        LD      DE, MSG_CONFIRM
        CALL    PSTR
        CALL    SHOW_SELECTION
        LD      DE, MSG_CONFIRM2
        JP      PSTR

DRAW_WORK:
        LD      DE, MSG_WORK
        CALL    PSTR
        CALL    SHOW_SELECTION
        CALL    CRLF
        RET

SHOW_SELECTION:
        LD      DE, MSG_DRIVE
        CALL    PSTR
        LD      A, (DRIVE)
        ADD     A, 'A'
        LD      E, A
        CALL    PCHR
        LD      DE, MSG_MODE
        CALL    PSTR
        LD      A, (MODE)
        LD      E, A
        JP      PCHR

SHOW_MENU_SELECTION:
        LD      DE, MSG_DRIVE
        CALL    PSTR
        LD      A, (DRIVE)
        ADD     A, 'A'
        LD      E, A
        CALL    PCHR
        LD      DE, MSG_MODE
        CALL    PSTR
        LD      A, (MODE)
        OR      A
        JR      NZ, SMS_MODE
        LD      A, '-'
SMS_MODE:
        LD      E, A
        JP      PCHR

SHOW_TRACK_BEGIN:
        LD      DE, MSG_TRACK
        CALL    PSTR
        LD      A, (TRACK)
        CALL    PHEX
        LD      DE, MSG_BUSY
        JP      PSTR

SHOW_TRACK_DONE:
        LD      DE, MSG_OK
        JP      PSTR

GETKEY_UP:
        LD      C, RDCON
        CALL    BDOS
        AND     05FH
        RET

PSTR:
        LD      C, PRINT
        JP      BDOS

PCHR:
        LD      C, CONOUT
        JP      BDOS

CRLF:
        LD      E, CR
        CALL    PCHR
        LD      E, LF
        JP      PCHR

PHEX:
        PUSH    AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL    PHEX_NIB
        POP     AF
PHEX_NIB:
        AND     0FH
        ADD     A, '0'
        CP      '9'+1
        JR      C, PHEX_OUT
        ADD     A, 7
PHEX_OUT:
        LD      E, A
        JP      PCHR

; ---------------------------------------------------------------------------
; Lynx floppy interface and MB8877 control
; ---------------------------------------------------------------------------

HW_INIT:
        LD      A, 00FH
        OUT     (PIOAC), A
        OUT     (PIOBC), A
        CALL    KEEP_DRIVE
        CALL    MOTOR_DELAY
        RET

KEEP_DRIVE:
        LD      A, (DRIVE)
        OR      A
        JR      NZ, KEEP_B
        LD      A, 008H
        JR      KEEP_OUT
KEEP_B:
        LD      A, 005H
KEEP_OUT:
        PUSH    AF
        LD      A, (SIDE)
        OUT     (PIOAD), A
        POP     AF
        OUT     (PIOBD), A
        RET

CHECK_READY:
        CALL    KEEP_DRIVE
        IN      A, (FDCSTS)
        LD      (ERRSTAT), A
        BIT     7, A
        RET

MOTOR_DELAY:
        LD      HL, 0FFFFH
MOTOR_D1:
        DEC     HL
        LD      A, H
        OR      L
        JR      NZ, MOTOR_D1
        RET

SEEK_TRACK:
        CALL    KEEP_DRIVE
        LD      A, (TRACK)
        OR      A
        JR      NZ, SEEK_TO_N
        LD      A, 008H
        OUT     (FDCCMD), A
        CALL    WAIT_FDC_TYPE1
        RET     NZ
        XOR     A
        OUT     (FDCTRK), A
        RET

SEEK_TO_N:
        OUT     (FDCDAT), A
        LD      A, 018H
        OUT     (FDCCMD), A
        CALL    WAIT_FDC_TYPE1
        RET     NZ
        LD      A, (TRACK)
        OUT     (FDCTRK), A
        XOR     A
        RET

WAIT_FDC_TYPE1:
        LD      DE, 0FFFFH
WFDC_1:
        IN      A, (FDCSTS)
        LD      (ERRSTAT), A
        BIT     0, A
        JR      Z, WFDC_DONE
        DEC     DE
        LD      A, D
        OR      E
        JR      NZ, WFDC_1
        LD      A, 1
        RET
WFDC_DONE:
        LD      A, (ERRSTAT)
        AND     098H
        RET     NZ
        XOR     A
        RET

FORCE_INTERRUPT:
        LD      A, 0D0H
        OUT     (FDCCMD), A
        RET

; ---------------------------------------------------------------------------
; Track formatter. No BDOS calls while Write Track is active.
; ---------------------------------------------------------------------------

FORMAT_TRACK:
        XOR     A
        LD      (SECTOR), A
        CALL    KEEP_DRIVE
        LD      A, 0F4H
        OUT     (FDCCMD), A

        LD      B, GAP4
        CALL    WR_BYTE_REPEAT_ZERO
        RET     NZ

FMT_SECLP:
        LD      B, GAP1
        CALL    WR_BYTE_REPEAT_ZERO
        RET     NZ

        LD      A, 0FEH
        CALL    WR_TRK_BYTE
        RET     NZ
        LD      A, (TRACK)
        CALL    WR_TRK_BYTE
        RET     NZ
        LD      A, (SIDE)
        OR      A
        JR      Z, FMT_SIDE_ID
        LD      A, 1
FMT_SIDE_ID:
        CALL    WR_TRK_BYTE
        RET     NZ
        LD      A, (SECTOR)
        INC     A
        LD      (SECTOR), A
        CALL    WR_TRK_BYTE
        RET     NZ
        LD      A, 1
        CALL    WR_TRK_BYTE
        RET     NZ
        LD      A, 0F7H
        CALL    WR_TRK_BYTE
        RET     NZ

        LD      B, GAP2
        CALL    WR_BYTE_REPEAT_ZERO
        RET     NZ

        LD      A, 0FBH
        CALL    WR_TRK_BYTE
        RET     NZ
        LD      B, SECSIZE
FMT_DATLP:
        LD      A, 0E5H
        CALL    WR_TRK_BYTE
        RET     NZ
        DJNZ    FMT_DATLP

        LD      A, 0F7H
        CALL    WR_TRK_BYTE
        RET     NZ

        LD      B, GAP3
        CALL    WR_BYTE_REPEAT_ZERO
        RET     NZ

        LD      A, (SECTOR)
        CP      LASTSEC
        JR      NZ, FMT_SECLP

FMT_PAD:
        LD      A, 04EH
        CALL    WR_TRK_BYTE
        OR      A
        JR      Z, FMT_PAD
        CP      2
        JR      Z, FMT_DONE
        RET

FMT_DONE:
        XOR     A
        RET

WR_BYTE_REPEAT_ZERO:
        XOR     A
WR_ZERO_1:
        CALL    WR_TRK_BYTE
        RET     NZ
        DJNZ    WR_ZERO_1
        RET

WR_TRK_BYTE:
        LD      E, A
WR_WAIT:
        IN      A, (FDCSTS)
        BIT     1, A
        JR      NZ, WR_OUT
        BIT     0, A
        JR      NZ, WR_WAIT
        LD      (ERRSTAT), A
        LD      A, 2
        RET
WR_OUT:
        LD      A, E
        OUT     (FDCDAT), A
        XOR     A
        RET

; ---------------------------------------------------------------------------
; Messages
; ---------------------------------------------------------------------------

MSG_MENU:
        DB      ESC, '[2J', ESC, '[H'
        DB      'Lynx-Z80 FORMAT', CR, LF
        DB      '----------------', CR, LF
        DB      'A/B : select drive', CR, LF
        DB      'S   : system disk (cylinder 0 preserved)', CR, LF
        DB      'D   : data disk (all cylinders)', CR, LF
        DB      'Q   : quit', CR, LF, CR, LF
        DB      '$'
MSG_MENU_PROMPT:
        DB      CR, LF, CR, LF, 'Select command: $'
MSG_CONFIRM:
        DB      ESC, '[2J', ESC, '[H'
        DB      'FORMAT confirmation', CR, LF
        DB      '-------------------', CR, LF, '$'
MSG_CONFIRM2:
        DB      CR, LF, 'Type Y to start: $'
MSG_WORK:
        DB      ESC, '[2J', ESC, '[H'
        DB      'FORMAT running', CR, LF
        DB      '--------------', CR, LF, '$'
MSG_DRIVE:
        DB      'Drive $'
MSG_MODE:
        DB      '  Mode $'
MSG_TRACK:
        DB      CR, LF, 'Cylinder $'
MSG_BUSY:
        DB      ' ... $'
MSG_OK:
        DB      'OK$'
MSG_DONE:
        DB      CR, LF, 'Format complete.', CR, LF, '$'
MSG_ERR:
        DB      CR, LF, 'Format aborted. FDC status=$'
MSG_EXIT:
        DB      CR, LF, 'Canceled.', CR, LF, '$'
MSG_BADARG:
        DB      CR, LF, 'Bad argument. Usage: FORMAT [A:|B:] [S|D|/S|/D] [/Y]', CR, LF, '$'

DRIVE:    DB      0
MODE:     DB      0
AUTO:     DB      0
STARTTRK: DB      FIRSTTRK
TRACK:    DB      0
SECTOR:   DB      0
SIDE:     DB      0
ERRSTAT:  DB      0

        END
