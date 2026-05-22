; Lynx Z80 sub CPU bootstrap ROM
; Built with ASW: asw -cpu z80 -L subcpurom.asm

CGDC_PARAM_PORT      EQU     000H
CGDC_CMD_PORT        EQU     001H
GGDC_PARAM_PORT      EQU     002H
GGDC_CMD_PORT        EQU     003H
MINSUB_PORT          EQU     080H
STACK_TOP            EQU     087FFH
CURSOR_ADDR          EQU     08000H
CURSOR_COL           EQU     08002H
CHAR_LATCH           EQU     08003H
SUB_CMD_STATE        EQU     08004H
GFX_LO               EQU     08005H
GFX_HI               EQU     08006H
SUB_CMD_OP          EQU     08007H
SUB_HEX             EQU     08008H
SCROLL_BASE         EQU     08009H
ANSI_PARAM0         EQU     0800BH
ANSI_PARAM1         EQU     0800CH
ANSI_PARAM_INDEX    EQU     0800DH
CURRENT_ATTR        EQU     0800EH
SAVED_CURSOR_ADDR   EQU     0800FH
SAVED_CURSOR_COL    EQU     08011H
ROW_STRIDE           EQU     050H
TEXT_LIMIT           EQU     07D0H
TVRAM_CELLS          EQU     0800H
LAST_ROW_ADDR        EQU     0780H
ATTR_WHITE           EQU     007H

CMD_RESET            EQU     000H
CMD_START            EQU     00DH
CMD_SYNC_ON          EQU     00FH
CMD_WRITE            EQU     020H
CMD_PITCH            EQU     047H
CMD_CSRW             EQU     049H
CMD_MASK             EQU     04AH
CMD_CSRFORM          EQU     04BH
CMD_VECTW            EQU     04CH
CMD_MASTER           EQU     06FH
CMD_SCROLL           EQU     070H
GDC_VECTOR_BYTES     EQU     00BH
GFX_VISIBLE_WORDS    EQU     03E80H

        ORG     0000H
        JP      reset

        ORG     0008H
        JP      trap

        ORG     0010H
        JP      trap

        ORG     0018H
        JP      trap

        ORG     0020H
        JP      trap

        ORG     0028H
        JP      trap

        ORG     0030H
        JP      trap

        ORG     0038H
        JP      irq_handler

        ORG     0066H
        JP      nmi_handler

        ORG     0100H

reset:
        DI
        LD      SP,STACK_TOP
        LD      A,001H
        OUT     (MINSUB_PORT),A
        XOR     A
        LD      (CURSOR_COL),A
        LD      (SUB_CMD_STATE),A
        LD      A,ATTR_WHITE
        LD      (CURRENT_ATTR),A
        XOR     A
        LD      HL,0000H
        LD      (SCROLL_BASE),HL
        LD      HL,0000H
        LD      (CURSOR_ADDR),HL
        CALL    init_chr_gdc
        CALL    init_gfx_gdc
        CALL    gdc_settle_delay
        CALL    prime_chr_gdc
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
        CALL    update_cursor_gdc
        XOR     A
        OUT     (MINSUB_PORT),A
        JR      idle_loop

trap:
        DI
        JR      trap

irq_handler:
        EI
        RETI

nmi_handler:
        RETN

init_chr_gdc:
        CALL    cgdc_reset
        LD      A,CMD_MASTER
        CALL    cgdc_command
        LD      HL,0000H
        LD      (SCROLL_BASE),HL
        CALL    set_chr_scroll
        CALL    init_chr_cursor
        LD      A,CMD_START
        CALL    cgdc_command
        RET

init_chr_cursor:
        LD      A,CMD_CSRFORM
        CALL    cgdc_command
        LD      A,08FH
        CALL    cgdc_param
        LD      A,02EH
        CALL    cgdc_param
        LD      A,078H
        CALL    cgdc_param
        JP      update_cursor_gdc

init_gfx_gdc:
        CALL    ggdc_reset
        LD      A,CMD_MASTER
        CALL    ggdc_command
        LD      A,CMD_START
        CALL    ggdc_command
        RET

cgdc_reset:
        XOR     A
cgdc_command:
        OUT     (CGDC_CMD_PORT),A
        RET

