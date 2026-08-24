; Lynx IPL-ROM
; 2026-06-21 VER. 2.01
;
; This ROM provides a CP/M BIOS-style call table for IPL use.

FDC_CMD_PORT        EQU     02CH
FDC_TRK_PORT        EQU     02DH
FDC_SEC_PORT        EQU     02EH
FDC_DATA_PORT       EQU     02FH
PIO_PORT_A_DATA     EQU     030H
PIO_PORT_B_DATA     EQU     031H
PIO_PORT_A_CTRL     EQU     032H
PIO_PORT_B_CTRL     EQU     033H
SIO_CHB_DATA_PORT   EQU     021H
SIO_CHB_CTRL_PORT   EQU     023H
MINSUB_PORT         EQU     03CH
MINSUB_DR_FULL      EQU     002H
MINSUB_SUB_BUSY     EQU     001H

CPM_LOAD_ADDR       EQU     0DC00H
CPM_IMAGE_SIZE      EQU     8192
; CP/M image is fixed at build time; calculate its 128-byte logical-sector
; count in the assembler instead of performing a boot-time division loop.
CPM_LOAD_SECTORS    EQU     (CPM_IMAGE_SIZE+127)/128
CPM_ENTRY_ADDR      EQU     0F202H
CPM_BOOT_ADDR       EQU     CPM_ENTRY_ADDR
; Keep this synchronized with the assembled CP/M WBOOT vector.  The CP/M
; image currently places BOOT/WBOOT at F202H/F205H; pointing at F203H enters
; the middle of the BOOT jump and makes warm boots execute invalid code.
CPM_WBOOT_ADDR      EQU     0F205H
; The BDOS entry is FBASE1, not the preceding FBASE jump table/data.
; A vector to E406H enters the BDOS error table instead of its prologue.
CPM_FBASE1_ADDR     EQU     0E413H

ROM_CTRL_BOOT       EQU     088H
ROM_CTRL_OFF        EQU     008H
ROM_SHADOW_BASE     EQU     2000H
ROM_SHADOW_SIZE     EQU     0800H

; Keep resident-only memory and ROM control choices in the assembly source.
; build_cpm22_runtime.ps1 selects this branch with -D RESIDENT_BIOS.
        IFDEF   RESIDENT_BIOS
BOOT_VARS_BASE      EQU     0F900H
DRIVE0_CTRL         EQU     008H
DRIVE1_CTRL         EQU     005H
        ELSE
BOOT_VARS_BASE      EQU     3000H
DRIVE0_CTRL         EQU     088H
DRIVE1_CTRL         EQU     085H
        ENDIF

CURRENT_DRIVE       EQU     BOOT_VARS_BASE+00H
CURRENT_TRACK       EQU     BOOT_VARS_BASE+01H
CURRENT_SECTOR      EQU     BOOT_VARS_BASE+03H
DMA_ADDR            EQU     BOOT_VARS_BASE+05H
CURRENT_SIDE        EQU     BOOT_VARS_BASE+07H
CURRENT_HALF        EQU     BOOT_VARS_BASE+08H
PHYS_SECTOR         EQU     BOOT_VARS_BASE+09H
PAYLOAD_COUNT       EQU     BOOT_VARS_BASE+0AH
CACHE_VALID         EQU     BOOT_VARS_BASE+0CH
CACHE_DRIVE         EQU     BOOT_VARS_BASE+0DH
CACHE_TRACK         EQU     BOOT_VARS_BASE+0EH
CACHE_SIDE          EQU     BOOT_VARS_BASE+0FH
CACHE_SECTOR        EQU     BOOT_VARS_BASE+010H
SECBUF              EQU     BOOT_VARS_BASE+20H

        ORG     0000H
        JP      RESET

        ORG     0008H
        JP      FAIL_TRAP

        ORG     0010H
        JP      FAIL_TRAP

        ORG     0018H
        JP      FAIL_TRAP

        ORG     0020H
        JP      FAIL_TRAP

        ORG     0028H
        JP      FAIL_TRAP

        ORG     0030H
        JP      FAIL_TRAP

        ORG     0038H
        JP      IRQ_HANDLER

        ORG     0066H
        JP      NMI_HANDLER

        ORG     0069H
