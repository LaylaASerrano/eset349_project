    AREA    |.text|, CODE, READONLY
    export  Reset_Handler
    export  main_loop

    ; --- Existing Imports ---
	import	gpio_init
	import  game_init
	import  i2c_init
	import  lcd_init
	import  usart_init
	import  delay_init
	import 	read_buttons
	import	game_update
	import	lcd_render
	import  delay_ms

    ; --- New/Existing Imports for ESP8266 Communication ---
    import  send_input_uart     ; Used to send raw bytes to ESP8266
    import  recv_input_uart     ; Used to receive raw bytes from ESP8266
    import  send_string_uart    ; Used to send AT commands (strings) to ESP8266
    import  uart_read_line      ; Used to read lines (responses) from ESP8266
    import  str_contains        ; Used to parse ESP8266 responses
    import  send_at_command     ; High-level function for AT commands

    ; --- Imports for global variables (from game_logic.s) ---
    IMPORT  paddle1_y           ; Player 1's paddle Y (remote, received via Wi-Fi)
    IMPORT  paddle2_y           ; Player 2's paddle Y (local, controlled by buttons)

    ; --- Imports for AT command constants (from usart_init.s) ---
    import  CMD_AT
    import  CMD_AT_RST
    import  CMD_AT_CWMODE1
    import  CMD_AT_CWJAP_TEST   ; For connecting to AP
    import  CMD_AT_CIFSR        ; For getting local IP (useful for debugging, not strictly needed for client)

    import  RESP_OK
    import  RESP_ERROR
    import  RESP_WIFI_GOT_IP
    import  RESP_CONNECT        ; Expected response for TCP connection
    import  RESP_SEND_OK        ; Expected response after CIPSEND data
    import  RESP_CLOSED         ; Connection closed

    ; --- Global Variables for Wi-Fi Communication ---
    ; These are internal to main.s for now, but could be in a .bss section if needed elsewhere
    ; For simplicity, we'll use immediate values where possible or pass via registers.

    ; --- Constants for TCP Client Connection (Player 2) ---
    ; !!! IMPORTANT: REPLACE THESE WITH YOUR ACTUAL VALUES !!!
    PLAYER1_SERVER_IP_STR   DCB "YOUR_PLAYER1_IP",0 ; e.g., "192.168.1.100",0
    PLAYER_GAME_PORT_STR    DCB "8080",0       ; e.g., "8080",0
    TCP_LINK_ID             EQU 0                   ; Link ID for TCP connection (usually 0 for single connection)

    ; --- Constants for paddle movement boundaries ---
    MAX_PADDLE_Y_POS EQU 2      ; Max Y position for the top of a 2-pixel paddle on a 4-line LCD (0-3)

; -----------------------------------------------------------------------------
; Reset_Handler: Entry point after reset. Initializes peripherals and ESP8266.
; -----------------------------------------------------------------------------
Reset_Handler PROC
    PUSH    {LR}                ; Save LR for proper function context

    ; Initialize all necessary peripherals
    BL      gpio_init           ; Initialize GPIO for buttons and UART
    BL      game_init           ; Initialize ball and paddle positions
    BL      i2c_init            ; Initialize I2C for LCD
    BL      lcd_init            ; Initialize LCD module
    BL      usart_init          ; Initialize USART for communication with ESP8266
    BL      delay_init          ; Initialize SysTick for delays

    BL      esp8266_setup       ; Call routine to initialize and connect ESP8266

    POP     {PC}                ; Restore LR and return to caller (which will be the main_loop branch)
    B       main_loop           ; Go to the main game loop
ENDP

; -----------------------------------------------------------------------------
; esp8266_setup: Initializes the ESP8266 module with AT commands.
; Configures as Wi-Fi station and connects to Player 1's TCP server.
; Displays status on LCD and traps on error.
; -----------------------------------------------------------------------------
esp8266_setup PROC
    PUSH    {r0-r7, LR}         ; Save registers

    ; Display "ESP INIT" on LCD
    MOV     R0, #0x80           ; Line 0
    BL      lcd_send_cmd
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #'S'
    BL      lcd_send_data
    MOV     R0, #'P'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data
    MOV     R0, #'I'
    BL      lcd_send_data
    MOV     R0, #'N'
    BL      lcd_send_data
    MOV     R0, #'I'
    BL      lcd_send_data
    MOV     R0, #'T'
    BL      lcd_send_data
    MOV     R0, #500            ; Short delay
    BL      delay_ms

    ; --- 1. Test AT command (Check if ESP is responsive) ---
    MOV     R0, #CMD_AT         ; Command: "AT\r\n"
    MOV     R1, #RESP_OK        ; Expected response: "OK\r\n"
    MOV     R2, #1000           ; Timeout: 1000ms
    BL      send_at_command
    CMP     R0, #1
    BEQ     L_at_ok
    B       L_esp_error        ; Trap on failure