cgdc_param:
        OUT     (CGDC_PARAM_PORT),A
        RET

ggdc_reset:
        XOR     A
ggdc_command:
        OUT     (GGDC_CMD_PORT),A
        RET

ggdc_param:
        OUT     (GGDC_PARAM_PORT),A
        RET

gdc_settle_delay:
        LD      BC,0400H
gdc_settle_delay_loop:
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,gdc_settle_delay_loop
        RET

prime_chr_gdc:
        LD      A,' '
        LD      (CHAR_LATCH),A
        LD      HL,0000H
        CALL    write_char_a
        RET

write_string_at:
        LD      (CURSOR_ADDR),DE
        XOR     A
        LD      (CURSOR_COL),A
write_string_at_loop:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        CALL    handle_char
        POP     HL
        INC     HL
        JR      write_string_at_loop

handle_char:
        LD      B,A
        LD      A,(SUB_CMD_STATE)
        OR      A
        JR      NZ,handle_sub_command
        LD      A,B
        CP      01BH
        JR      Z,handle_escape
        CP      00DH
        JP      Z,handle_cr
        CP      00AH
        JP      Z,handle_lf
        CP      008H
        JP      Z,handle_bs
        CP      009H
        JP      Z,handle_tab
        CP      020H
        RET     C
        LD      (CHAR_LATCH),A
        LD      HL,(CURSOR_ADDR)
        CALL    write_char_a
        CALL    advance_cursor
        RET

handle_escape:
        LD      A,1
        LD      (SUB_CMD_STATE),A
        RET

handle_sub_command:
        CP      1
        JR      Z,handle_sub_command_group
        CP      2
        JR      Z,handle_sub_command_op
        CP      3
        JR      Z,handle_sub_command_hex_hi
        CP      4
        JR      Z,handle_sub_command_hex_lo
        CP      5
        JP      Z,handle_ansi_char
        XOR     A
        LD      (SUB_CMD_STATE),A
        LD      A,B
        JP      handle_char

handle_sub_command_group:
        LD      A,B
        CP      'G'
        JR      Z,handle_sub_command_graphic
        CP      '['
        JR      Z,handle_ansi_start
        CP      '7'
        JP      Z,ansi_save_cursor_direct
        CP      '8'
        JP      Z,ansi_restore_cursor_direct
        CP      'M'
        JP      Z,ansi_reverse_index_direct
        JR      handle_sub_command_cancel
handle_sub_command_graphic:
        LD      A,2
        LD      (SUB_CMD_STATE),A
        RET

handle_ansi_start:
        XOR     A
        LD      (ANSI_PARAM0),A
        LD      (ANSI_PARAM1),A
        LD      (ANSI_PARAM_INDEX),A
        LD      A,5
        LD      (SUB_CMD_STATE),A
        RET

handle_sub_command_op:
        LD      A,B
        CP      'C'
        JR      Z,handle_sub_command_cmd
        CP      'P'
        JR      Z,handle_sub_command_param
        CP      'T'
        JP      Z,run_gvram_test
        JR      handle_sub_command_cancel

handle_sub_command_cmd:
        LD      A,1
        LD      (SUB_CMD_OP),A
        LD      A,3
        LD      (SUB_CMD_STATE),A
        RET

handle_sub_command_param:
        LD      A,2
        LD      (SUB_CMD_OP),A
        LD      A,3
        LD      (SUB_CMD_STATE),A
        RET

handle_sub_command_hex_hi:
        LD      A,B
        CALL    hex_to_nibble
        JR      C,handle_sub_command_cancel
        RLCA
        RLCA
        RLCA
        RLCA
        LD      (SUB_HEX),A
        LD      A,4
        LD      (SUB_CMD_STATE),A
        RET

handle_sub_command_hex_lo:
        LD      A,B
        CALL    hex_to_nibble
        JR      C,handle_sub_command_cancel
        LD      B,A
        LD      A,(SUB_HEX)
        OR      B
        LD      B,A
        XOR     A
        LD      (SUB_CMD_STATE),A
        LD      A,(SUB_CMD_OP)
        CP      1
        JR      Z,handle_sub_command_emit_cmd
        CP      2
        JR      Z,handle_sub_command_emit_param
        RET

