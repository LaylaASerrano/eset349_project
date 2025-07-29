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
    LDR     r1, =0x0000008B     ; Set for 9600 baud rate (assuming 16MHz PCLK1)
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
; -----------------------------------------------------------------------------
; send_string_uart: Sends a null-terminated string via UART.
; R0 = Address of the string to send.
; -----------------------------------------------------------------------------
send_string_uart PROC
    PUSH    {r1, LR}            ; Save r1 and LR
send_string_loop
    LDRB    r1, [r0]            ; Load byte from string
    CMP     r1, #0              ; Check for null terminator
    BEQ     send_string_done    ; If null, string sent

    BL      send_input_uart     ; Send the character using existing routine (R1 is data)
    ADD     r0, r0, #1          ; Increment string pointer
    B       send_string_loop
send_string_done
    POP     {r1, PC}            ; Restore r1 and return
    ENDP

; -----------------------------------------------------------------------------
; uart_read_line: Reads characters into uart_rx_buffer until '\n' or timeout.
; Uses uart_rx_buffer, uart_rx_index, uart_rx_ready.
; R0 = timeout in ms
; Returns: R0 = 1 if line received, 0 on timeout.
;          uart_rx_buffer contains the line, uart_rx_index is reset to 0.
; -----------------------------------------------------------------------------
uart_read_line PROC
    PUSH    {r1, r2, r3, r4, r5, r6, LR} ; Save used registers

    MOV     R6, R0              ; R6 = timeout in ms
    MOV     R5, #0              ; R5 = bytes_received counter

    ; Get start time for timeout
    LDR     r1, =g_ms_ticks     ; Global millisecond tick counter
    LDR     r2, [r1]            ; R2 = current_ticks
    ADD     R2, R2, R6          ; R2 = target_ticks (current + timeout)

    LDR     r3, =uart_rx_buffer ; R3 = buffer address
    LDR     r4, =uart_rx_index  ; R4 = index address

    ; Clear the buffer index and ready flag for a new read
    MOV     r0, #0
    STR     r0, [r4]            ; uart_rx_index = 0
    LDR     r0, =uart_rx_ready
    STR     r0, [r0]            ; uart_rx_ready = 0

