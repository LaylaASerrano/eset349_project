	AREA    |.text|, CODE, READONLY
    export  usart_init
    export  send_input_uart
    export  recv_input_uart

usart_init PROC
    PUSH    {r0, r1, LR}        ; Save registers and LR

    ; Enable GPIOA and USART2 clocks
    LDR     r0, =0x40023830     ; RCC_AHB1ENR
    LDR     r1, [r0]            ; Read current value
    ORR     r1, r1, #0x00000001 ; Set bit0 for GPIOA
    STR     r1, [r0]            ;

    ; Enable USART2 (bit 17)
    LDR     r0, =0x40023840     ; RCC_APB1ENR
    LDR     r1, [r0]            ; Read current value
    ORR     r1, r1, #0x00020000 ; Set bit 17 for USART2
    STR     r1, [r0]            ;

    ; Set PA2/PA3 to Alternate Function mode
    LDR     r0, =0x40020000     ; GPIOA base
    LDR     r1, [r0, #0x00]     ; Read MODER
    BIC     r1, r1, #(0xF << 4) ; Clear bits for PA2 and PA3
    ORR     r1, r1, #(0xA << 4) ; Set to '10' (AF mode)
    STR     r1, [r0, #0x00]     ;

    ; Set AF7 (USART2) for PA2 and PA3
    LDR     r1, [r0, #0x20]     ; Read AFRL
    BIC     r1, r1, #0x0000FF00 ; Clear bits for PA2/PA3
    ORR     r1, r1, #0x00007700 ; Set AF7
    STR     r1, [r0, #0x20]     ;

    ; use control register (usart_cr1) for uart config bit13 = 1 bit12 = 0 bit3 = 1 bit2 = 1
    ; offset = 0x0C
    ; base register for usart2 = 0x40004400
    LDR     r0, =0x40004400     ; USART2 base address
    LDR     r1, [r0, #0x0C]     ; Read USART_CR1
    BIC     r1, r1, #(1 << 12)  ; Clear bit 12 (M0) for 8-bit word length
    ORR     r1, r1, #(1 << 13)  ; Set bit 13 (UE) to enable USART
    ORR     r1, r1, #(1 << 3)   ; Set bit 3 (TE) to enable Transmitter
    ORR     r1, r1, #(1 << 2)   ; Set bit 2 (RE) to enable Receiver
    STR     r1, [r0, #0x0C]     ;

    ; baud rate register (USART_BRR), offset = 0x08
    LDR     r1, =0x00000683     ; Set for 9600 baud rate (assuming 16MHz PCLK1)
    STR     r1, [r0, #0x08]     ; Write to USART_BRR

    POP     {r0, r1, PC}        ; Restore registers and return
	ENDP

send_input_uart PROC
    PUSH    {r0, r2, LR}        ; Save R0, R2 and LR. R1 is argument and is preserved.
wait_txe_loop
    LDR     r0, =0x40004400     ; usart2 base
    LDR     r2, [r0, #0x00]     ; Read USART_SR into r2 (r1 holds data)
    TST     r2, #0x00000080     ; Test bit 7 (TXE)
    BEQ     wait_txe_loop       ;

    STR     r1, [r0, #0x04]     ; Store the character (in R1) to USART_DR
    POP     {r0, r2, PC}        ; Restore registers and return
	ENDP

recv_input_uart PROC
    PUSH    {r1, LR}            ; Save r1 and LR
wait_rxne_loop
    LDR     r0, =0x40004400     ; USART2 base address
    LDR     r1, [r0, #0x00]     ; Read USART_SR
    TST     r1, #0x20           ; Test RXNE bit (bit 5)
    BEQ     wait_rxne_loop      ;

    LDR     r0, [r0, #0x04]     ; Read data from USART_DR into R0
    POP     {r1, PC}            ; Restore r1 and return
	ENDP

    END