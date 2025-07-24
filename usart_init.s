
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
        mov r1, #0x00000001    ;set bit0 = gpioA 
        str r1, [r0]

        ;Enable USART2 (bit 17)
        ldr r0, =0x40023840        ; RCC_APB1ENR
        ldr r1, =0x00020000        ; set bit 17 = usart2
        str r1, [r0]

        ;Set PA2/PA3 to Alternate Function mode
        ;ldr r0, =0x40020000     ;gpioA_MODER
        ;mov r1, #0x000000A0     ;set pa2 = 10 and pa3 = 10
        ;str r1, [r0, #0x00]

        ; Set PA2/PA3 to Alternate Function mode
        ldr r0, =0x40020000        ; GPIOA base
        ldr r1, [r0, #0x00]        ; Read MODER
        bic r1, r1, #(0xF << 4)   ; Clear bits for PA2 and PA3
        orr r1, r1, #(0xA << 4)    ; Set to '10' (AF mode)
        str r1, [r0, #0x00]

        ;Set AF7 for USART2 in AFRL
        ;ldr r1, =0x00007700
        ;str r1, [r0, #0x20]

        ; Set AF7 (USART2) for PA2 and PA3
        ldr r1, [r0, #0x20]        ; Read AFRL
        bic r1, r1, #0x0000FF00    ; Clear bits for PA2/PA3
        orr r1, r1, #0x00007700    ; Set AF7
        str r1, [r0, #0x20]

        ;use control registar (usart_cr1) for uart config bit13 = 1 bit12 = 0 bit3 = 1 bit2 = 1
        ;offset = 0x0C
        ; base registar for usart2 = 0x40004400
        ldr r0, =0x40004400
        ldr r1, [r0, #0x0C]. ; read cr1
        ; clear bits 13,12,3,2 
        ; set 13,3,2 to 1 and clear bit 12 
        ;write to memory 

        ;clear bits 0-15
        ;bit 0-3 for fraction 
        ;bit 4-15 for mantissa 
        ;figure out baudrate write number to max = 5.25  
        ;use  baud rate registar (uart_brr) figure out how to do that with the website found
        ;offset = 0x08
        
;status register = usart_sr
;offset = 0x00
;bit 7 = txe -> tranmit data register empty
;bit 6 = tc -> transmission complete
;bit 5 = rxne -> read data registar not empty
send_input_uart
        ;Wait until TXE (Transmit data register empty)
        ;Write data to USART2_DR


wait_txe 
        ldr r0, =0x40004400 ;usart2 base
        
wait_loop


recv_input_uart
; TODO: recv_input_uart:
;     - Wait until RXNE (Receive data register not empty)
;     - Read data from USART2_DR