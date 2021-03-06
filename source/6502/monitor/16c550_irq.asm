; 6502 BIOS 
; Based on original code by Daryl Rictor
; Adapted to 16550 UART board for RC2014
; Renamed to 16c550.asm
; Changes are copyright Ben Chong and freely licensed to the community
;
; Note: Does not require a 16C550 with autoflow control
;
; ----------------- assembly instructions ---------------------------- 
;
; this is a subroutine library only
; it must be included in an executable source file
;
;
;*** I/O Locations *******************************
; Define the i/o address of the UART chip
;*** 16C550 UART ************************

uart_base       = $c0c0
uart_reg0       = $c0c0
uart_reg1       = $c0c1
uart_reg2       = $c0c2
uart_reg3       = $c0c3
uart_reg4       = $c0c4
uart_reg5       = $c0c5
uart_reg6       = $c0c6
uart_reg7       = $c0c7
uart_xmit       = uart_reg0     ; Used by upload.asm

;
;***********************************************************************
; UART I/O Support Routines
; We'll use Daryl's routine names for compatibility with his software/code
; Otherwise, we'll use UART-agnostic nomemclature

;---------------------------------------------------------------------
;
 
ACIA1_init
uart_init
                lda     #>uart_irq
                ldx     #<uart_irq
                stx     irq_vector
                sta     irq_vector+1
                jsr     init_buffer     ; Initialize IRQ buffer
                lda     #$80            ; Line control register, Set DLAB=1
                sta     uart_reg3
                lda     #$01            ; 115200 with 1.8432MHz;  OSC / (16 * Baudrate)
                sta     uart_reg0       ; Divisor latch
                lda     #$00
                sta     uart_reg1       ; Divisor latch
                LDA     #$03            ; Line control register, 8N1, DLAB=0
                sta     uart_reg3
                LDA     #$02            ; Modem control register
                sta     uart_reg4       ; Enable RTS
                LDA     #$87            ; FIFO enable, reset RCVR/XMIT FIFO
                sta     uart_reg2

;                jsr     AFE_16C550      ; Enable auto flow control
                
                lda     #$01            ; Enable receiver interrupt
                sta     uart_reg1
                rts                     ; done
                
;---------------------------------------------------------------------
; Input char from UART (blocking)
; Exit: character in A
ACIA1_Input
uart_input
                jsr     check_buffer
                beq     uart_input
                jsr     pull_buffer
                rts                      ;

;---------------------------------------------------------------------
; Non-blocking get character routine 
; Scan for input (no wait), C=1 char, C=0 no character
ACIA1_Scan
uart_scan
                clc
                jsr     check_buffer
                beq     uart_scan2
                jsr     pull_buffer     ; Exit with C=1
uart_scan2     
                rts

;---------------------------------------------------------------------
; output to OutPut Port
; Entry: character in A
; Exit: character in A
ACIA1_Output
uart_output   
                pha                      ; save registers
uart_out1     
                lda   uart_reg5           ; serial port status
                and   #$20               ; is tx buffer empty
                beq   uart_out1         ; no
                pla                      ; get chr
                sta   uart_reg0           ; put character to Port
                rts                      ; done

;---------------------------------------------------------------------
; Enable autoflow control
AFE_16C550
                LDA     #$87                  ; Trigger level, FIFO enable, reset FIFO
                sta     uart_reg2
                ; Use this to enable autoflow control
                LDA     #$22                  ; Modem control register
                sta     uart_reg4    ; Enable AFE
                rts
                
;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS high to disable transmit from terminal
; We can use A
uart_deassert_rts
                lda     #$00
                sta     uart_reg4
                rts

;------------------------------------------------------------------------------
; This is the UART-specific call to bring RTS low to re-enable transmit

uart_assert_rts
                lda     #$02
                sta     uart_reg4
                rts

;---------------------------------------------------------------------
uart_irq
                ; Check if our interrupt
                lda      uart_reg5      ; Serial port status             
                and      #$01           ; is recvr full
                beq      ui_end         ; no char to get

                ; It's our interrupt
ui_loop
                lda      uart_reg0           ; get chr
                jsr     put_buffer
                
                lda      uart_reg5      ; Serial port status             
                and      #$01           ; is recvr full
                bne      ui_loop        ; Yes, still full
ui_end
                jmp     null_irq
                
        .include        buffer.asm

;
;end of file