; ------------------------------------------------------------
; ROM enabled状態で呼ぶ。
; 0000h-04FFh のROM内容を 2000h-24FFh へ退避する。
; ------------------------------------------------------------
IPL_COPY_ROM_TO_SHADOW:
        LD      HL,0000H
        LD      DE,ROM_SHADOW_BASE
        LD      BC,ROM_SHADOW_SIZE
        LDIR
        RET

; ------------------------------------------------------------
; ここは 2000h 側にコピーされた後、
; ROM_SHADOW_BASE + IPL_SHADOW_ENTRY の位置で実行される。
;
; 重要:
;   ROMをOFFにした後も、実行中のコードは 2000h 側RAMにあるので安全。
; ------------------------------------------------------------
IPL_SHADOW_ENTRY:
        DI

        LD      A,ROM_CTRL_OFF
        OUT     (PIO_PORT_B_DATA),A

        ; 退避しておいたROMイメージを、今度はRAMの0000hへ書き戻す
        LD      HL,ROM_SHADOW_BASE
        LD      DE,0000H
        LD      BC,ROM_SHADOW_SIZE
        LDIR

        ; ここから先は 0000h 側RAM上の同じコードへ移る
        JP      RAM_BOOT_START

; ------------------------------------------------------------
; ROM OFF後、RAM上の0000hで実行される本当の起動継続点
; ------------------------------------------------------------
RAM_BOOT_START:
        DI
        IM      1
        LD      SP,0FFFEH

        LD      HL,OPENING_MESSAGE
        CALL    BIOS_PRINT_STRING
        LD      HL,LOADMSG
        CALL    BIOS_PRINT_STRING

        CALL    BIOS_BOOT

        JP      BOOT_RETRY

LOADMSG:
        DB 'Loading...',00Dh,00AH,0

        ORG     0100H

BIOS_JUMP_TABLE:
BIOS_BOOT_JP:
        JP      BIOS_BOOT
BIOS_WBOOT_JP:
        JP      BIOS_WBOOT
BIOS_CONST_JP:
        JP      BIOS_CONST
BIOS_CONIN_JP:
        JP      BIOS_CONIN
BIOS_CONOUT_JP:
        JP      BIOS_CONOUT
BIOS_LIST_JP:
        JP      BIOS_LIST
BIOS_PUNCH_JP:
        JP      BIOS_PUNCH
BIOS_READER_JP:
        JP      BIOS_READER
BIOS_HOME_JP:
        JP      BIOS_HOME
BIOS_SELDSK_JP:
        JP      BIOS_SELDSK
BIOS_SETTRK_JP:
        JP      BIOS_SETTRK
BIOS_SETSEC_JP:
        JP      BIOS_SETSEC
BIOS_SETDMA_JP:
        JP      BIOS_SETDMA
BIOS_READ_JP:
        JP      BIOS_READ
BIOS_WRITE_JP:
        JP      BIOS_WRITE
BIOS_PRSTAT_JP:
        JP      BIOS_PRSTAT
BIOS_SECTRN_JP:
        JP      BIOS_SECTRN

RESET:
        DI
        IM      1
        LD      SP,0FFFEH

        ; ROMが見えている間に最低限のI/O初期化だけ行う
        CALL    BIOS_CONSOLE_INIT
        CALL    BIOS_PIO_INIT

        ; 念のためROM visible状態を明示
        LD      A,ROM_CTRL_BOOT
        OUT     (PIO_PORT_B_DATA),A

        ; 0000h-04FFh のROMを 2000h-24FFh へコピー
        CALL    IPL_COPY_ROM_TO_SHADOW

        ; 2000h側の IPL_SHADOW_ENTRY へ飛ぶ
        LD      HL,IPL_SHADOW_ENTRY
        LD      DE,ROM_SHADOW_BASE
        ADD     HL,DE
        JP      (HL)

