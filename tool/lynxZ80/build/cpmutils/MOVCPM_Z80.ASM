    TITLE   'CP/M VERSION 2.2 SYSTEM RELOCATOR - Z80 OPTIMIZED'
    ; Optimized for Z80 by AI
    ; Assembler: MacroAssembler AS

    CPU     Z80

BIOSWK  EQU     03H     ; THREE PAGES FOR BIOS WORKSPACE
STACK   EQU     0800H
MODSIZ  EQU     0801H   ; MODULE SIZE IS STORED HERE
VERSION EQU     22      ; CPM VERSION NUMBER
BOOTSIZ EQU     0100H   ; SIZE OF THE COLD START LOADER
BDOSL   EQU     0800H   ; RELATIVE LOCATION OF BDOS
BIOS    EQU     1600H   ; RELATIVE LOCATION OF BIOS
BOOT    EQU     0000H   ; REBOOT LOCATION
BDOS    EQU     0005H
PRNT    EQU     9       ; PRINT BUFFER FUNCTION
FCB     EQU     005CH   ; DEFAULT FCB
MODULE  EQU     0900H   ; MODULE ADDRESS
CR      EQU     0DH
LF      EQU     0AH

    ORG     100H
    JP      PASTCOPY
COPY:   DB      'COPYRIGHT (C) DIGITAL RESEARCH, 1979     '
PASTCOPY:
    LD      SP, STACK

    ; メモリサイズの取得（引数チェック）
    LD      A, (FCB+1)
    CP      ' '
    JP      Z, FINDTOP
    CP      '?'
    JP      Z, FINDTOP

    ; 文字列からデシマル変換
    LD      DE, FCB+1
    LD      HL, 0
CLOOP:
    LD      A, (DE)
    INC     DE
    CP      ' '
    JP      Z, ECON
    OR      A
    JP      Z, ECON
    SUB     '0'
    CP      10
    JP      NC, CERROR
    
    ; HL = HL * 10 + A
    LD      B, H
    LD      C, L
    ADD     HL, HL      ; *2
    ADD     HL, HL      ; *4
    ADD     HL, BC      ; *5
    ADD     HL, HL      ; *10
    LD      C, A
    LD      B, 0
    ADD     HL, BC
    JP      CLOOP

ECON:
    LD      A, H
    OR      A
    JP      NZ, CERROR
    LD      A, L
    CP      16
    JP      C, CERROR
    
    ; HL = (A * 1024) >> 8 は単に H=A, L=0
    LD      H, A
    LD      L, 0
    ADD     HL, HL      ; SHL 1
    ADD     HL, HL      ; SHL 2 (Kバイトからページ単位)
    JP      SETASC

CERROR:
    LD      DE, CONMSG
    CALL    PRINT
    JP      BOOT
CONMSG: DB      CR, LF, 'INVALID MEMORY SIZE$'

    ; メモリ末尾の自動検出
FINDTOP:
    LD      HL, 0
FINDM:
    INC     H           ; 次のページへ
    JP      Z, MSIZED   ; 64Kオーバーフロー対策
    LD      A, (HL)
    CPL
    LD      (HL), A
    CP      (HL)
    CPL
    LD      (HL), A
    JP      Z, FINDM    ; 書き換え成功なら次へ

MSIZED:
    LD      A, H
    AND     11111100B   ; 1K境界に切り捨て
    LD      H, A
    LD      L, 0

SETASC:
    PUSH    HL          ; メモリTOPを保存
    ; シリアライズ処理
    LD      HL, (BDOS+1)
    LD      (SER1), HL
    POP     HL
    PUSH    HL

    ; メモリサイズ(K)を計算して文字列化
    LD      A, H
    RRA
    RRA
    AND     00111111B
    JR      NZ, NOT64
    LD      A, 64
NOT64:
    LD      B, A        ; B = Kバイト数
    LD      HL, AMEM
    LD      (HL), '0'
    INC     HL
    LD      (HL), '0'
ASC0:
    LD      HL, AMEM+1
    INC     (HL)
    LD      A, (HL)
    CP      '9'+1
    JR      C, ASC1
    LD      (HL), '0'
    DEC     HL
    INC     (HL)
ASC1:
    DJNZ    ASC0

    LD      DE, MEMSG
    CALL    PRINT

    ; モジュールサイズの取得
    LD      BC, (MODSIZ)
    PUSH    BC          ; モジュールサイズをスタックへ

    ; バージョン文字列の検索
    LD      HL, MODULE
    ; BC はモジュールサイズ
SLOOP:
    LD      A, 'k'      ; "k CP/M" の 'k' を探す
    CPIR
    JP      NZ, ESEAR   ; 見つからなければ終了
    
    ; 'k' が見つかったので残りの文字列を比較
    PUSH    HL
    PUSH    BC
    LD      DE, AMSG+1  ; " CP/M..."
    LD      B, LAMSG-1
CHLOOP:
    LD      A, (DE)
    CP      (HL)
    JR      NZ, NOMATCH
    INC     DE
    INC     HL
    DJNZ    CHLOOP
    
    ; マッチした：メモリサイズ文字列を埋め込む
    POP     BC
    POP     HL
    DEC     HL
    LD      DE, AMEM+1
    LD      A, (DE)
    LD      (HL), A
    DEC     HL
    DEC     DE
    LD      A, (DE)
    LD      (HL), A
    JP      ESEAR

NOMATCH:
    POP     BC
    POP     HL
    JP      SLOOP