L_at_ok
    MOV     R0, #0xC0           ; Line 1
    BL      lcd_send_cmd
    MOV     R0, #'A'
    BL      lcd_send_data
    MOV     R0, #'T'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data
    MOV     R0, #'O'
    BL      lcd_send_data
    MOV     R0, #'K'
    BL      lcd_send_data
    MOV     R0, #100            ; Short delay after OK
    BL      delay_ms

    ; --- 2. Reset ESP8266 ---
    MOV     R0, #CMD_AT_RST     ; Command: "AT+RST\r\n"
    MOV     R1, #RESP_OK        ; Expected response: "OK\r\n"
    MOV     R2, #2000           ; Timeout: 2000ms (reset takes time)
    BL      send_at_command
    CMP     R0, #1
    BEQ     L_rst_ok
    B       L_esp_error
L_rst_ok
    MOV     R0, #0x94           ; Line 2
    BL      lcd_send_cmd
    MOV     R0, #'R'
    BL      lcd_send_data
    MOV     R0, #'S'
    BL      lcd_send_data
    MOV     R0, #'T'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data
    MOV     R0, #'O'
    BL      lcd_send_data
    MOV     R0, #'K'
    BL      lcd_send_data
    MOV     R0, #3000           ; Long delay for ESP to reboot and be ready
    BL      delay_ms
    ; After reset, the ESP might send "WIFI GOT IP" or "ready" unsolicited.
    ; For simplicity, we just delay for now.

    ; --- 3. Set Wi-Fi Mode to Station (Client) ---
    MOV     R0, #CMD_AT_CWMODE1 ; Command: "AT+CWMODE=1\r\n"
    MOV     R1, #RESP_OK        ; Expected response: "OK\r\n"
    MOV     R2, #1000           ; Timeout: 1000ms
    BL      send_at_command
    CMP     R0, #1
    BEQ     L_cwmode_ok
    B       L_esp_error
L_cwmode_ok
    MOV     R0, #0xD4           ; Line 3
    BL      lcd_send_cmd
    MOV     R0, #'M'
    BL      lcd_send_data
    MOV     R0, #'O'
    BL      lcd_send_data
    MOV     R0, #'D'
    BL      lcd_send_data
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data
    MOV     R0, #'O'
    BL      lcd_send_data
    MOV     R0, #'K'
    BL      lcd_send_data
    MOV     R0, #100            ; Short delay
    BL      delay_ms

    ; --- 4. Connect to Wi-Fi Access Point (Using hardcoded test string) ---
    ; This uses CMD_AT_CWJAP_TEST defined in usart_init.s (e.g., "AT+CWJAP=\"SSID\",\"Password\"\r\n")
    MOV     R0, #CMD_AT_CWJAP_TEST ; Command
    MOV     R1, #RESP_OK           ; Expected response: "OK\r\n"
    MOV     R2, #10000             ; Longer timeout (10 seconds) for connection
    BL      send_at_command
    CMP     R0, #1
    BEQ     L_cwjap_ok
    B       L_esp_error
L_cwjap_ok
    MOV     R0, #0x80           ; Back to line 0 for next message
    BL      lcd_send_cmd
    MOV     R0, #'W'
    BL      lcd_send_data
    MOV     R0, #'I'
    BL      lcd_send_data
    MOV     R0, #'F'
    BL      lcd_send_data
    MOV     R0, #'I'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data
    MOV     R0, #'C'
    BL      lcd_send_data
    MOV     R0, #'O'
    BL      lcd_send_data
    MOV     R0, #'N'
    BL      lcd_send_data
    MOV     R0, #'N'
    BL      lcd_send_data
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #'C'
    BL      lcd_send_data
    MOV     R0, #'T'
    BL      lcd_send_data
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #'D'
    BL      lcd_send_data
    MOV     R0, #500
    BL      delay_ms

    ; --- 5. Connect to Player 1's TCP Server (This board is the Client) ---
    ; Format: AT+CIPSTART="TCP","<Player1_IP>",<port>\r\n
    ; We need to build this string dynamically or use a pre-defined one.
    ; For simplicity, we'll use a hardcoded string here.
    ; This requires a new constant in usart_init.s or defined here.
    ; Let's assume usart_init.s will have CMD_AT_CIPSTART_P1

    ; Build AT+CIPSTART command string:
    ; "AT+CIPSTART=\"TCP\",\"" + PLAYER1_SERVER_IP_STR + "\"," + PLAYER_GAME_PORT_STR + "\r\n"
    ; This is complex in pure assembly. A simpler approach is to use a pre-formatted string.
    ; Let's define a new constant for this specific command.
    ; For now, we'll assume a new constant `CMD_AT_CIPSTART_P1` exists in usart_init.s
    ; and you have correctly set PLAYER1_SERVER_IP_STR and PLAYER_GAME_PORT_STR above.

    ; !!! IMPORTANT: You NEED to create CMD_AT_CIPSTART_P1 in usart_init.s like this:
    ; CMD_AT_CIPSTART_P1 DCB "AT+CIPSTART=\"TCP\",\"YOUR_PLAYER1_IP\",\"YOUR_PORT\"\r\n",0
    ; And ensure YOUR_PLAYER1_IP and YOUR_PORT match your setup.

    MOV     R0, #CMD_AT_CIPSTART_P1 ; Command to connect to Player 1's server
    MOV     R1, #RESP_CONNECT       ; Expected response: "CONNECT\r\n" or "OK\r\n"
    MOV     R2, #5000               ; Timeout: 5 seconds for connection
    BL      send_at_command
    CMP     R0, #1
    BEQ     L_tcp_connect_ok
    B       L_esp_error
