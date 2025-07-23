; -------------------------------
; File: usart_init.s
; Description: UART communication via USART2 (PA2: TX, PA3: RX)
; -------------------------------

; TODO: usart_init:
;     - Enable GPIOA and USART2 clocks
;     - Set PA2/PA3 to Alternate Function mode
;     - Set AF7 for USART2 in AFRL
;     - Configure baud rate (e.g. 9600 or 115200)
;     - Enable USART2 (TE, RE, UE)

; TODO: send_input_uart:
;     - Wait until TXE (Transmit data register empty)
;     - Write data to USART2_DR

; TODO: recv_input_uart:
;     - Wait until RXNE (Receive data register not empty)
;     - Read data from USART2_DR