handle_sub_command_emit_cmd:
        LD      A,B
        OUT     (GGDC_CMD_PORT),A
        RET

handle_sub_command_emit_param:
        LD      A,B
        OUT     (GGDC_PARAM_PORT),A
        RET

handle_sub_command_cancel:
        XOR     A
        LD      (SUB_CMD_STATE),A
        RET

hex_to_nibble:
        CP      '0'
        JR      C,hex_bad
        CP      '9'+1
        JR      C,hex_digit
        CP      'A'
        JR      C,hex_bad
        CP      'F'+1
        JR      C,hex_upper
        CP      'a'
        JR      C,hex_bad
        CP      'f'+1
        JR      NC,hex_bad
        SUB     'a'-10
        OR      A
        RET
hex_upper:
        SUB     'A'-10
        OR      A
        RET
hex_digit:
        SUB     '0'
        OR      A
        RET
hex_bad:
        SCF
        RET

handle_ansi_char:
        LD      A,B
        CP      '?'
        RET     Z
        CP      '0'
        JR      C,handle_ansi_final
        CP      '9'+1
        JR      C,handle_ansi_digit
        CP      ';'
        JR      Z,handle_ansi_semicolon
        JR      handle_ansi_final

handle_ansi_digit:
        SUB     '0'
        LD      C,A
        LD      A,(ANSI_PARAM_INDEX)
        OR      A
        JR      NZ,handle_ansi_digit_p1
        LD      A,(ANSI_PARAM0)
        CALL    mul10_add_c
        LD      (ANSI_PARAM0),A
        RET
handle_ansi_digit_p1:
        LD      A,(ANSI_PARAM1)
        CALL    mul10_add_c
        LD      (ANSI_PARAM1),A
        RET

handle_ansi_semicolon:
        LD      A,1
        LD      (ANSI_PARAM_INDEX),A
        RET

handle_ansi_final:
        XOR     A
        LD      (SUB_CMD_STATE),A
        LD      A,B
        CP      'H'
        JP      Z,ansi_cursor_position
        CP      'f'
        JP      Z,ansi_cursor_position
        CP      'J'
        JP      Z,ansi_erase_display
        CP      'K'
        JP      Z,ansi_erase_line
        CP      'm'
        JP      Z,ansi_sgr
        CP      'A'
        JP      Z,ansi_cursor_up
        CP      'B'
        JP      Z,ansi_cursor_down
        CP      'C'
        JP      Z,ansi_cursor_right
        CP      'D'
        JP      Z,ansi_cursor_left
        CP      'E'
        JP      Z,ansi_cursor_next_line
        CP      'F'
        JP      Z,ansi_cursor_prev_line
        CP      'G'
        JP      Z,ansi_cursor_column
        CP      's'
        JP      Z,ansi_save_cursor
        CP      'u'
        JP      Z,ansi_restore_cursor
        RET

mul10_add_c:
        LD      E,A
        ADD     A,A
        ADD     A,A
        ADD     A,E
        ADD     A,A
        ADD     A,C
        RET

ansi_cursor_position:
        LD      A,(ANSI_PARAM0)
        OR      A
        JR      NZ,ansi_cup_row_set
        INC     A
ansi_cup_row_set:
        DEC     A
        CP      25
        JR      C,ansi_cup_row_ok
        LD      A,24
ansi_cup_row_ok:
        LD      B,A
        LD      A,(ANSI_PARAM1)
        OR      A
        JR      NZ,ansi_cup_col_set
        INC     A
ansi_cup_col_set:
        DEC     A
        CP      ROW_STRIDE
        JR      C,ansi_cup_col_ok
        LD      A,ROW_STRIDE-1
ansi_cup_col_ok:
        LD      C,A
        LD      HL,(SCROLL_BASE)
        LD      A,B
        OR      A
        JR      Z,ansi_cup_add_col
ansi_cup_row_loop:
        LD      DE,ROW_STRIDE
        ADD     HL,DE
        CALL    wrap_hl_tvr
        DJNZ    ansi_cup_row_loop
ansi_cup_add_col:
        LD      E,C
        LD      D,0
        ADD     HL,DE
        CALL    wrap_hl_tvr
        LD      (CURSOR_ADDR),HL
        LD      A,C
        LD      (CURSOR_COL),A
        RET