ESEAR:
    ; シリアルチェック
    LD      BC, (SER1)
    LD      A, C
    CP      6
    LD      A, 0
    JP      NZ, SETJMP
    LD      (SER1), A   ; 下位バイトを0にする

    POP     BC          ; モジュールサイズ
    POP     HL          ; メモリTOP
    PUSH    BC          ; 長さを再保存
    
    ; 転送先アドレス計算
    LD      A, B
    ADD     A, BIOSWK
    LD      B, A
    ; HL = HL - BC
    OR      A
    SBC     HL, BC
    LD      (RELBAS), HL
    
    EX      DE, HL      ; DE = 転送先(RELBAS)
    LD      HL, MODULE  ; HL = 転送元
    POP     BC          ; BC = 長さ
    PUSH    BC          ; 保存
    
    LD      A, (FCB+17) ; 第2引数チェック
    CP      ' '
    JR      Z, DO_MOVE
    ; 移動しない場合：ビットマップ位置を計算
    ADD     HL, BC
    JP      RELOC

DO_MOVE:
    LD      A, B
    OR      C
    JR      Z, RELOC
    LDIR                ; Z80高速ブロック転送

RELOC:
    ; 再配置処理
    ; HL = ビットマップ開始アドレス
    ; DE = 再配置対象(MODULE または RELBAS)
    ; IX = ビットマップポインタとして使用
    PUSH    HL
    POP     IX
    
    LD      BC, (RELBAS)
    LD      HL, BOOTSIZ
    ADD     HL, BC
    LD      B, H        ; B = 再配置バイアス(上位バイト)
    
    POP     BC          ; モジュール長
    LD      A, (FCB+17)
    CP      ' '
    LD      DE, MODULE
    JR      NZ, REL0
    LD      DE, (RELBAS)

REL0:
    LD      A, B
    OR      C
    JP      Z, ENDREL

    ; シリアル同期ダミー処理
    JP      PASTSYNC
SYNCMSG: DB CR, LF, 'SYNCRONIZATION ERROR$'
PASTSYNC:

    ; ビットマップの処理
    LD      A, E
    AND     7
    JR      NZ, REL1
    LD      L, (IX+0)   ; Lに現在のビットマスクをロード
    INC     IX

REL1:
    RL      L           ; MSBをキャリーへ
    JR      NC, REL2
    
    ; 再配置実行
    LD      A, (DE)
    ADD     A, B        ; バイアスを加算
    LD      (DE), A

REL2:
    INC     DE
    ; BC(長さ)をデクリメント
    LD      A, C
    SUB     1
    LD      C, A
    LD      A, B
    SBC     A, 0
    LD      B, A
    JP      REL0

ENDREL:
    ; シリアルナンバー最終確認
    LD      DE, MODULE+BDOSL+BOOTSIZ
    LD      HL, (SER1)
    LD      B, 6
CHKSER:
    LD      A, (DE)
    CP      (HL)
    JP      NZ, SETJMP
    INC     HL
    INC     DE
    DJNZ    CHKSER

    LD      A, (FCB+17)
    CP      ' '
    JP      Z, TRANSFER

    ; SAVE用処理: 先頭128バイトが0かチェック
    LD      HL, MODULE
    LD      BC, 128
    LD      A, 0
    CPIR                ; 0でないバイトを探す
    JP      NZ, TREND   ; 全部0でなければ移動不要

    ; 80Hバイト下へシフト
    LD      DE, MODULE
    LD      HL, MODULE+128
    LD      BC, (MODSIZ)
    LD      A, C
    SUB     128
    LD      C, A
    LD      A, B
    SBC     A, 0
    LD      B, A
    LDIR

    ; シリアル不正時のジャンプ先
SETJMP:
    LD      HL, BADSER
    LD      (JMPSER+1), HL
    JP      JMPSER

BADSER:
    XOR     A
BADSER0:
    DEC     A
    JR      NZ, BADSER0
    LD      HL, 0F4F3H  ; DI / HALT
    LD      (PRHLT), HL
    LD      A, 0CDH     ; CALL
    LD      (PRJMP), A
    LD      DE, SYNCMSG
    JP      PRINT

TREND:
    ; 保存用サイズ文字列作成
    LD      BC, (MODSIZ)
    LD      HL, MODULE
    ADD     HL, BC
    LD      B, H        ; B = ページ数+1
    LD      HL, SAVMEM
    LD      (HL), '0'
    INC     HL
    LD      (HL), '0'
TRCOMP:
    DEC     B
    JR      Z, TRC1
    LD      HL, SAVMEM+1
    INC     (HL)
    LD      A, (HL)
    CP      '9'+1
    JR      C, TRCOMP
    LD      (HL), '0'
    DEC     HL
    INC     (HL)
    JP      TRCOMP

TRC1:
    LD      HL, (AMEM)
    LD      (SAVM0), HL
    LD      DE, RELOK
    CALL    PRINT
    JP      BOOT

RELOK:
    DB      CR, LF, 'READY FOR "SYSGEN" OR'
    DB      CR, LF, '"SAVE '
SAVMEM: DB      '00 CPM'
SAVM0:  DB      '00.COM"$'

TRANSFER:
    LD      DE, BOOTSIZ+BIOS
    LD      HL, (RELBAS)
    ADD     HL, DE
    JP      (HL)        ; 転送先へジャンプ

PRINT:
    LD      C, PRNT
PRJMP:
    JP      BDOS
PRHLT:  DW      0
JMPSER: JP      0       ; 実行時に書き換え

; データ領域
SER1:   DW      0
RELBAS: DW      0
MEMSG:  DB      CR, LF, 'CONSTRUCTING '
AMEM:   DB      '00'
AMSG:   DB      'k CP/M vers '
        DB      VERSION/10+'0', '.', VERSION MOD 10 +'0'
LAMSG   EQU     $-AMSG
        DB      '$'

    END
