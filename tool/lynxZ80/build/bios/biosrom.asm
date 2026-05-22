; Lynx Z80 CP/M bootstrap ROM
; Built with ASW: asw -cpu z80 -L biosrom.asm

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

RUNTIME_ROM_BASE    EQU     1000H
RUNTIME_RAM_BASE    EQU     2000H
RUNTIME_SIZE        EQU     1000H
BOOT_VARS_BASE      EQU     3000H

CPM_LOAD_ADDR       EQU     0DC00H
CPM_IMAGE_SIZE      EQU     5683
CPM_BOOT_ADDR       EQU     0F200H
CPM_WBOOT_ADDR      EQU     0F203H
CPM_FBASE1_ADDR     EQU     0E411H

ROM_CTRL_BOOT       EQU     088H
RUNTIME_NMI_VECTOR  EQU     RUNTIME_RAM_BASE+5
boot_track          EQU     BOOT_VARS_BASE
boot_sector         EQU     BOOT_VARS_BASE+1
payload_sector_count EQU    BOOT_VARS_BASE+2

        ORG     0000H
        JP      reset

        ORG     0008H
        JP      fail_trap

        ORG     0010H
        JP      fail_trap

        ORG     0018H
        JP      fail_trap

        ORG     0020H
        JP      fail_trap

        ORG     0028H
        JP      fail_trap

        ORG     0030H
        JP      fail_trap

        ORG     0038H
        JP      irq_handler

        ORG     0066H
        JP      nmi_handler

        ORG     0100H

reset:
        DI
        IM      1
        LD      SP,0FFFEH
        CALL    init_pio_drive_control
        LD      HL,opening_message
        CALL    print_string
        
boot_retry:
        DI
        IM      1
        LD      SP,0FFFEH
        CALL    init_pio_drive_control
        CALL    copy_runtime_bios
        CALL    load_cpm_payload
        JR      C,boot_fail
        CALL    patch_page_zero
        CALL    prime_runtime_boot
        JP      RUNTIME_RAM_BASE+2

boot_fail:
        CALL    init_sio_b
        LD      HL,boot_fail_message
        CALL    print_string
        CALL    wait_return
        JP      boot_retry

fail_trap:
        DI
        JR      fail_trap

irq_handler:
        EI
        RETI

nmi_handler:
        RETN

init_pio_drive_control:
        LD      A,00FH
        OUT     (PIO_PORT_A_CTRL),A
        OUT     (PIO_PORT_B_CTRL),A
        LD      A,ROM_CTRL_BOOT
        OUT     (PIO_PORT_B_DATA),A
        RET

init_sio_b:
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

print_string:
        LD      A,(HL)
        OR      A
        RET     Z
        PUSH    HL
        CALL    print_char
        POP     HL
        INC     HL
        JR      print_string

print_char:
        LD      B,A
print_char_wait:
        IN      A,(MINSUB_PORT)
        AND     MINSUB_DR_FULL+MINSUB_SUB_BUSY
        JR      NZ,print_char_wait
        LD      A,B
        OUT     (MINSUB_PORT),A
        RET

probe_char:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      B,A
        LD      DE,0100H
probe_char_wait:
        IN      A,(MINSUB_PORT)
        AND     MINSUB_DR_FULL+MINSUB_SUB_BUSY
        JR      Z,probe_char_send
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,probe_char_wait
        JR      probe_char_done
probe_char_send:
        LD      A,B
        OUT     (MINSUB_PORT),A
probe_char_done:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

wait_return:
        XOR     A
        OUT     (SIO_CHB_CTRL_PORT),A
wait_return_loop:
        IN      A,(SIO_CHB_CTRL_PORT)
        AND     001H
        JR      Z,wait_return_loop
        IN      A,(SIO_CHB_DATA_PORT)
        CP      00DH
        JR      NZ,wait_return
        RET

copy_runtime_bios:
        LD      HL,RUNTIME_ROM_BASE
        LD      DE,RUNTIME_RAM_BASE
        LD      BC,RUNTIME_SIZE
        LDIR
        RET

load_cpm_payload:
        CALL    compute_payload_sector_count
        LD      HL,CPM_LOAD_ADDR
        LD      DE,(payload_sector_count)
        XOR     A
        LD      (boot_track),A
        INC     A
        LD      (boot_sector),A
load_cpm_payload_loop:
        LD      A,D
        OR      E
        JR      Z,load_cpm_payload_done
        PUSH    DE
        CALL    read_sector_to_hl
        POP     DE
        RET     C
        CALL    advance_boot_sector
        DEC     DE
        JR      load_cpm_payload_loop

