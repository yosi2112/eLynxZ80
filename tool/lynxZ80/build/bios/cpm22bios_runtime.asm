; Lynx Z80 runtime BIOS for CP/M 2.2
; Loaded by biosrom.asm into RAM at 2000H

FDC_CMD_PORT        EQU     02CH
FDC_TRK_PORT        EQU     02DH
FDC_SEC_PORT        EQU     02EH
FDC_DATA_PORT       EQU     02FH
PIO_PORT_B_DATA     EQU     031H
PIO_PORT_A_CTRL     EQU     032H
PIO_PORT_B_CTRL     EQU     033H
SIO_CHB_DATA_PORT   EQU     021H
SIO_CHB_CTRL_PORT   EQU     023H
MINSUB_PORT         EQU     03CH
MINSUB_DR_FULL      EQU     002H
MINSUB_SUB_BUSY     EQU     001H

CPM_CBASE           EQU     0DC00H
CTRL_RUNTIME        EQU     008H

        ORG     2000H

BOOT_TARGET:
        DEFW    0

        JP      BIOS_ENTER_CPM
        JP      BIOS_NMI_HANDLER

BIOS_BOOT:
        CALL    BIOS_CONSOLE_INIT
        CALL    BIOS_PRINT_SIGNON
        LD      HL,0080H
        LD      (DMA_ADDR),HL
        XOR     A
        LD      (CURRENT_DRIVE),A
        LD      (CURRENT_TRACK),A
        LD      (CURRENT_TRACK+1),A
        INC     A
        LD      (CURRENT_SECTOR),A
        XOR     A
        LD      (CURRENT_SECTOR+1),A
        LD      A,CTRL_RUNTIME
        LD      (CTRL_SHADOW),A
        LD      C,0
        JP      CPM_CBASE

BIOS_WBOOT:
        CALL    BIOS_CONSOLE_INIT
        
        ; ドライブAを選択し、トラック0・セクタ1にセット
        XOR     A
        LD      (CURRENT_DRIVE),A
        LD      (CURRENT_TRACK),A
        LD      (CURRENT_TRACK+1),A
        INC     A
        LD      (CURRENT_SECTOR),A
        XOR     A
        LD      (CURRENT_SECTOR+1),A
        
        ; DMAアドレスをCP/Mのロード先(0DC00H)にセット
        LD      HL,CPM_CBASE
        LD      (DMA_ADDR),HL
        
        ; CP/Mイメージサイズ 5683バイト = 45セクタ (128バイト/セクタ)
        LD      B,45
BIOS_WBOOT_LOOP:
        PUSH    BC
        CALL    FDC_READ_SECTOR
        POP     BC
        JR      C,BIOS_WBOOT_FAIL
        
        ; DMAアドレスを128バイト(1セクタ分)進める
        LD      HL,(DMA_ADDR)
        LD      DE,128
        ADD     HL,DE
        LD      (DMA_ADDR),HL
        
        ; セクタを1進める (1トラック=26セクタ。26を超えたら次のトラックへ)
        LD      A,(CURRENT_SECTOR)
        INC     A
        CP      27
        JR      C,BIOS_WBOOT_NEXT_SEC
        LD      A,1
        LD      (CURRENT_SECTOR),A
        LD      A,(CURRENT_TRACK)
        INC     A
        LD      (CURRENT_TRACK),A
        JR      BIOS_WBOOT_SEC_DONE
BIOS_WBOOT_NEXT_SEC:
        LD      (CURRENT_SECTOR),A
BIOS_WBOOT_SEC_DONE:
        DJNZ    BIOS_WBOOT_LOOP
        
        ; ウォームブート完了処理
        ; デフォルトのDMA(0080H)を復元
        LD      HL,0080H
        LD      (DMA_ADDR),HL
        
        ; ドライブA(0)を指定してCCPの先頭へジャンプ
        LD      A,CTRL_RUNTIME
        LD      (CTRL_SHADOW),A
        LD      C,0
        JP      CPM_CBASE

BIOS_WBOOT_FAIL:
        ; 読み込みエラー時の処理（ディスクが抜かれている場合など）
        LD      HL,WBOOT_ERR_MSG
        CALL    BIOS_PRINT_STRING
        CALL    BIOS_CONIN      ; 任意のキー入力待ち
        JP      BIOS_WBOOT      ; キーが押されたら最初からやり直す

BIOS_CONST:
        XOR     A
        OUT     (SIO_CHB_CTRL_PORT),A
        IN      A,(SIO_CHB_CTRL_PORT)
        AND     001H
        RET     Z
        LD      A,0FFH
        RET

BIOS_CONIN:
BIOS_CONIN_WAIT:
        XOR     A
        OUT     (SIO_CHB_CTRL_PORT),A
        IN      A,(SIO_CHB_CTRL_PORT)
        AND     001H
        JR      Z,BIOS_CONIN_WAIT
        IN      A,(SIO_CHB_DATA_PORT)
        RET

BIOS_CONOUT:
        PUSH    BC
        LD      B,C
BIOS_CONOUT_WAIT:
        IN      A,(MINSUB_PORT)
        AND     MINSUB_DR_FULL+MINSUB_SUB_BUSY
        JR      NZ,BIOS_CONOUT_WAIT
        LD      A,B
        OUT     (MINSUB_PORT),A
        POP     BC
        RET

BIOS_PRINT_STRING:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        LD      C,A
        CALL    BIOS_CONOUT
        POP     HL
        INC     HL
        JR      BIOS_PRINT_STRING