L_tcp_connect_ok
    MOV     R0, #0xC0           ; Line 1
    BL      lcd_send_cmd
    MOV     R0, #'C'
    BL      lcd_send_data
    MOV     R0, #'O'
    BL      lcd_send_data
    MOV     R0, #'N'
    BL      lcd_send_data
    MOV     R0, #'N'
    BL      lcd_send_data
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #'C'
    BL      lcd_send_data
    MOV     R0, #'T'
    BL      lcd_send_data
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #'D'
    BL      lcd_send_data
    MOV     R0, #500
    BL      delay_ms

    B       L_esp_setup_done   ; Jump to end if all goes well

L_esp_error
    ; Clear LCD and display "ESP ERR"
    MOV     r0, #0x01           ; Clear display command
    BL      lcd_send_cmd
    MOV     r0, #2              ; Delay for clear
    BL      delay_ms

    MOV     R0, #0x80           ; Line 0
    BL      lcd_send_cmd
    MOV     r0, #'E'
    BL      lcd_send_data
    MOV     r0, #'S'
    BL      lcd_send_data
    MOV     r0, #'P'
    BL      lcd_send_data
    MOV     r0, #' '
    BL      lcd_send_data
    MOV     r0, #'E'
    BL      lcd_send_data
    MOV     r0, #'R'
    BL      lcd_send_data
    MOV     r0, #'R'
    BL      lcd_send_data
L_error_trap
    B       L_error_trap       ; Infinite loop on error

L_esp_setup_done
    POP     {r0-r7, PC}         ; Restore registers and return
    ENDP

; -----------------------------------------------------------------------------
; send_paddle_wifi: Sends a paddle position (0-3) over Wi-Fi.
; R0 = paddle_y (0-3)
; Returns R0 = 1 on success, 0 on failure.
; -----------------------------------------------------------------------------
send_paddle_wifi PROC
    PUSH    {r1-r7, LR}         ; Save registers
    MOV     r4, r0              ; Save original paddle_y (0-3) in r4

    ; Convert paddle_y (0-3) to ASCII character ('0'-'3')
    ADD     r5, r4, #'0'        ; r5 = ASCII char

    ; Construct AT+CIPSEND command: AT+CIPSEND=<link_id>,<length>\r\n
    ; Length will always be 1 for a single character.
    ; Using a temporary buffer to build the string.
    ; This is a simplified approach. A more robust way would be to dynamically
    ; build the string or use a dedicated string building function.

    ; For simplicity, we'll send the AT+CIPSEND command directly, then the data.
    ; This assumes a single TCP connection (link ID 0).
    ; Command: "AT+CIPSEND=0,1\r\n"
    ; !!! IMPORTANT: You NEED to create CMD_AT_CIPSEND_0_1 in usart_init.s like this:
    ; CMD_AT_CIPSEND_0_1 DCB "AT+CIPSEND=0,1\r\n",0

    MOV     R0, #CMD_AT_CIPSEND_0_1 ; Command string for CIPSEND
    MOV     R1, #'>'                ; Expected response: '>' prompt
    MOV     R2, #500                ; Timeout for prompt
    BL      send_at_command         ; Send CIPSEND command
    CMP     R0, #1                  ; Check if '>' prompt was received
    BEQ     L_send_data_prompt_ok
    MOV     R0, #0                  ; Return 0 (failure)
    B       L_send_paddle_wifi_done

