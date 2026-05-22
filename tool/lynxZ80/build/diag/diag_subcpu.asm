; Lynx Z80 SUB CPU diagnostic monitor ROM
; Controlled by MAIN CPU over MINSUB; MAIN console is SIO-A.

CGDC_PARAM_PORT      EQU     000H
CGDC_CMD_PORT        EQU     001H
GGDC_PARAM_PORT      EQU     002H
GGDC_CMD_PORT        EQU     003H
MINSUB_PORT          EQU     080H
STACK_TOP            EQU     087FFH
CURSOR_ADDR          EQU     08000H
CURSOR_COL           EQU     08002H
CHAR_LATCH           EQU     08003H
GFX_LO               EQU     08004H
GFX_HI               EQU     08005H
ROW_STRIDE           EQU     050H
TEXT_LIMIT           EQU     07D0H

CMD_RESET            EQU     000H
CMD_SYNC_ON          EQU     00FH
CMD_MASTER           EQU     06FH
CMD_START            EQU     00DH
CMD_CSRW             EQU     049H
CMD_WRITE            EQU     020H
CMD_VECTW            EQU     04CH
GDC_VECTOR_BYTES     EQU     00BH

        ORG     0000H
        JP      reset

        ORG     0038H
        EI
        RETI

        ORG     0066H
        RETN

        ORG     0100H

reset:
        DI
        LD      SP,STACK_TOP
        LD      A,001H
        OUT     (MINSUB_PORT),A
        XOR     A
        LD      (CURSOR_COL),A
        LD      HL,0000H
        LD      (CURSOR_ADDR),HL
        CALL    init_chr_gdc
        CALL    init_gfx_gdc
        CALL    settle_delay
        CALL    prime_chr_gdc
        CALL    draw_banner
        XOR     A
        OUT     (MINSUB_PORT),A

idle_loop:
        IN      A,(MINSUB_PORT)
        OR      A
        JR      Z,idle_loop
        PUSH    AF
        LD      A,001H
        OUT     (MINSUB_PORT),A
        POP     AF
        CALL    handle_char
        XOR     A
        OUT     (MINSUB_PORT),A
        JR      idle_loop

init_chr_gdc:
        XOR     A
        OUT     (CGDC_CMD_PORT),A
        LD      A,CMD_MASTER
        OUT     (CGDC_CMD_PORT),A
        LD      A,CMD_START
        OUT     (CGDC_CMD_PORT),A
        RET

init_gfx_gdc:
        XOR     A
        OUT     (GGDC_CMD_PORT),A
        LD      A,CMD_MASTER
        OUT     (GGDC_CMD_PORT),A
        LD      A,CMD_SYNC_ON
        OUT     (GGDC_CMD_PORT),A
        LD      HL,gfx_sync_params
        LD      B,008H
init_gfx_sync_loop:
        LD      A,(HL)
        OUT     (GGDC_PARAM_PORT),A
        INC     HL
        DJNZ    init_gfx_sync_loop
        LD      A,CMD_START
        OUT     (GGDC_CMD_PORT),A
        RET

settle_delay:
        LD      BC,0400H
settle_delay_loop:
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,settle_delay_loop
        RET

prime_chr_gdc:
        LD      A,' '
        LD      (CHAR_LATCH),A
        LD      HL,0000H
        CALL    write_char_at_hl
        RET

draw_banner:
        LD      HL,banner0
        LD      DE,0000H
        CALL    write_string_at
        LD      HL,banner1
        LD      DE,0050H
        CALL    write_string_at
        LD      HL,00A0H
        LD      (CURSOR_ADDR),HL
        XOR     A
        LD      (CURSOR_COL),A
        RET

write_string_at:
        LD      A,(HL)
        OR      A
        RET     Z
        LD      (CHAR_LATCH),A
        PUSH    HL
        LD      H,D
        LD      L,E
        CALL    write_char_at_hl
        POP     HL
        INC     HL
        INC     DE
        JR      write_string_at

handle_char:
        CP      01BH
        JR      Z,handle_esc
        CP      00DH
        JR      Z,handle_cr
        CP      00AH
        JR      Z,handle_lf
        CP      008H
        JR      Z,handle_bs
        CP      020H
        RET     C
        LD      (CHAR_LATCH),A
        LD      HL,(CURSOR_ADDR)
        CALL    write_char_at_hl
        CALL    advance_cursor
        RET

handle_esc:
        CALL    minsub_getc
        CP      'G'
        RET     NZ
        CALL    minsub_getc
        CP      'T'
        RET     NZ
        JP      gvram_test_pattern

minsub_getc:
        IN      A,(MINSUB_PORT)
        OR      A
        JR      Z,minsub_getc
        RET