BOOT_RETRY:
        DI
        IM      1
        LD      SP,0FFFEH
        CALL    BIOS_BOOT
        CALL    IPL_LOAD_CPM
        JR      C,BOOT_FAIL
        CALL    IPL_PATCH_PAGE_ZERO
        XOR     A
        LD      (0003H),A       ; IOBYTE = 0
        LD      (0004H),A       ; current drive = A:
        LD      C,A             ; CCPへ渡すcurrent drive = A:
        JP      CPM_BOOT_ADDR

BOOT_FAIL:
        CALL    BIOS_BOOT
        LD      HL,BOOT_FAIL_MESSAGE
        CALL    BIOS_PRINT_STRING
        CALL    BIOS_CONIN
        JP      BOOT_RETRY

FAIL_TRAP:
        DI
        JR      FAIL_TRAP

IRQ_HANDLER:
        EI
        RETI

NMI_HANDLER:
        RETN

IPL_LOAD_CPM:
        CALL    IPL_COMPUTE_PAYLOAD_COUNT
        LD      BC,0
        CALL    BIOS_SETTRK
        LD      BC,1
        CALL    BIOS_SETSEC
        LD      BC,CPM_LOAD_ADDR
        CALL    BIOS_SETDMA
        LD      DE,(PAYLOAD_COUNT)

IPL_LOAD_LOOP:
        LD      A,D
        OR      E
        JR      Z,IPL_LOAD_DONE

        PUSH    DE
        CALL    BIOS_READ
        POP     DE

        OR      A
        SCF
        RET     NZ

        PUSH    DE
        CALL    IPL_ADVANCE_DMA
        CALL    IPL_ADVANCE_SECTOR
        POP     DE

        DEC     DE
        JR      IPL_LOAD_LOOP

IPL_LOAD_DONE:
        OR      A
        RET

IPL_COMPUTE_PAYLOAD_COUNT:
        LD      HL,CPM_LOAD_SECTORS
        LD      (PAYLOAD_COUNT),HL
        RET

IPL_ADVANCE_DMA:
        LD      HL,(DMA_ADDR)
        LD      BC,128
        ADD     HL,BC
        LD      (DMA_ADDR),HL
        RET

IPL_ADVANCE_SECTOR:
        LD      HL,(CURRENT_SECTOR)
        INC     HL
        LD      A,L
        CP      65
        JR      C,IPL_ADVANCE_STORE_SEC

IPL_ADVANCE_NEXT_TRACK:
        LD      HL,1
        LD      (CURRENT_SECTOR),HL
        LD      HL,(CURRENT_TRACK)
        INC     HL
        LD      (CURRENT_TRACK),HL
        RET

IPL_ADVANCE_STORE_SEC:
        LD      (CURRENT_SECTOR),HL
        RET

IPL_PATCH_PAGE_ZERO:
        LD      A,0C3H
        LD      (0000H),A
        LD      HL,CPM_WBOOT_ADDR
        LD      (0001H),HL
        LD      A,0C3H
        LD      (0005H),A
        LD      HL,CPM_FBASE1_ADDR
        LD      (0006H),HL
        RET

BIOS_BOOT:
        CALL    BIOS_CONSOLE_INIT
        CALL    BIOS_PIO_INIT
        LD      A,ROM_CTRL_OFF
        OUT     (PIO_PORT_B_DATA),A
        XOR     A
        LD      (CURRENT_DRIVE),A
        LD      (CURRENT_TRACK),A
        LD      (CURRENT_TRACK+1),A
        INC     A
        LD      (CURRENT_SECTOR),A
        XOR     A
        LD      (CURRENT_SECTOR+1),A
        LD      (CURRENT_SIDE),A
        LD      (CURRENT_HALF),A
        LD      (CACHE_VALID),A
        LD      HL,0080H
        LD      (DMA_ADDR),HL
        IFDEF   RESIDENT_BIOS
        LD      C,0
        JP      CPM_CBASE_ADDR
        ELSE
        RET
        ENDIF