L_send_data_prompt_ok
    ; Send the actual paddle data character
    MOV     R1, r5                  ; Move ASCII paddle char to R1 for send_input_uart
    BL      send_input_uart         ; Send the single character data

    ; Wait for "SEND OK" response
    MOV     R0, #RESP_SEND_OK       ; Expected response: "SEND OK\r\n"
    MOV     R1, #RESP_OK            ; send_at_command expects a second response for success
    MOV     R2, #1000               ; Timeout for SEND OK
    BL      send_at_command         ; This call will read until SEND OK or timeout
    CMP     R0, #1                  ; Check if SEND OK was received
    BEQ     L_send_paddle_wifi_success
    MOV     R0, #0                  ; Return 0 (failure)
    B       L_send_paddle_wifi_done

L_send_paddle_wifi_success
    MOV     R0, #1                  ; Return 1 (success)

L_send_paddle_wifi_done
    POP     {r1-r7, PC}         ; Restore registers and return
ENDP

; -----------------------------------------------------------------------------
; receive_paddle_wifi: Receives paddle position from Wi-Fi.
; Returns R0 = paddle_y (0-3) on success, or -1 (0xFFFFFFFF) if no data/error.
; This function will poll for incoming data (+IPD) and parse it.
; -----------------------------------------------------------------------------
receive_paddle_wifi PROC
    PUSH    {r1-r7, LR}         ; Save registers
    MOV     r0, #0xFFFFFFFF     ; Default return value: -1 (error/no data)

L_recv_loop
    ; Try to read a line from UART with a short timeout
    MOV     r1, #100            ; Short timeout (e.g., 100ms) for uart_read_line
    BL      uart_read_line      ; Read into uart_rx_buffer. R0 = 1 if line read, 0 if timeout.
    CMP     r0, #0              ; Check if a line was successfully read
    BEQ     L_recv_loop_end     ; If timeout, exit loop

    ; Check if the received line contains "+IPD" (Incoming Data)
    LDR     r0, =uart_rx_buffer ; Load address of received buffer
    MOV     r1, #'+'            ; Search for '+'
    MOV     r2, #'I'            ; Search for 'I'
    MOV     r3, #'P'            ; Search for 'P'
    MOV     r4, #'D'            ; Search for 'D'
    ; This is a simplified check. A proper str_contains for "+IPD," is better.
    ; Assuming str_contains takes (haystack_addr, needle_addr)
    ; We need a specific needle string for "+IPD,"

    ; !!! IMPORTANT: You NEED to create RESP_IPD_PREFIX in usart_init.s like this:
    ; RESP_IPD_PREFIX DCB "+IPD,",0

    LDR     r1, =RESP_IPD_PREFIX ; Load address of "+IPD," string
    MOV     r0, =uart_rx_buffer  ; Haystack is the received buffer
    BL      str_contains         ; Check if "+IPD," is in the buffer
    CMP     r0, #1               ; If str_contains returns 1 (found)
    BEQ     L_ipd_found          ; Process the IPD message

    ; If not +IPD, it might be another unsolicited message, ignore and try again
    B       L_recv_loop         ; Loop to read next line

L_ipd_found
    ; Found "+IPD,". Now parse the data.
    ; The format is typically: +IPD,<link_id>,<len>:<data>
    ; We need to find the ':' and then take the character after it.
    ; This is complex in assembly. For simplicity, we'll assume the data is
    ; the first character after "+IPD,<link_id>,<len>:"
    ; A more robust parser would find the second comma, then the colon, then read the byte.

    ; Let's assume the paddle data is the last character in the buffer before \r\n
    ; Or, more reliably, a fixed offset from the start of "+IPD," if the length is known.
    ; For now, let's try to find the last character before \r\n.
    ; This requires knowing the length of the received line. uart_read_line doesn't return length.
    ; A simpler (but less robust) approach for a single char:
    ; Assume the paddle data is at a fixed offset after "+IPD,0,1:"
    ; This means we need to search for ":", then take the next character.

    ; Find the colon ':' in uart_rx_buffer
    MOV     r6, #0              ; Index for scanning buffer
    LDR     r7, =uart_rx_buffer ; Base address of buffer

L_find_colon_loop
    LDRB    r0, [r7, r6]        ; Load byte at current index
    CMP     r0, #':'            ; Check if it's a colon
    BEQ     L_colon_found       ; If found, proceed
    CMP     r0, #0              ; Check for null terminator
    BEQ     L_recv_loop_end     ; If end of string, colon not found, exit
    ADD     r6, r6, #1          ; Increment index
    B       L_find_colon_loop   ; Continue search