ansi_erase_display:
        LD      A,(ANSI_PARAM0)
        CP      1
        JP      Z,clear_to_screen_start
        CP      2
        JP      Z,clear_visible_screen
        CP      3
        JP      Z,clear_visible_screen
        JP      clear_to_screen_end

ansi_erase_line:
        LD      A,(ANSI_PARAM0)
        CP      1
        JP      Z,clear_from_line_start
        CP      2
        JP      Z,clear_entire_line
        JP      clear_to_eol

ansi_sgr:
        LD      A,(ANSI_PARAM0)
        CALL    ansi_sgr_param
        LD      A,(ANSI_PARAM_INDEX)
        OR      A
        RET     Z
        LD      A,(ANSI_PARAM1)
        CALL    ansi_sgr_param
        RET

ansi_sgr_param:
        CP      0
        JR      Z,ansi_sgr_reset
        CP      5
        JR      Z,ansi_sgr_blink_on
        CP      7
        JR      Z,ansi_sgr_inverse_on
        CP      8
        JR      Z,ansi_sgr_hidden_on
        CP      10
        JR      Z,ansi_sgr_font0
        CP      11
        JR      Z,ansi_sgr_font1
        CP      25
        JR      Z,ansi_sgr_blink_off
        CP      27
        JR      Z,ansi_sgr_inverse_off
        CP      28
        JR      Z,ansi_sgr_hidden_off
        CP      30
        RET     C
        CP      38
        JR      C,ansi_sgr_fg_color
        CP      39
        JR      Z,ansi_sgr_fg_default
        RET
ansi_sgr_reset:
        LD      A,ATTR_WHITE
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_fg_color:
        SUB     30
        LD      B,A
        LD      A,(CURRENT_ATTR)
        AND     0F8H
        OR      B
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_fg_default:
        LD      A,(CURRENT_ATTR)
        AND     0F8H
        OR      ATTR_WHITE
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_blink_on:
        LD      A,(CURRENT_ATTR)
        OR      080H
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_blink_off:
        LD      A,(CURRENT_ATTR)
        AND     07FH
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_inverse_on:
        LD      A,(CURRENT_ATTR)
        OR      008H
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_inverse_off:
        LD      A,(CURRENT_ATTR)
        AND     0F7H
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_hidden_on:
        LD      A,(CURRENT_ATTR)
        OR      040H
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_hidden_off:
        LD      A,(CURRENT_ATTR)
        AND     0BFH
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_font0:
        LD      A,(CURRENT_ATTR)
        AND     0EFH
        LD      (CURRENT_ATTR),A
        RET
ansi_sgr_font1:
        LD      A,(CURRENT_ATTR)
        OR      010H
        LD      (CURRENT_ATTR),A
        RET

ansi_get_count:
        LD      A,(ANSI_PARAM0)
        OR      A
        RET     NZ
        INC     A
        RET

ansi_cursor_right:
        CALL    ansi_get_count
        LD      B,A
ansi_cursor_right_loop:
        LD      A,(CURSOR_COL)
        CP      ROW_STRIDE-1
        RET     NC
        INC     A
        LD      (CURSOR_COL),A
        LD      HL,(CURSOR_ADDR)
        INC     HL
        CALL    wrap_hl_tvr
        LD      (CURSOR_ADDR),HL
        DJNZ    ansi_cursor_right_loop
        RET

ansi_cursor_left:
        CALL    ansi_get_count
        LD      B,A
ansi_cursor_left_loop:
        LD      A,(CURSOR_COL)
        OR      A
        RET     Z
        DEC     A
        LD      (CURSOR_COL),A
        LD      HL,(CURSOR_ADDR)
        CALL    dec_hl_tvr
        LD      (CURSOR_ADDR),HL
        DJNZ    ansi_cursor_left_loop
        RET

ansi_cursor_up:
        CALL    ansi_get_count
        LD      B,A
ansi_cursor_up_loop:
        CALL    cursor_relative
        LD      DE,ROW_STRIDE
        OR      A
        SBC     HL,DE
        RET     C
        LD      HL,(CURSOR_ADDR)
        OR      A
        SBC     HL,DE
        JR      NC,ansi_cursor_up_store
        LD      DE,TVRAM_CELLS
        ADD     HL,DE
