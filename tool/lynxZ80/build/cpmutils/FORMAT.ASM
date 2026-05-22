; Lynx-Z80 CP/M 2.2 FORMAT.COM
; Optimized for Z80 (MacroAssembler AS)

        CPU     Z80

BDOS    EQU     0005H
CONOUT  EQU     0002H
PRINT   EQU     0009H
RDCON   EQU     0001H

SETTRK  EQU     0F21EH
SELDSK  EQU     0F21BH
SETSEC  EQU     0F221H
SETDMA  EQU     0F224H
WRITE   EQU     0F22AH
WBOOT   EQU     0000H

FIRSTTRK EQU    2
DATATRK  EQU    0
LASTTRK  EQU    76
LASTSEC  EQU    26
MAXDRV   EQU    4
CR       EQU     0DH
LF       EQU     0AH
TAB      EQU     09H

ARGCNT   EQU     0080H
ARGPTR   EQU     0081H

        ORG     0100H

START:
        CALL    PARSEARG
        LD      DE, MSG_HELLO
        LD      C, PRINT
        CALL    BDOS
        LD      A, (MODE)
        OR      A
        JR      NZ, GOTMODE_OK
        LD      DE, MSG_SELECT
        LD      C, PRINT
        CALL    BDOS
        CALL    GETMODE
GOTMODE_OK:
        CP      'S'
        JP      Z, MODE_SYSTEM
        CP      'D'
        JP      Z, MODE_DATA
        JP      EXIT

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
        AND     05FH
        CP      '/'
        JR      Z, PA_SWITCH
        CP      '-'
        JR      Z, PA_SWITCH
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
        LD      C, PRINT
        CALL    BDOS
        JP      WBOOT

MODE_SYSTEM:
        LD      A, FIRSTTRK
        LD      (STARTTRK), A
        LD      DE, MSG_SYS
        JR      CONFIRM

MODE_DATA:
        LD      A, DATATRK
        LD      (STARTTRK), A
        LD      DE, MSG_DATA

CONFIRM:
        LD      C, PRINT
        CALL    BDOS
        LD      A, (AUTO)
        OR      A
        JR      Z, CONFIRM_ASK
        LD      DE, MSG_AUTO
        LD      C, PRINT
        CALL    BDOS
        JR      DO_FORMAT

CONFIRM_ASK:
        LD      DE, MSG_OK
        LD      C, PRINT
        CALL    BDOS
        CALL    GETKEY
        AND     05FH
        CP      'Y'
        JR      NZ, EXIT

DO_FORMAT:
        LD	A, (DRIVE)
        LD      C, A
        LD      E, 0
        CALL    SELDSK
        LD      A, H
        OR      L
        JR      Z, WERR

        CALL    FILLBUF
        LD      A, (STARTTRK)
        LD      (TRACK), A

TRKLP:
        LD      A, 1
        LD      (SECTOR), A

SECLP:
        LD      A, (TRACK)
        LD      C, A
        LD      B, 0
        CALL    SETTRK

        LD      A, (SECTOR)
        LD      C, A
        LD      B, 0
        CALL    SETSEC

        LD      BC, BUFFER
        CALL    SETDMA

        LD      C, 0
        CALL    WRITE
        OR      A
        JR      NZ, WERR

        LD      E, '.'
        LD      C, CONOUT
        CALL    BDOS

        LD      A, (SECTOR)
        INC     A
        LD      (SECTOR), A
        CP      LASTSEC+1
        JR      NZ, SECLP

        CALL    CRLF
        LD      A, (TRACK)
        INC     A
        LD      (TRACK), A
        CP      LASTTRK+1
        JR      NZ, TRKLP

        LD      DE, MSG_DONE
        LD      C, PRINT
        CALL    BDOS
        JP      WBOOT

WERR:
        LD      DE, MSG_WERR
        LD      C, PRINT
        CALL    BDOS
EXIT:
        JP      WBOOT

GETMODE:
        LD      C, RDCON
        CALL    BDOS
        AND     05FH
        RET

GETKEY:
        LD      C, RDCON
        CALL    BDOS
        RET

CRLF:
        LD      E, 0DH
        LD      C, CONOUT
        CALL    BDOS
        LD      E, 0AH
        LD      C, CONOUT
        JP      BDOS

FILLBUF:
        LD      HL, BUFFER
        LD      (HL), 0E5H
        LD      DE, BUFFER+1
        LD      BC, 127
        LDIR                    ; Fast Z80 fill
        RET

MSG_HELLO:
        DB      CR, LF, 'FORMAT UTIL', CR, LF
        DB      'Usage: FORMAT [A:|B:|C:|D:] [S|D|/S|/D] [/Y]', CR, LF
        DB      'S = system disk (preserve tracks 0-1)', CR, LF
        DB      'D = data disk (erase all tracks)', CR, LF, '$'
MSG_SELECT:
        DB      'Select S/D or RETURN to cancel: $'
MSG_SYS:  DB      CR, LF, 'System format: $'
MSG_DATA: DB      CR, LF, 'Data format: $'
MSG_OK:   DB      'OK (Y/N)? $'
MSG_AUTO: DB      'start.', CR, LF, '$'
MSG_DONE: DB      CR, LF, 'Format complete.', CR, LF, '$'
MSG_WERR: DB      CR, LF, 'Write error - aborted.', CR, LF, '$'
MSG_BADARG: DB    CR, LF, 'Bad argument.', CR, LF, '$'

DRIVE:  DB      0           ; 0=A:, 1=B:
MODE:     DB      0           ; 0=ask, 'S'=system, 'D'=data
AUTO:     DB      0           ; non-zero skips confirmation
STARTTRK: DB      FIRSTTRK
TRACK:    DB      0
SECTOR:   DB      0
BUFFER:   DS      128