BIOS_WBOOT:
        IFDEF   RESIDENT_BIOS
        LD      A,(0004H)
        LD      C,A
        JP      CPM_CBASE_ADDR+3
        ELSE
        JP      RESET
        ENDIF

BIOS_CONST:
        XOR     A
        OUT     (SIO_CHB_CTRL_PORT),A
        IN      A,(SIO_CHB_CTRL_PORT)
        AND     001H
        RET     Z
        LD      A,0FFH
        RET

BIOS_CONIN:
        XOR     A
        OUT     (SIO_CHB_CTRL_PORT),A

BIOS_CONIN_WAIT:
        IN      A,(SIO_CHB_CTRL_PORT)
        AND     001H
        JR      Z,BIOS_CONIN_WAIT
        IN      A,(SIO_CHB_DATA_PORT)
        RET

BIOS_CONOUT:
        PUSH    BC
        LD      B,C
        CALL    BIOS_CONOUT_B
        POP     BC
        RET

BIOS_CONOUT_B:
        IN      A,(MINSUB_PORT)
        AND     MINSUB_DR_FULL+MINSUB_SUB_BUSY
        JR      NZ,BIOS_CONOUT_B
        LD      A,B
        OUT     (MINSUB_PORT),A
        RET

BIOS_LIST:
        RET

BIOS_PUNCH:
        RET

BIOS_READER:
        JP      BIOS_CONIN

BIOS_HOME:
        LD      BC,0
        CALL    BIOS_SETTRK
        CALL    FDC_SELECT_DRIVE
        LD      A,008H
        OUT     (FDC_CMD_PORT),A
        JP      FDC_WAIT_NOT_BUSY

BIOS_SELDSK:
        LD      A,C
        CP      2
        JR      NC,BIOS_SELDSK_INVALID
        LD      (CURRENT_DRIVE),A
        OR      A
        LD      HL,DPH0
        RET     Z
        LD      HL,DPH1
        RET

BIOS_SELDSK_INVALID:
        LD      HL,0
        RET

BIOS_SETTRK:
        LD      H,B
        LD      L,C
        LD      (CURRENT_TRACK),HL
        RET

BIOS_SETSEC:
        LD      H,B
        LD      L,C
        LD      (CURRENT_SECTOR),HL
        RET

BIOS_SETDMA:
        LD      H,B
        LD      L,C
        LD      (DMA_ADDR),HL
        RET

BIOS_READ:
        CALL    FDC_READ_SECTOR
        JR      NC,BIOS_READ_OK
        LD      A,1
        RET

BIOS_READ_OK:
        XOR     A
        RET

BIOS_WRITE:
        CALL    FDC_WRITE_SECTOR
        JR      NC,BIOS_WRITE_OK
        LD      A,1
        RET

BIOS_WRITE_OK:
        XOR     A
        RET

BIOS_PRSTAT:
        LD      A,0FFH
        RET

BIOS_SECTRN:
        LD      A,D
        OR      E
        JR      Z,BIOS_SECTRN_IDENTITY
        EX      DE,HL
        ADD     HL,BC
        LD      A,(HL)
        LD      L,A
        LD      H,0
        RET

BIOS_SECTRN_IDENTITY:
        LD      H,B
        LD      L,C
        RET