ansi_cursor_up_store:
        LD      (CURSOR_ADDR),HL
        DJNZ    ansi_cursor_up_loop
        RET

ansi_cursor_down:
        CALL    ansi_get_count
        LD      B,A
ansi_cursor_down_loop:
        CALL    cursor_relative
        LD      DE,LAST_ROW_ADDR
        OR      A
        SBC     HL,DE
        RET     NC
        LD      HL,(CURSOR_ADDR)
        LD      DE,ROW_STRIDE
        ADD     HL,DE
        CALL    wrap_hl_tvr
        LD      (CURSOR_ADDR),HL
        DJNZ    ansi_cursor_down_loop
        RET

ansi_cursor_next_line:
        CALL    ansi_get_count
        LD      B,A
        CALL    handle_cr
ansi_cursor_next_line_loop:
        PUSH    BC
        CALL    handle_lf
        POP     BC
        DJNZ    ansi_cursor_next_line_loop
        RET

ansi_cursor_prev_line:
        CALL    ansi_get_count
        LD      B,A
        CALL    handle_cr
        JP      ansi_cursor_up_loop

ansi_cursor_column:
        LD      A,(ANSI_PARAM0)
        OR      A
        JR      NZ,ansi_column_have
        INC     A
ansi_column_have:
        DEC     A
        CP      ROW_STRIDE
        JR      C,ansi_column_ok
        LD      A,ROW_STRIDE-1
ansi_column_ok:
        LD      C,A
        CALL    cursor_line_start
        LD      E,C
        LD      D,0
        ADD     HL,DE
        CALL    wrap_hl_tvr
        LD      (CURSOR_ADDR),HL
        LD      A,C
        LD      (CURSOR_COL),A
        RET

ansi_save_cursor_direct:
        XOR     A
        LD      (SUB_CMD_STATE),A
ansi_save_cursor:
        LD      HL,(CURSOR_ADDR)
        LD      (SAVED_CURSOR_ADDR),HL
        LD      A,(CURSOR_COL)
        LD      (SAVED_CURSOR_COL),A
        RET

ansi_restore_cursor_direct:
        XOR     A
        LD      (SUB_CMD_STATE),A
ansi_restore_cursor:
        LD      HL,(SAVED_CURSOR_ADDR)
        LD      (CURSOR_ADDR),HL
        LD      A,(SAVED_CURSOR_COL)
        LD      (CURSOR_COL),A
        RET

ansi_reverse_index_direct:
        XOR     A
        LD      (SUB_CMD_STATE),A
        LD      A,1
        LD      (ANSI_PARAM0),A
        JP      ansi_cursor_up

handle_cr:
        LD      A,(CURSOR_COL)
        LD      E,A
        LD      D,0
        LD      HL,(CURSOR_ADDR)
        OR      A
        SBC     HL,DE
        JR      NC,handle_cr_addr_ok
        LD      DE,TVRAM_CELLS
        ADD     HL,DE
handle_cr_addr_ok:
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
        CALL    dec_hl_tvr
        LD      (CURSOR_ADDR),HL
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        RET

handle_tab:
        LD      A,(CURSOR_COL)
        AND     007H
        LD      B,A
        LD      A,008H
        SUB     B
        LD      B,A
handle_tab_loop:
        LD      A,' '
        LD      (CHAR_LATCH),A
        LD      HL,(CURSOR_ADDR)
        CALL    write_char_a
        CALL    advance_cursor
        DJNZ    handle_tab_loop
        RET

write_char_a:
        CALL    cgdc_set_csr_hl
        LD      A,CMD_WRITE
        CALL    cgdc_command
        LD      A,(CHAR_LATCH)
        CALL    cgdc_param
        LD      A,(CURRENT_ATTR)
        CALL    cgdc_param
        RET

cgdc_set_csr_hl:
        LD      A,CMD_CSRW
        CALL    cgdc_command
        LD      A,L
        CALL    cgdc_param
        LD      A,H
        CALL    cgdc_param
        XOR     A
        CALL    cgdc_param
        RET