load_cpm_payload_done:
        OR      A
        RET

compute_payload_sector_count:
        LD      HL,0
        LD      DE,CPM_IMAGE_SIZE
compute_payload_sector_count_loop:
        LD      A,D
        OR      E
        JR      Z,compute_payload_sector_count_done
        INC     HL
        LD      A,D
        OR      A
        JR      NZ,compute_payload_sector_count_subtract
        LD      A,E
        CP      080H
        JR      C,compute_payload_sector_count_zero
compute_payload_sector_count_subtract:
        LD      A,E
        SUB     080H
        LD      E,A
        LD      A,D
        SBC     A,000H
        LD      D,A
        JR      compute_payload_sector_count_loop
compute_payload_sector_count_zero:
        XOR     A
        LD      D,A
        LD      E,A
        JR      compute_payload_sector_count_loop
compute_payload_sector_count_done:
        LD      (payload_sector_count),HL
        RET

patch_page_zero:
        LD      A,0C3H
        LD      (0000H),A
        LD      HL,CPM_WBOOT_ADDR
        LD      (0001H),HL
        LD      A,0C3H
        LD      (0005H),A
        LD      HL,CPM_FBASE1_ADDR
        LD      (0006H),HL
        LD      A,0C3H
        LD      (0066H),A
        LD      HL,RUNTIME_NMI_VECTOR
        LD      (0067H),HL
        RET

prime_runtime_boot:
        LD      HL,CPM_BOOT_ADDR
        LD      (RUNTIME_RAM_BASE),HL
        RET

advance_boot_sector:
        LD      A,(boot_sector)
        INC     A
        CP      27
        JR      C,advance_boot_sector_store
        LD      A,1
        LD      (boot_sector),A
        LD      A,(boot_track)
        INC     A
        LD      (boot_track),A
        RET
advance_boot_sector_store:
        LD      (boot_sector),A
        RET

read_sector_to_hl:
        CALL    setup_drive
        CALL    seek_boot_track
        RET     C
        LD      A,(boot_track)
        OUT     (FDC_TRK_PORT),A
        LD      A,(boot_sector)
        OUT     (FDC_SEC_PORT),A
        LD      B,128
        LD      A,088H
        OUT     (FDC_CMD_PORT),A
read_sector_byte_loop:
        CALL    wait_fdc_drq
        RET     C
        IN      A,(FDC_DATA_PORT)
        LD      (HL),A
        INC     HL
        DJNZ    read_sector_byte_loop
        CALL    wait_fdc_not_busy
        RET

setup_drive:
        LD      A,ROM_CTRL_BOOT
        OUT     (PIO_PORT_B_DATA),A
        RET

seek_boot_track:
        LD      A,(boot_track)
        OR      A
        JR      NZ,seek_boot_track_seek
        LD      A,008H
        OUT     (FDC_CMD_PORT),A
        JP      wait_fdc_not_busy

seek_boot_track_seek:
        OUT     (FDC_DATA_PORT),A
        LD      A,018H
        OUT     (FDC_CMD_PORT),A
        JP      wait_fdc_not_busy

wait_fdc_drq:
        LD      DE,0FFFFH
wait_fdc_drq_loop:
        IN      A,(FDC_CMD_PORT)
        CP      0FFH
        JR      Z,wait_fdc_drq_fail
        BIT     1,A
        JR      NZ,wait_fdc_drq_ok
        BIT     0,A
        JR      Z,wait_fdc_drq_fail
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,wait_fdc_drq_loop
wait_fdc_drq_fail:
        SCF
        RET
wait_fdc_drq_ok:
        OR      A
        RET

wait_fdc_not_busy:
        LD      DE,0FFFFH
wait_fdc_not_busy_loop:
        IN      A,(FDC_CMD_PORT)
        CP      0FFH
        JR      Z,wait_fdc_not_busy_fail
        BIT     0,A
        JR      Z,wait_fdc_not_busy_done
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,wait_fdc_not_busy_loop
wait_fdc_not_busy_fail:
        SCF
        RET
wait_fdc_not_busy_done:
        AND     098H
        JR      Z,wait_fdc_not_busy_ok
        SCF
        RET
wait_fdc_not_busy_ok:
        OR      A
        RET

opening_message:
        DEFB    'LYNX-Z80 Compatible IPL Ver. 1.1',00DH,00AH
        DEFB    'Written with Codex by yosi',00DH,00AH,0

boot_fail_message:
        DEFB    'Insert System disk to drive A:',00DH,00AH
        DEFB    'Hit RETURN key to retry',00DH,00AH,0

        ORG     1FFFH
        DEFB    0FFH
