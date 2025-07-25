
; -------------------------------
; File: usart_init.s
; Description: UART communication via USART2 (PA2: TX, PA3: RX)
; -------------------------------
        AREA |.text|, CODE, READONLY
        EXPORT usart_init
        EXPORT send_input_uart
        EXPORT recv_input_uart


usart_init
        
		;Enable GPIOA and USART2 clocks
        ldr r0, =0x40023830    ; RCC_AHB1ENR
        ldr r1, [r0]            ; Read current value
        orr r1, r1, #0x00000001 ; Set bit0 for GPIOA (corrected)
        str r1, [r0]

        ;Enable USART2 (bit 17)
        ldr r0, =0x40023840        ; RCC_APB1ENR
        ; ldr r1, =0x00020000        ; set bit 17 = usart2 -- Same as above, use OR to preserve.
        ldr r1, [r0]            ; Read current value
        orr r1, r1, #0x00020000    ; Set bit 17 for USART2 (corrected)
        str r1, [r0]


        ; Set PA2/PA3 to Alternate Function mode
        ldr r0, =0x40020000        ; GPIOA base
        ldr r1, [r0, #0x00]        ; Read MODER
        bic r1, r1, #(0xF << 4)   ; Clear bits for PA2 and PA3
        orr r1, r1, #(0xA << 4)    ; Set to '10' (AF mode)
        str r1, [r0, #0x00]

        ; Set AF7 (USART2) for PA2 and PA3
        ldr r1, [r0, #0x20]        ; Read AFRL
        bic r1, r1, #0x0000FF00    ; Clear bits for PA2/PA3
        orr r1, r1, #0x00007700    ; Set AF7
        str r1, [r0, #0x20]

        ;use control registar (usart_cr1) for uart config bit13 = 1 bit12 = 0 bit3 = 1 bit2 = 1
        ;offset = 0x0C
        ; base registar for usart2 = 0x40004400
        ldr r0, =0x40004400        ; USART2 base address
        ldr r1, [r0, #0x0C]        ; Read USART_CR1
        bic r1, r1, #(1 << 12)     ; Clear bit 12 (M0) for 8-bit word length
        orr r1, r1, #(1 << 13)     ; Set bit 13 (UE) to enable USART
        orr r1, r1, #(1 << 3)      ; Set bit 3 (TE) to enable Transmitter
        orr r1, r1, #(1 << 2)      ; Set bit 2 (RE) to enable Receiver
        str r1, [r0, #0x0C]

        ; baud rate register (USART_BRR), offset = 0x08
        ; Assuming PCLK1 = 16MHz for STM32F401RE (often default for NUCLEO-F401RE)
        ; For 9600 baud rate:
        ; USARTDIV = PCLK1 / (8 * (2 - OVER8) * Baudrate)
        ; For OVER8 = 0 (default), USARTDIV = PCLK1 / (16 * Baudrate)
        ; USARTDIV = 16,000,000 / (16 * 9600) = 104.1666...
        ; Mantissa = 104 (0x68)
        ; Fraction = 16 * 0.1666 = 2.66 ~= 3 (0x3)
        ; BRR = (Mantissa << 4) | Fraction = (0x68 << 4) | 0x3 = 0x680 | 0x3 = 0x683
        ldr r1, =0x00000683        ; Set for 9600 baud rate (assuming 16MHz PCLK1)
        str r1, [r0, #0x08]        ; Write to USART_BRR

send_input_uart
        ;Wait until TXE (Transmit data register empty)
        ;Write data to USART2_DR


wait_txe 
        ldr r0, =0x40004400 ;usart2 base
		; r0 now holds the base address for USART2
        ; Need to read USART_SR (offset 0x00) and check bit 7 (TXE)
        
wait_loop
		ldr r1, [r0, #0x00]        ; Read USART_SR
        tst r1, #0x00000080        ; Test bit 7 (TXE)
        beq wait_loop              ; Loop if TXE is not set (0)

        ; At this point, TXE is set, meaning the data register is empty.
        ; The character to send is typically passed in a register, e.g., R1.
        ; For demonstration, let's assume the character is in R1.
        ; str r1, [r0, #0x04]      ; Write data to USART_DR (offset 0x04)
        ; bx lr                    ; Return after sending

        ; This section is incomplete as it expects a value to be sent.
        ; Assuming it will be called with the byte to send in R1.
        ldr r0, =0x40004400     ; USART2 base address
        ldr r2, [r0, #0x00]     ; Read USART_SR
        tst r2, #0x80           ; Check TXE bit
        beq send_input_uart     ; Loop until TXE is set

        str r1, [r0, #0x04]     ; Store the character (in R1) to USART_DR
        bx lr

recv_input_uart
; TODO: recv_input_uart:
;     - Wait until RXNE (Receive data register not empty)
;     - Read data from USART2_DR

wait_rxne
        ldr r0, =0x40004400     ; USART2 base address
        ldr r1, [r0, #0x00]     ; Read USART_SR
        tst r1, #0x20           ; Test RXNE bit (bit 5)
        beq wait_rxne           ; Loop until RXNE is set

        ldr r0, [r0, #0x04]     ; Read data from USART_DR into R0
        bx lr                   ; Return with the received character in R0

        ENDP
        END