update_cursor_gdc:
        LD      HL,(CURSOR_ADDR)
        JP      cgdc_set_csr_hl

run_gvram_test:
        CALL    init_gfx_gdc

        LD      D,000H
        LD      HL,00000H
        CALL    gfx_set_linear_vector
        CALL    gfx_set_csr
        LD      A,0AAH
        LD      (GFX_LO),A
        LD      A,055H
        LD      (GFX_HI),A
        CALL    gfx_write_fill

        LD      D,000H
        LD      HL,08000H
        CALL    gfx_set_linear_vector
        CALL    gfx_set_csr
        LD      A,033H
        LD      (GFX_LO),A
        LD      A,0CCH
        LD      (GFX_HI),A
        CALL    gfx_write_fill

        LD      D,001H
        LD      HL,00000H
        CALL    gfx_set_linear_vector
        CALL    gfx_set_csr
        LD      A,00FH
        LD      (GFX_LO),A
        LD      A,0F0H
        LD      (GFX_HI),A
        CALL    gfx_write_fill
        RET

gfx_set_linear_vector:
        PUSH    HL
        LD      A,CMD_VECTW
        CALL    ggdc_command
        LD      HL,gfx_linear_vector
        LD      B,GDC_VECTOR_BYTES
gfx_set_linear_vector_loop:
        LD      A,(HL)
        CALL    ggdc_param
        INC     HL
        DJNZ    gfx_set_linear_vector_loop
        POP     HL
        RET

gfx_set_csr:
        LD      A,CMD_CSRW
        CALL    ggdc_command
        LD      A,L
        CALL    ggdc_param
        LD      A,H
        CALL    ggdc_param
        LD      A,D
        CALL    ggdc_param
        RET

gfx_write_fill:
        LD      A,CMD_WRITE
        CALL    ggdc_command
        LD      A,(GFX_LO)
        CALL    ggdc_param
        LD      A,(GFX_HI)
        CALL    ggdc_param
        RET

advance_cursor:
        LD      HL,(CURSOR_ADDR)
        INC     HL
        LD      (CURSOR_ADDR),HL
        LD      A,(CURSOR_COL)
        INC     A
        CP      ROW_STRIDE
        JR      C,advance_cursor_store
        XOR     A
advance_cursor_store:
        LD      (CURSOR_COL),A
        CALL    normalize_cursor
        RET

normalize_cursor:
        LD      DE,TVRAM_CELLS
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,normalize_cursor_check_visible
        OR      A
        SBC     HL,DE
normalize_cursor_check_visible:
        PUSH    HL
        LD      DE,(SCROLL_BASE)
        OR      A
        SBC     HL,DE
        JR      NC,normalize_cursor_have_rel
        LD      DE,TVRAM_CELLS
        ADD     HL,DE
normalize_cursor_have_rel:
        LD      DE,TEXT_LIMIT
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,normalize_cursor_store
        CALL    scroll_one_line
normalize_cursor_store:
        LD      (CURSOR_ADDR),HL
        RET

scroll_one_line:
        PUSH    HL
        LD      HL,(SCROLL_BASE)
        LD      DE,ROW_STRIDE
        ADD     HL,DE
        LD      DE,TVRAM_CELLS
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,scroll_one_line_base_ok
        OR      A
        SBC     HL,DE
scroll_one_line_base_ok:
        LD      (SCROLL_BASE),HL
        CALL    set_chr_scroll
        LD      DE,LAST_ROW_ADDR
        ADD     HL,DE
        LD      DE,TVRAM_CELLS
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,scroll_one_line_cursor_ok
        OR      A
        SBC     HL,DE
scroll_one_line_cursor_ok:
        LD      (CURSOR_ADDR),HL
        CALL    clear_current_line
        POP     HL
        LD      HL,(CURSOR_ADDR)
        RET

set_chr_scroll:
        PUSH    HL
        LD      A,CMD_SCROLL
        CALL    cgdc_command
        LD      A,L
        CALL    cgdc_param
        LD      A,H
        CALL    cgdc_param
        XOR     A
        CALL    cgdc_param
        LD      A,01EH
        CALL    cgdc_param
        POP     HL
        RET

clear_current_line:
        PUSH    HL
        PUSH    BC
        LD      B,ROW_STRIDE
