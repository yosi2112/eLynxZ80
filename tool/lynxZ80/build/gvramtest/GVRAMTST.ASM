; Lynx-Z80 CP/M 2.2 GVRAM test for SUBCPU ROM
;
; MAIN CPU never writes the Graphic uPD7220 directly. Every GDC byte is sent
; through the SUBCPU monitor command stream:
;   ESC G C xx  -> GGDC command byte
;   ESC G P xx  -> GGDC parameter byte
; where xx is a two-digit ASCII hex byte.

BDOS            EQU     0005H
PRINT           EQU     0009H
MINSUB          EQU     03CH
MINSUB_DR_FULL  EQU     002H
MINSUB_SUB_BUSY EQU     001H

CMD_RESET       EQU     000H
CMD_START       EQU     00DH
CMD_WRITE       EQU     020H
CMD_CSRW        EQU     049H
CMD_VECTW       EQU     04CH
CMD_VECTE       EQU     06CH
CMD_TEXTW       EQU     078H
CMD_MASTER      EQU     06FH

        ORG     0100H

start:
        LD      DE,msg_head
        LD      C,PRINT
        CALL    BDOS

        CALL    init_ggdc
        CALL    fill_gvram
        CALL    draw_arcs

        LD      DE,msg_done
        LD      C,PRINT
        CALL    BDOS
        RET

init_ggdc:
        LD      A,CMD_RESET
        CALL    send_cmd_a
        LD      A,CMD_MASTER
        CALL    send_cmd_a
        LD      A,CMD_START
        JP      send_cmd_a

fill_gvram:
        LD      HL,fill_table
        LD      B,fill_count
fill_loop:
        PUSH    BC
        LD      D,(HL)
        INC     HL
        LD      E,(HL)
        INC     HL
        LD      C,(HL)
        INC     HL
        PUSH    HL

        LD      HL,linear_vector
        CALL    send_vector_hl

        LD      A,CMD_CSRW
        CALL    send_cmd_a
        LD      A,E
        CALL    send_param_a
        LD      A,D
        CALL    send_param_a
        LD      A,C
        CALL    send_param_a

        POP     HL
        LD      E,(HL)
        INC     HL
        LD      D,(HL)
        INC     HL

        LD      A,CMD_WRITE
        CALL    send_cmd_a
        LD      A,E
        CALL    send_param_a
        LD      A,D
        CALL    send_param_a

        POP     BC
        DJNZ    fill_loop
        RET

draw_arcs:
        LD      A,CMD_TEXTW
        CALL    send_cmd_a
        LD      A,0FFH
        CALL    send_param_a
        LD      A,0FFH
        CALL    send_param_a

        LD      HL,arc_table
        LD      B,arc_count
arc_loop:
        PUSH    BC

        LD      A,CMD_CSRW
        CALL    send_cmd_a
        LD      C,3
        CALL    send_params_hl_c

        LD      A,CMD_VECTW
        CALL    send_cmd_a
        LD      C,11
        CALL    send_params_hl_c

        LD      A,CMD_VECTE
        CALL    send_cmd_a
        CALL    draw_settle_delay

        POP     BC
        DJNZ    arc_loop
        RET

send_vector_hl:
        LD      A,CMD_VECTW
        CALL    send_cmd_a
        LD      C,11
        JP      send_params_hl_c

send_params_hl_c:
        LD      A,C
        OR      A
        RET     Z
send_params_loop:
        LD      A,(HL)
        CALL    send_param_a
        INC     HL
        DEC     C
        JR      NZ,send_params_loop
        RET

send_cmd_a:
        LD      B,'C'
        JP      send_proxy_a

send_param_a:
        LD      B,'P'

send_proxy_a:
        LD      E,A
        LD      A,01BH
        CALL    put_direct
        LD      A,'G'
        CALL    put_direct
        LD      A,B
        CALL    put_direct
        LD      A,E
        RRCA
        RRCA
        RRCA
        RRCA
        AND     00FH
        CALL    put_hex_nibble
        LD      A,E
        AND     00FH
        JP      put_hex_nibble

put_hex_nibble:
        CP      00AH
        JR      C,put_hex_digit
        ADD     A,'A'-10
        JP      put_direct
put_hex_digit:
        ADD     A,'0'
        JP      put_direct

put_direct:
        PUSH    AF
wait_sub:
        IN      A,(MINSUB)
        AND     MINSUB_DR_FULL+MINSUB_SUB_BUSY
        JR      NZ,wait_sub
        POP     AF
        OUT     (MINSUB),A
        RET

draw_settle_delay:
        PUSH    BC
        LD      BC,0400H
draw_settle_loop:
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,draw_settle_loop
        POP     BC
        RET

msg_head:
        DEFB    0DH,0AH
        DEFB    'LYNX-Z80 SUBCPU GVRAM TEST',0DH,0AH
        DEFB    'Sending Graphic 7220 command stream via MINSUB.',0DH,0AH
        DEFB    0DH,0AH,'$'
msg_done:
        DEFB    0DH,0AH
        DEFB    'SUBCPU command stream sent. Check the GVRAM pattern.',0DH,0AH
        DEFB    'Returning to CP/M.',0DH,0AH,'$'

linear_vector:
        DEFB    002H,07FH,03EH,008H,000H,008H,000H,000H,000H,000H,000H

fill_count      EQU     3
fill_table:
        ; Stored as EAD high, EAD low, EAD bit16/DAD, write low, write high.
        ; CSRW is sent in uPD7220 order: low, high, third byte.
        DEFB    000H,000H,000H,0AAH,055H
        DEFB    080H,000H,000H,033H,0CCH
        DEFB    000H,000H,001H,00FH,0F0H

arc_count       EQU     8
arc_table:
        ; 3 CSRW bytes, then 11 VECTW bytes.
        DEFB    094H,025H,000H
        DEFB    021H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    0C7H,02CH,0A0H
        DEFB    020H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    099H,03EH,000H
        DEFB    027H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    0B7H,050H,090H
        DEFB    026H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    094H,057H,000H
        DEFB    025H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    0B0H,050H,070H
        DEFB    024H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    08FH,03EH,000H
        DEFB    023H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H

        DEFB    070H,02CH,070H
        DEFB    022H,038H,000H,050H,000H,000H,000H,000H,000H,000H,000H