L_colon_found
    ADD     r6, r6, #1          ; Move index past the colon to the data byte
    LDRB    r0, [r7, r6]        ; Load the data byte (ASCII paddle char) into R0

    ; Convert ASCII character ('0'-'3') back to numeric (0-3)
    SUB     r0, r0, #'0'        ; Convert ASCII '0' to 0, '1' to 1, etc.
    CMP     r0, #0              ; Validate range (0-3)
    BLT     L_recv_loop_end     ; If less than 0, invalid
    CMP     r0, #3              ;
    BGT     L_recv_loop_end     ; If greater than 3, invalid

    B       L_recv_loop_end     ; Data successfully parsed, exit loop

L_recv_loop_end
    POP     {r1-r7, PC}         ; Restore registers and return (R0 contains paddle_y or -1)
ENDP


; -----------------------------------------------------------------------------
; main_loop: The main game loop for Player 2.
; Handles local paddle input, sends/receives paddle data over Wi-Fi,
; updates game, and renders.
; -----------------------------------------------------------------------------
main_loop PROC
    PUSH    {r0-r3, LR}         ; Save registers and Link Register

    ; ----------------------------------------------------
    ; PLAYER 2 SPECIFIC LOGIC
    ; ----------------------------------------------------

    ; 1. Read local buttons for Player 2's paddle control (controlling paddle2_y)
    BL      read_buttons        ; Call read_buttons to get local button state into R0
    MOV     r1, r0              ; Copy button state from R0 to R1 for processing

    ; Get current paddle2_y value
    LDR     r2, =paddle2_y      ; Load the address of paddle2_y into R2
    LDR     r3, [r2]            ; Load the current value of paddle2_y into R3

    ; Check button states and update paddle2_y
    TST     r1, #0x01           ; Test if the 'up' button (bit 0) is pressed
    BNE     L_p2_move_up        ; If bit 0 is set, branch to move paddle up

    TST     r1, #0x02           ; Test if the 'down' button (bit 1) is pressed
    BNE     L_p2_move_down      ; If bit 1 is set, branch to move paddle down

    B       L_p2_no_move        ; If no recognized button is pressed, skip paddle movement

L_p2_move_up
    CMP     r3, #0              ; Compare current paddle2_y (R3) with the top boundary (0)
    BEQ     L_p2_no_move        ; If already at 0, do not move further up
    SUBS    r3, r3, #1          ; Decrement paddle2_y (move paddle up by 1)
    STR     r3, [r2]            ; Store the new paddle2_y value back to memory
    B       L_p2_no_move        ; Continue to the next step in the loop

L_p2_move_down
    CMP     r3, #MAX_PADDLE_Y_POS ; Compare current paddle2_y (R3) with the bottom boundary (MAX_PADDLE_Y_POS)
    BEQ     L_p2_no_move        ; If already at the bottom, do not move further down
    ADDS    r3, r3, #1          ; Increment paddle2_y (move paddle down by 1)
    STR     r3, [r2]            ; Store the new paddle2_y value back to memory
    ; Fall through to L_p2_no_move

L_p2_no_move

    ; 2. Send local paddle position (paddle2_y) to Player 1 via Wi-Fi
    ; The updated paddle2_y value is currently in R3.
    MOV     r0, r3              ; Move paddle2_y (from R3) into R0 for send_paddle_wifi
    BL      send_paddle_wifi    ; Call send_paddle_wifi to transmit Player 2's paddle_y

    ; 3. Receive remote input (Player 1's paddle position) via Wi-Fi
    BL      receive_paddle_wifi ; Call receive_paddle_wifi; received paddle_y will be in R0
    CMP     r0, #0xFFFFFFFF     ; Check if receive_paddle_wifi returned an error/no data (-1)
    BEQ     L_skip_paddle1_update ; If error, don't update paddle1_y

    LDR     r1, =paddle1_y      ; Load the address of paddle1_y into R1
    STR     r0, [r1]            ; Store the received value (from R0) into paddle1_y

L_skip_paddle1_update

    ; ----------------------------------------------------
    ; COMMON GAME LOGIC (Applies to both players)
    ; ----------------------------------------------------
    BL      game_update         ; Update ball position and handle collisions
    BL      lcd_render          ; Render the current game state on the LCD

    MOV     r0, #30             ; Set delay value (e.g., 30ms) for game speed control
    BL      delay_ms            ; Call delay_ms to pause execution

    POP     {r0-r3, PC}         ; Restore saved registers and return from the function
    B       main_loop           ; Branch back to the beginning of main_loop to create an infinite loop
    ENDP

    END