clear_current_line_loop:
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        INC     HL
        CALL    wrap_hl_tvr
        DJNZ    clear_current_line_loop
        POP     BC
        POP     HL
        RET

cursor_home:
        LD      HL,(SCROLL_BASE)
        LD      (CURSOR_ADDR),HL
        XOR     A
        LD      (CURSOR_COL),A
        RET

clear_to_eol:
        PUSH    HL
        PUSH    BC
        LD      HL,(CURSOR_ADDR)
        LD      A,(CURSOR_COL)
        LD      C,A
        LD      A,ROW_STRIDE
        SUB     C
        LD      B,A
clear_to_eol_loop:
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        INC     HL
        CALL    wrap_hl_tvr
        DJNZ    clear_to_eol_loop
        POP     BC
        POP     HL
        RET

clear_from_line_start:
        PUSH    HL
        PUSH    BC
        LD      A,(CURSOR_COL)
        INC     A
        LD      B,A
        CALL    cursor_line_start
clear_from_line_start_loop:
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        INC     HL
        CALL    wrap_hl_tvr
        DJNZ    clear_from_line_start_loop
        POP     BC
        POP     HL
        RET

clear_entire_line:
        PUSH    HL
        PUSH    BC
        CALL    cursor_line_start
        LD      B,ROW_STRIDE
clear_entire_line_loop:
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        INC     HL
        CALL    wrap_hl_tvr
        DJNZ    clear_entire_line_loop
        POP     BC
        POP     HL
        RET

clear_visible_screen:
        PUSH    HL
        PUSH    BC
        LD      HL,(SCROLL_BASE)
        LD      C,25
clear_visible_screen_row:
        LD      B,ROW_STRIDE
clear_visible_screen_col:
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        INC     HL
        CALL    wrap_hl_tvr
        DJNZ    clear_visible_screen_col
        DEC     C
        JR      NZ,clear_visible_screen_row
        POP     BC
        POP     HL
        RET

clear_to_screen_end:
        PUSH    HL
        PUSH    BC
        CALL    cursor_relative
        LD      DE,TEXT_LIMIT
        EX      DE,HL
        OR      A
        SBC     HL,DE
        LD      B,H
        LD      C,L
        LD      HL,(CURSOR_ADDR)
        CALL    clear_chars_bc_from_hl
        POP     BC
        POP     HL
        RET

clear_to_screen_start:
        PUSH    HL
        PUSH    BC
        CALL    cursor_relative
        INC     HL
        LD      B,H
        LD      C,L
        LD      HL,(SCROLL_BASE)
        CALL    clear_chars_bc_from_hl
        POP     BC
        POP     HL
        RET

clear_chars_bc_from_hl:
        LD      A,B
        OR      C
        RET     Z
clear_chars_bc_from_hl_loop:
        LD      A,' '
        LD      (CHAR_LATCH),A
        CALL    write_char_a
        INC     HL
        CALL    wrap_hl_tvr
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,clear_chars_bc_from_hl_loop
        RET

cursor_relative:
        LD      HL,(CURSOR_ADDR)
        LD      DE,(SCROLL_BASE)
        OR      A
        SBC     HL,DE
        RET     NC
        LD      DE,TVRAM_CELLS
        ADD     HL,DE
        RET

cursor_line_start:
        LD      A,(CURSOR_COL)
        LD      E,A
        LD      D,0
        LD      HL,(CURSOR_ADDR)
        OR      A
        SBC     HL,DE
        RET     NC
        LD      DE,TVRAM_CELLS
        ADD     HL,DE
        RET

wrap_hl_tvr:
        PUSH    DE
        LD      DE,TVRAM_CELLS
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,wrap_hl_tvr_done
        OR      A
        SBC     HL,DE
wrap_hl_tvr_done:
        POP     DE
        RET

dec_hl_tvr:
        LD      A,H
        OR      L
        JR      NZ,dec_hl_tvr_normal
        LD      HL,TVRAM_CELLS-1
        RET
dec_hl_tvr_normal:
        DEC     HL
        RET

gfx_linear_vector:
        DEFB    002H,07FH,03EH,008H,000H,008H,000H,000H,000H,000H,000H

        ORG     1FFFH
        DEFB    0FFH