BIOS_CONSOLE_INIT:
        LD      A,018H
        OUT     (SIO_CHB_CTRL_PORT),A
        LD      A,004H
        OUT     (SIO_CHB_CTRL_PORT),A
        LD      A,044H
        OUT     (SIO_CHB_CTRL_PORT),A
        LD      A,003H
        OUT     (SIO_CHB_CTRL_PORT),A
        LD      A,0C1H
        OUT     (SIO_CHB_CTRL_PORT),A
        LD      A,005H
        OUT     (SIO_CHB_CTRL_PORT),A
        LD      A,060H
        OUT     (SIO_CHB_CTRL_PORT),A
        RET

BIOS_PIO_INIT:
        LD      A,00FH
        OUT     (PIO_PORT_A_CTRL),A
        OUT     (PIO_PORT_B_CTRL),A
        RET

BIOS_PRINT_STRING:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        LD      B,A
        CALL    BIOS_CONOUT_B
        POP     HL
        INC     HL
        JR      BIOS_PRINT_STRING

FDC_SELECT_DRIVE:
        LD      A,(CURRENT_DRIVE)
        AND     01H
        LD      A,DRIVE0_CTRL
        JR      Z,FDC_SELECT_DRIVE_CTRL
        LD      A,DRIVE1_CTRL

FDC_SELECT_DRIVE_CTRL:
        OUT     (PIO_PORT_B_DATA),A
        LD      A,(CURRENT_SIDE)
        OR      010H
        OUT     (PIO_PORT_A_DATA),A
        XOR     A
        OUT     (FDC_SEC_PORT),A
        RET

FDC_SEEK_TRACK:
        CALL    FDC_SELECT_DRIVE
        LD      HL,(CURRENT_TRACK)
        LD      A,L
        OR      A
        JR      NZ,FDC_SEEK_TRACK_SEEK
        LD      A,008H
        OUT     (FDC_CMD_PORT),A
        JP      FDC_WAIT_NOT_BUSY

FDC_SEEK_TRACK_SEEK:
        OUT     (FDC_DATA_PORT),A
        LD      A,018H
        OUT     (FDC_CMD_PORT),A
        JP      FDC_WAIT_NOT_BUSY

FDC_MAP_LOGICAL_SECTOR:
        LD      HL,(CURRENT_SECTOR)
        DEC     HL
        LD      A,L
        AND     001H
        LD      (CURRENT_HALF),A
        LD      A,L
        SRL     A
        LD      B,000H
        CP      16
        JR      C,FDC_MAP_SIDE_DONE
        SUB     16
        LD      B,040H

FDC_MAP_SIDE_DONE:
        INC     A
        LD      (PHYS_SECTOR),A
        LD      A,B
        LD      (CURRENT_SIDE),A
        RET

FDC_READ_SECTOR:
        CALL    FDC_MAP_LOGICAL_SECTOR
        CALL    FDC_CACHE_MATCH
        JR      NC,FDC_READ_SECTOR_CACHED
        CALL    FDC_READ_PHYSICAL_SECTOR
        RET     C
        CALL    FDC_CACHE_STORE

FDC_READ_SECTOR_CACHED:
        JP      FDC_COPY_HALF_TO_DMA

FDC_WRITE_SECTOR:
        CALL    FDC_MAP_LOGICAL_SECTOR
        CALL    FDC_CACHE_MATCH
        JR      NC,FDC_WRITE_SECTOR_CACHED
        CALL    FDC_READ_PHYSICAL_SECTOR
        RET     C

FDC_WRITE_SECTOR_CACHED:
        CALL    FDC_COPY_DMA_TO_HALF
        CALL    FDC_WRITE_PHYSICAL_SECTOR
        JR      C,FDC_WRITE_SECTOR_FAIL
        CALL    FDC_CACHE_STORE
        OR      A
        RET

FDC_WRITE_SECTOR_FAIL:
        CALL    FDC_CACHE_INVALIDATE
        SCF
        RET