read_line_loop
    ; Check for timeout
    LDR     r1, =g_ms_ticks
    LDR     r0, [r1]            ; Get current ticks
    CMP     r0, R2              ; Compare with target_ticks
    BGE     read_line_timeout   ; If current_ticks >= target_ticks, timeout

    ; Check if data is available (polling RXNE)
    LDR     r0, =0x40004400     ; USART2 base address
    LDR     r1, [r0, #0x00]     ; Read USART_SR
    TST     r1, #0x20           ; Test RXNE bit (bit 5)
    BEQ     read_line_loop      ; No data, continue looping

    ; Data available, read it
    LDR     r0, [r0, #0x04]     ; Read data from USART_DR into R0 (char)

    ; Store in buffer
    LDR     r5, [r4]            ; R5 = current uart_rx_index
    CMP     r5, #255            ; Check for buffer overflow (max 255 chars + null)
    BGE     read_line_buffer_full ; If buffer full, stop

    STRB    r0, [r3, r5]        ; Store byte into buffer[uart_rx_index]
    ADD     r5, r5, #1          ; Increment uart_rx_index
    STR     r5, [r4]            ; Store updated index

    CMP     r0, #0x0A           ; Check if it's Line Feed (0x0A)
    BEQ     read_line_success   ; If yes, line received

    B       read_line_loop      ; Continue reading

read_line_buffer_full
    ; Null-terminate and set ready flag, but consider it a failure for full line read
    LDR     r1, =uart_rx_ready
    MOV     r0, #1
    STR     r0, [r1]            ; Set uart_rx_ready
    LDR     r1, [r4]            ; Get current index
    MOV     r0, #0              ; Null terminator
    STRB    r0, [r3, r1]        ; Store null at end of buffer
    MOV     R0, #0              ; Return 0 (failure)
    B       read_line_exit

read_line_timeout
    LDR     r1, =uart_rx_ready
    MOV     r0, #0
    STR     r0, [r1]            ; Ensure ready flag is clear
    MOV     R0, #0              ; Return 0 (failure)
    B       read_line_exit

read_line_success
    ; Null-terminate the buffer
    LDR     r1, [r4]            ; Get current uart_rx_index
    MOV     r0, #0              ; Null terminator
    STRB    r0, [r3, r1]        ; Store null at end of string

    LDR     r1, =uart_rx_ready
    MOV     r0, #1
    STR     r0, [r1]            ; Set uart_rx_ready flag
    MOV     R0, #1              ; Return 1 (success)

read_line_exit
    POP     {r1, r2, r3, r4, r5, r6, PC} ; Restore registers and return
    ENDP

; -----------------------------------------------------------------------------
; str_contains: Checks if a substring (needle) is present in a string (haystack).
; R0 = Address of haystack (larger string, e.g., uart_rx_buffer)
; R1 = Address of needle (substring to search for, e.g., "OK")
; Returns: R0 = 1 if needle found, 0 if not found.
; -----------------------------------------------------------------------------
str_contains PROC
    PUSH    {r4-r7, LR}
    MOV     R4, R0              ; R4 = Haystack pointer
    MOV     R5, R1              ; R5 = Needle pointer

outer_loop_str_contains
    LDRB    R6, [R4]            ; Get char from haystack
    CMP     R6, #0              ; End of haystack?
    BEQ     not_found_str_contains ; If yes, needle not found

    MOV     R0, R4              ; Store current haystack position (for inner loop)
    MOV     R1, R5              ; Store start of needle (for inner loop)

inner_loop_str_contains
    LDRB    R2, [R0]            ; Get char from haystack (inner)
    LDRB    R3, [R1]            ; Get char from needle

    CMP     R3, #0              ; End of needle?
    BEQ     found_str_contains  ; If yes, needle found

    CMP     R2, R3              ; Characters match?
    BNE     mismatch_str_contains ; If no, move to next haystack char in outer loop

    ADD     R0, R0, #1          ; Next char in haystack (inner)
    ADD     R1, R1, #1          ; Next char in needle
    B       inner_loop_str_contains

mismatch_str_contains
    ADD     R4, R4, #1          ; Next char in haystack (outer)
    B       outer_loop_str_contains

found_str_contains
    MOV     R0, #1              ; Return 1 (found)
    B       exit_str_contains

not_found_str_contains
    MOV     R0, #0              ; Return 0 (not found)

exit_str_contains
    POP     {r4-r7, PC}
    ENDP

; -----------------------------------------------------------------------------
; send_at_command: Sends an AT command and waits for an expected response.
; R0 = Address of AT command string (e.g., CMD_AT)
; R1 = Address of expected response string (e.g., RESP_OK)
; R2 = Timeout in ms
; Returns: R0 = 1 on success (expected response received), 0 on timeout/error.
; -----------------------------------------------------------------------------
send_at_command PROC
    PUSH    {r4-r7, LR}
    MOV     R4, R0              ; R4 = command address
    MOV     R5, R1              ; R5 = expected response address
    MOV     R6, R2              ; R6 = timeout_ms

    ; Send the command string
    MOV     R0, R4              ; R0 points to command string
    BL      send_string_uart    ; Send the AT command

    ; Wait for response
    MOV     R0, R6              ; Pass timeout to uart_read_line
    BL      uart_read_line      ; Read response into uart_rx_buffer
    CMP     R0, #1              ; Check if uart_read_line successfully read a line
    BNE     command_fail_at     ; If not 1, means timeout or buffer full

    ; Check if received line contains the expected response
    LDR     R0, =uart_rx_buffer ; Haystack (received data)
    MOV     R1, R5              ; Needle (expected response)
    BL      str_contains
    CMP     R0, #1              ; Was the needle found?
    BEQ     command_success_at  ; If yes, command succeeded

command_fail_at
    MOV     R0, #0              ; Return 0 (fail)
    B       exit_send_at_command

command_success_at
    MOV     R0, #1              ; Return 1 (success)

exit_send_at_command
    POP     {r4-r7, PC}
    ENDP

wait_rxne_loop
    LDR     r0, =0x40004400     ; USART2 base address
    LDR     r1, [r0, #0x00]     ; Read USART_SR
    TST     r1, #0x20           ; Test RXNE bit (bit 5)
    BEQ     wait_rxne_loop      ;

    LDR     r0, [r0, #0x04]     ; Read data from USART_DR into R0
    POP     {r1, PC}            ; Restore r1 and return
	ENDP

    ; --- Global Variables for UART Reception ---
    AREA    |.bss_usart|, NOINIT, READWRITE

uart_rx_buffer      SPACE   256             ; Buffer for received UART data (256 bytes)
uart_rx_index       DCD     0               ; Current write index for uart_rx_buffer
uart_rx_ready       DCD     0               ; Flag: 1 when a full line (ending with \n) is received

    ALIGN

    ; --- Constants for AT Commands and Expected Responses ---
    AREA    |.data_usart|, DATA, READONLY

; AT Commands (include CR+LF for termination)
CMD_AT              DCB     "AT", 0x0D, 0x0A, 0 ; AT\r\n
CMD_AT_RST          DCB     "AT+RST", 0x0D, 0x0A, 0 ; AT+RST\r\n
CMD_AT_CWMODE1      DCB     "AT+CWMODE=1", 0x0D, 0x0A, 0 ; AT+CWMODE=1\r\n
; Note: AT+CWJAP is complex to build dynamically in assembly.
; For initial testing, you might hardcode it or build with string concatenation if implemented.
; Example hardcoded for testing:
CMD_AT_CWJAP_TEST   DCB     "AT+CWJAP=\"YourSSID\",\"YourPassword\"\r\n", 0 ; Replace with your actual SSID/Password !!!!!!!!!!!!!!!
CMD_AT_CIFSR        DCB     "AT+CIFSR", 0x0D, 0x0A, 0 ; Get IP address

; Expected Responses
RESP_OK             DCB     "OK", 0x0D, 0x0A, 0
RESP_ERROR          DCB     "ERROR", 0x0D, 0x0A, 0
RESP_WIFI_GOT_IP    DCB     "WIFI GOT IP", 0x0D, 0x0A, 0
RESP_CONNECT        DCB     "CONNECT", 0x0D, 0x0A, 0
RESP_SEND_OK        DCB     "SEND OK", 0x0D, 0x0A, 0

    ALIGN



    END