handle_cr:
        LD      A,(CURSOR_COL)
        LD      E,A
        LD      D,0
        LD      HL,(CURSOR_ADDR)
        OR      A
        SBC     HL,DE
        XOR     A
        LD      (CURSOR_COL),A
        LD      (CURSOR_ADDR),HL
        RET

handle_lf:
        LD      HL,(CURSOR_ADDR)
        LD      DE,ROW_STRIDE
        ADD     HL,DE
        CALL    normalize_cursor
        RET

handle_bs:
        LD      A,(CURSOR_COL)
        OR      A
        RET     Z
        DEC     A
        LD      (CURSOR_COL),A
        LD      HL,(CURSOR_ADDR)
        DEC     HL
        LD      (CURSOR_ADDR),HL
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_at_hl
        RET

write_char_at_hl:
        LD      A,CMD_CSRW
        OUT     (CGDC_CMD_PORT),A
        LD      A,L
        OUT     (CGDC_PARAM_PORT),A
        LD      A,H
        OUT     (CGDC_PARAM_PORT),A
        XOR     A
        OUT     (CGDC_PARAM_PORT),A
        LD      A,CMD_WRITE
        OUT     (CGDC_CMD_PORT),A
        LD      A,(CHAR_LATCH)
        OUT     (CGDC_PARAM_PORT),A
        LD      A,007H
        OUT     (CGDC_PARAM_PORT),A
        RET

advance_cursor:
        LD      HL,(CURSOR_ADDR)
        INC     HL
        LD      (CURSOR_ADDR),HL
        LD      A,(CURSOR_COL)
        INC     A
        CP      080
        JR      C,advance_store
        XOR     A
        LD      (CURSOR_COL),A
        LD      HL,(CURSOR_ADDR)
        LD      DE,ROW_STRIDE-080
        ADD     HL,DE
        LD      (CURSOR_ADDR),HL
        CALL    normalize_cursor
        RET
advance_store:
        LD      (CURSOR_COL),A
        CALL    normalize_cursor
        RET

normalize_cursor:
        LD      HL,(CURSOR_ADDR)
        LD      DE,TEXT_LIMIT
        OR      A
        SBC     HL,DE
        RET     C
        LD      HL,0000H
        LD      (CURSOR_ADDR),HL
        XOR     A
        LD      (CURSOR_COL),A
        RET

gvram_test_pattern:
        CALL    init_gfx_gdc

        LD      D,000H
        LD      HL,00000H
        CALL    gfx_set_linear_vector
        CALL    gfx_set_csr
        LD      A,0AAH
        LD      (GFX_LO),A
        LD      A,055H
        LD      (GFX_HI),A
        CALL    gfx_write_word

        LD      D,000H
        LD      HL,08000H
        CALL    gfx_set_linear_vector
        CALL    gfx_set_csr
        LD      A,033H
        LD      (GFX_LO),A
        LD      A,0CCH
        LD      (GFX_HI),A
        CALL    gfx_write_word

        LD      D,001H
        LD      HL,00000H
        CALL    gfx_set_linear_vector
        CALL    gfx_set_csr
        LD      A,00FH
        LD      (GFX_LO),A
        LD      A,0F0H
        LD      (GFX_HI),A
        CALL    gfx_write_word
        RET

gfx_set_linear_vector:
        PUSH    HL
        LD      A,CMD_VECTW
        OUT     (GGDC_CMD_PORT),A
        LD      HL,gfx_linear_vector
        LD      B,GDC_VECTOR_BYTES
gfx_set_linear_vector_loop:
        LD      A,(HL)
        OUT     (GGDC_PARAM_PORT),A
        INC     HL
        DJNZ    gfx_set_linear_vector_loop
        POP     HL
        RET

gfx_set_csr:
        LD      A,CMD_CSRW
        OUT     (GGDC_CMD_PORT),A
        LD      A,L
        OUT     (GGDC_PARAM_PORT),A
        LD      A,H
        OUT     (GGDC_PARAM_PORT),A
        LD      A,D
        OUT     (GGDC_PARAM_PORT),A
        RET

gfx_write_word:
        LD      A,CMD_WRITE
        OUT     (GGDC_CMD_PORT),A
        LD      A,(GFX_LO)
        OUT     (GGDC_PARAM_PORT),A
        LD      A,(GFX_HI)
        OUT     (GGDC_PARAM_PORT),A
        RET

gfx_sync_params:
        DEFB    000H,000H,000H,000H,000H,000H,090H,001H

gfx_linear_vector:
        DEFB    002H,07FH,03EH,008H,000H,008H,000H,000H,000H,000H,000H

banner0:
        DEFB    "LynxZ80 SUBCPU DIAG",0
banner1:
        DEFB    "MINSUB READY - CONTROL VIA SIO-A",0

        END