FDC_READ_PHYSICAL_SECTOR:
        CALL    FDC_SEEK_TRACK
        RET     C
        LD      A,(CURRENT_TRACK)
        OUT     (FDC_TRK_PORT),A
        LD      A,(PHYS_SECTOR)
        OUT     (FDC_SEC_PORT),A
        LD      A,088H
        OUT     (FDC_CMD_PORT),A
        LD      HL,SECBUF
        CALL    FDC_PHYSICAL_BYTE_COUNT

FDC_READ_BYTE_LOOP:
        IN      A,(FDC_CMD_PORT)
        BIT     1,A
        JR      NZ,FDC_READ_BYTE_READY
        BIT     0,A
        JR      NZ,FDC_READ_BYTE_LOOP
        JR      FDC_READ_FAIL

FDC_READ_BYTE_READY:
        IN      A,(FDC_DATA_PORT)
        LD      (HL),A
        INC     HL
        DJNZ    FDC_READ_BYTE_LOOP
        JP      FDC_WAIT_NOT_BUSY

FDC_READ_FAIL:
        SCF
        RET

FDC_WRITE_PHYSICAL_SECTOR:
        CALL    FDC_SEEK_TRACK
        RET     C
        LD      A,(CURRENT_TRACK)
        OUT     (FDC_TRK_PORT),A
        LD      A,(PHYS_SECTOR)
        OUT     (FDC_SEC_PORT),A
        LD      A,0A8H
        OUT     (FDC_CMD_PORT),A
        LD      HL,SECBUF
        CALL    FDC_PHYSICAL_BYTE_COUNT

FDC_WRITE_BYTE_LOOP:
        IN      A,(FDC_CMD_PORT)
        BIT     1,A
        JR      NZ,FDC_WRITE_BYTE_READY
        BIT     0,A
        JR      NZ,FDC_WRITE_BYTE_LOOP
        JR      FDC_WRITE_FAIL

FDC_WRITE_BYTE_READY:
        LD      A,(HL)
        OUT     (FDC_DATA_PORT),A
        INC     HL
        DJNZ    FDC_WRITE_BYTE_LOOP
        JP      FDC_WAIT_NOT_BUSY

FDC_WRITE_FAIL:
        SCF
        RET

FDC_PHYSICAL_BYTE_COUNT:
        LD      B,0
        RET

FDC_HALF_BUFFER_ADDR:
        LD      HL,SECBUF
        LD      A,(CURRENT_HALF)
        OR      A
        RET     Z
        LD      DE,128
        ADD     HL,DE
        RET

FDC_COPY_HALF_TO_DMA:
        CALL    FDC_HALF_BUFFER_ADDR
        LD      DE,(DMA_ADDR)
        LD      BC,128
        LDIR
        OR      A
        RET

FDC_COPY_DMA_TO_HALF:
        CALL    FDC_HALF_BUFFER_ADDR
        EX      DE,HL
        LD      HL,(DMA_ADDR)
        LD      BC,128
        LDIR
        RET

FDC_CACHE_MATCH:
        LD      A,(CACHE_VALID)
        OR      A
        SCF
        RET     Z
        LD      A,(CURRENT_DRIVE)
        LD      B,A
        LD      A,(CACHE_DRIVE)
        CP      B
        SCF
        RET     NZ
        LD      A,(CURRENT_TRACK)
        LD      B,A
        LD      A,(CACHE_TRACK)
        CP      B
        SCF
        RET     NZ
        LD      A,(CURRENT_SIDE)
        LD      B,A
        LD      A,(CACHE_SIDE)
        CP      B
        SCF
        RET     NZ
        LD      A,(PHYS_SECTOR)
        LD      B,A
        LD      A,(CACHE_SECTOR)
        CP      B
        SCF
        RET     NZ
        OR      A
        RET

FDC_CACHE_STORE:
        LD      A,(CURRENT_DRIVE)
        LD      (CACHE_DRIVE),A
        LD      A,(CURRENT_TRACK)
        LD      (CACHE_TRACK),A
        LD      A,(CURRENT_SIDE)
        LD      (CACHE_SIDE),A
        LD      A,(PHYS_SECTOR)
        LD      (CACHE_SECTOR),A
        LD      A,1
        LD      (CACHE_VALID),A
        RET