BIOS_PRINT_SIGNON:
        LD      HL,SIGNON_MSG
        JP      BIOS_PRINT_STRING

BIOS_LIST:
        RET

BIOS_PUNCH:
        RET

BIOS_READER:
        JP      BIOS_CONIN

BIOS_HOME:
        XOR     A
        LD      (CURRENT_TRACK),A
        LD      (CURRENT_TRACK+1),A
        CALL    FDC_SELECT_DRIVE
        LD      A,008H
        OUT     (FDC_CMD_PORT),A
        CALL    FDC_WAIT_NOT_BUSY
        RET

BIOS_SELDSK:
        LD      A,C
        CP      1
        JR      NC,BIOS_SELDSK_INVALID
        LD      (CURRENT_DRIVE),A
        LD      HL,DPH0
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

BIOS_ENTER_CPM:
        CALL    BIOS_CONSOLE_INIT
        CALL    BIOS_PIO_INIT
        LD      A,CTRL_RUNTIME
        LD      (CTRL_SHADOW),A
        OUT     (PIO_PORT_B_DATA),A
        LD      HL,(BOOT_TARGET)
        JP      (HL)

BIOS_NMI_HANDLER:
        RETN

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

FDC_SELECT_DRIVE:
        LD      A,(CURRENT_DRIVE)
        AND     03H
        OR      008H
        LD      (CTRL_SHADOW),A
        OUT     (PIO_PORT_B_DATA),A
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

FDC_READ_SECTOR:
        CALL    FDC_SEEK_TRACK
        RET     C
        LD      A,(CURRENT_TRACK)
        OUT     (FDC_TRK_PORT),A
        LD      A,(CURRENT_SECTOR)
        OUT     (FDC_SEC_PORT),A
        LD      A,088H
        OUT     (FDC_CMD_PORT),A
        LD      HL,(DMA_ADDR)
        LD      B,128
FDC_READ_BYTE_LOOP:
        CALL    FDC_WAIT_DRQ
        JR      C,FDC_READ_FAIL
        IN      A,(FDC_DATA_PORT)
        LD      (HL),A
        INC     HL
        DJNZ    FDC_READ_BYTE_LOOP
        JP      FDC_WAIT_NOT_BUSY

FDC_READ_FAIL:
        SCF
        RET

FDC_WRITE_SECTOR:
        CALL    FDC_SEEK_TRACK
        RET     C
        LD      A,(CURRENT_TRACK)
        OUT     (FDC_TRK_PORT),A
        LD      A,(CURRENT_SECTOR)
        OUT     (FDC_SEC_PORT),A
        LD      A,0A8H
        OUT     (FDC_CMD_PORT),A
        LD      HL,(DMA_ADDR)
        LD      B,128
FDC_WRITE_BYTE_LOOP:
        CALL    FDC_WAIT_DRQ
        JR      C,FDC_WRITE_FAIL
        LD      A,(HL)
        OUT     (FDC_DATA_PORT),A
        INC     HL
        DJNZ    FDC_WRITE_BYTE_LOOP
        JP      FDC_WAIT_NOT_BUSY

FDC_WRITE_FAIL:
        SCF
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

; MS-DOS-compatible physical sector order: no CP/M skew.
SECTRAN:
        DEFB    1,2,3,4,5,6,7,8,9,10,11,12,13
        DEFB    14,15,16,17,18,19,20,21,22,23,24,25,26

DPH0:
        DEFW    SECTRAN
        DEFW    SCRATCH1
        DEFW    SCRATCH2
        DEFW    SCRATCH3
        DEFW    DIRBUF
        DEFW    DPB0
        DEFW    CSV0
        DEFW    ALV0

DPB0:
        DEFW    26              ; SPT: 26 physical 128-byte sectors/track
        DEFB    3               ; BSH: 1024-byte allocation blocks
        DEFB    7               ; BLM
        DEFB    0               ; EXM
        DEFW    242             ; DSM: 243 data blocks after reserved tracks
        DEFW    63              ; DRM: 64 directory entries
        DEFB    0C0H            ; AL0
        DEFB    00H             ; AL1
        DEFW    16              ; CKS
        DEFW    2               ; OFF: two reserved system tracks

CTRL_SHADOW:
        DEFB    CTRL_RUNTIME
CURRENT_DRIVE:
        DEFB    0
CURRENT_TRACK:
        DEFW    0
CURRENT_SECTOR:
        DEFW    1
DMA_ADDR:
        DEFW    0080H

SCRATCH1:
        DS      2
SCRATCH2:
        DS      2
SCRATCH3:
        DS      2
CSV0:
        DS      16
ALV0:
        DS      31
DIRBUF:
        DS      128

SIGNON_MSG:
        DEFB    00DH,00AH
        DEFB    'LYNX-Z80 Dual CPU computer',00DH,00AH
        DEFB    '62k CP/M Version 2.2 (C) 1982 Digital Reserch Inc.',00DH,00AH
        DEFB    'CBIOS VER. 1.0 Written with Codex by yosi',00DH,00AH
        DEFB    'TPA:DB00H (0100H-DBFFH)',00DH,00AH
        DEFB    0
WBOOT_ERR_MSG:
        DEFB    'WBOOT Failed.',00DH,00AH
        DEFB    'Insert System disk to drive A:',00DH,00AH
        DEFB    'Hit RETURN key to retry',00DH,00AH,0
