; Lynx Z80 MAIN CPU diagnostic monitor ROM
; Console: Z80 SIO channel A

SIO_CHA_DATA_PORT   EQU     020H
SIO_CHA_CTRL_PORT   EQU     022H
MINSUB_PORT         EQU     03CH
MINSUB_DR_FULL      EQU     002H
MINSUB_SUB_BUSY     EQU     001H
STACK_TOP           EQU     0FFFEH
RAM_TEST_START      EQU     02000H
RAM_TEST_END        EQU     0DFFFH

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
        IM      1
        LD      SP,STACK_TOP
        CALL    init_sio_a
        LD      HL,banner
        CALL    puts

monitor_loop:
        LD      HL,prompt
        CALL    puts
        CALL    getch
        CP      00DH
        JR      Z,monitor_newline
        CP      00AH
        JR      Z,monitor_loop
        PUSH    AF
        CALL    crlf
        POP     AF
        CP      'R'
        JP      Z,reset
        CP      'M'
        JR      Z,cmd_ram
        CP      'S'
        JR      Z,cmd_sub
        CP      'G'
        JR      Z,cmd_gvram
        CP      '?'
        JR      Z,cmd_help
        LD      HL,unknown_msg
        CALL    puts
        JR      monitor_loop

monitor_newline:
        CALL    crlf
        JR      monitor_loop

cmd_help:
        LD      HL,help_msg
        CALL    puts
        JR      monitor_loop

cmd_ram:
        LD      HL,ram_msg
        CALL    puts
        CALL    ram_test
        LD      HL,ok_msg
        JR      NC,cmd_ram_done
        LD      HL,fail_msg
cmd_ram_done:
        CALL    puts
        JR      monitor_loop

cmd_sub:
        LD      HL,sub_msg
        CALL    puts
        LD      HL,sub_text
        CALL    sub_puts
        LD      HL,ok_msg
        CALL    puts
        JR      monitor_loop

cmd_gvram:
        LD      HL,gvram_msg
        CALL    puts
        LD      A,01BH
        CALL    sub_putc
        LD      A,'G'
        CALL    sub_putc_data
        LD      A,'T'
        CALL    sub_putc_data
        LD      HL,ok_msg
        CALL    puts
        JP      monitor_loop

init_sio_a:
        LD      A,018H
        OUT     (SIO_CHA_CTRL_PORT),A
        LD      A,004H
        OUT     (SIO_CHA_CTRL_PORT),A
        LD      A,044H
        OUT     (SIO_CHA_CTRL_PORT),A
        LD      A,003H
        OUT     (SIO_CHA_CTRL_PORT),A
        LD      A,0C1H
        OUT     (SIO_CHA_CTRL_PORT),A
        LD      A,005H
        OUT     (SIO_CHA_CTRL_PORT),A
        LD      A,068H
        OUT     (SIO_CHA_CTRL_PORT),A
        RET

getch:
        XOR     A
        OUT     (SIO_CHA_CTRL_PORT),A
getch_wait:
        IN      A,(SIO_CHA_CTRL_PORT)
        AND     001H
        JR      Z,getch_wait
        IN      A,(SIO_CHA_DATA_PORT)
        AND     07FH
        CP      'a'
        RET     C
        CP      'z'+1
        RET     NC
        AND     05FH
        RET

getch_echo:
        CALL    getch
        PUSH    AF
        CALL    putc
        POP     AF
        RET

putc:
        PUSH    AF
        XOR     A
        OUT     (SIO_CHA_CTRL_PORT),A
putc_wait:
        IN      A,(SIO_CHA_CTRL_PORT)
        AND     004H
        JR      Z,putc_wait
        POP     AF
        OUT     (SIO_CHA_DATA_PORT),A
        RET

puts:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        CALL    putc
        POP     HL
        INC     HL
        JR      puts

crlf:
        LD      A,00DH
        CALL    putc
        LD      A,00AH
        JP      putc

sub_puts:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        CALL    sub_putc
        POP     HL
        INC     HL
        JR      sub_puts

sub_putc:
        LD      B,A
sub_putc_wait:
        IN      A,(MINSUB_PORT)
        AND     MINSUB_DR_FULL+MINSUB_SUB_BUSY
        JR      NZ,sub_putc_wait
        LD      A,B
        OUT     (MINSUB_PORT),A
        RET

sub_putc_data:
        LD      B,A
sub_putc_data_wait:
        IN      A,(MINSUB_PORT)
        AND     MINSUB_DR_FULL
        JR      NZ,sub_putc_data_wait
        LD      A,B
        OUT     (MINSUB_PORT),A
        RET

ram_test:
        LD      HL,RAM_TEST_START
ram_test_55:
        LD      (HL),055H
        LD      A,(HL)
        CP      055H
        SCF
        RET     NZ
        LD      (HL),0AAH
        LD      A,(HL)
        CP      0AAH
        SCF
        RET     NZ
        INC     HL
        LD      A,H
        CP      0E0H
        JR      NZ,ram_test_55
        OR      A
        RET

banner:
        DEFB    00DH,00AH
        DEFB    "LynxZ80 MAIN DIAG MONITOR",00DH,00AH
help_msg:
        DEFB    "M RAM  S SUB MSG  G GVRAM PATTERN  R RESET  ? HELP",00DH,00AH,0
prompt:
        DEFB    "DIAG> ",0
ram_msg:
        DEFB    "MAIN RAM 2000-DFFF: ",0
sub_msg:
        DEFB    "SUBCPU LINK: ",0
gvram_msg:
        DEFB    "SUBCPU GVRAM TEST: ",0
ok_msg:
        DEFB    "OK",00DH,00AH,0
fail_msg:
        DEFB    "FAIL",00DH,00AH,0
unknown_msg:
        DEFB    "UNKNOWN COMMAND",00DH,00AH,0
sub_text:
        DEFB    "MAIN DIAG TO SUBCPU",00DH,00AH,0

        END