FDC_CACHE_INVALIDATE:
        XOR     A
        LD      (CACHE_VALID),A
        RET

FDC_WAIT_DRQ:
        LD      DE,0FFFFH

FDC_WAIT_DRQ_LOOP:
        IN      A,(FDC_CMD_PORT)
        CP      0FFH
        JR      Z,FDC_WAIT_DRQ_FAIL
        BIT     1,A
        JR      NZ,FDC_WAIT_DRQ_OK
        BIT     0,A
        JR      Z,FDC_WAIT_DRQ_FAIL
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,FDC_WAIT_DRQ_LOOP

FDC_WAIT_DRQ_FAIL:
        SCF
        RET

FDC_WAIT_DRQ_OK:
        OR      A
        RET

FDC_WAIT_NOT_BUSY:
        LD      DE,0FFFFH

FDC_WAIT_NOT_BUSY_LOOP:
        IN      A,(FDC_CMD_PORT)
        CP      0FFH
        JR      Z,FDC_WAIT_NOT_BUSY_FAIL
        BIT     0,A
        JR      Z,FDC_WAIT_NOT_BUSY_DONE
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,FDC_WAIT_NOT_BUSY_LOOP

FDC_WAIT_NOT_BUSY_FAIL:
        SCF
        RET

FDC_WAIT_NOT_BUSY_DONE:
        AND     098H
        JR      Z,FDC_WAIT_NOT_BUSY_OK
        SCF
        RET

FDC_WAIT_NOT_BUSY_OK:
        OR      A
        RET

SECTRAN:
        DEFB    1,2,3,4,5,6,7,8,9,10,11,12,13
        DEFB    14,15,16,17,18,19,20,21,22,23,24,25,26
        DEFB    27,28,29,30,31,32,33,34,35,36,37,38,39
        DEFB    40,41,42,43,44,45,46,47,48,49,50,51,52
        DEFB    53,54,55,56,57,58,59,60,61,62,63,64

DPH0:
        DEFW    SECTRAN
        DEFW    SCRATCH1
        DEFW    SCRATCH2
        DEFW    SCRATCH3
        DEFW    DIRBUF
        DEFW    DPB0
        DEFW    CSV0
        DEFW    ALV0

DPH1:
        DEFW    SECTRAN
        DEFW    SCRATCH1
        DEFW    SCRATCH2
        DEFW    SCRATCH3
        DEFW    DIRBUF
        DEFW    DPB0
        DEFW    CSV1
        DEFW    ALV1

DPB0:
        DEFW    64
        DEFB    4
        DEFB    15
        DEFB    1
        DEFW    151
        DEFW    127
        DEFB    0C0H
        DEFB    00H
        DEFW    32
        DEFW    2

SCRATCH1           EQU     BOOT_VARS_BASE+0120H
SCRATCH2           EQU     BOOT_VARS_BASE+0122H
SCRATCH3           EQU     BOOT_VARS_BASE+0124H
CSV0               EQU     BOOT_VARS_BASE+0130H
ALV0               EQU     BOOT_VARS_BASE+0150H
CSV1               EQU     BOOT_VARS_BASE+0190H
ALV1               EQU     BOOT_VARS_BASE+01B0H
DIRBUF             EQU     BOOT_VARS_BASE+01F0H

OPENING_MESSAGE:
        DEFB    'LYNX-Z80 CP/M IPL ROM Ver. 2.01',00DH,00AH
        DEFB    'Build date:',DATE,00DH,00AH,0

BOOT_FAIL_MESSAGE:
        DEFB    'Insert System disk to drive A:',00DH,00AH
        DEFB    'Hit any key to retry',00DH,00AH,0
	END
