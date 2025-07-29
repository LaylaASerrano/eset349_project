	AREA    |.text|, CODE, READONLY
    ;export  __Vectors
    export  Reset_Handler
    export  main_loop
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

    ; New imports for communication functions
	import	send_string_uart
	import	uart_read_line
	import	str_contains
	import	send_at_command

    ; New imports for global variables and constants
	import	g_ms_ticks          ; From delay.s
	import  uart_rx_buffer      ; From usart_init.s
    import  uart_rx_ready       ; From usart_init.s

    ; New imports for AT command constants (from usart_init.s)
	import	CMD_AT
	import	CMD_AT_RST
	import	CMD_AT_CWMODE1
	import	CMD_AT_CWJAP_TEST   ; Use this for hardcoded Wi-Fi connect
	import	CMD_AT_CIFSR

	import	RESP_OK
	import	RESP_ERROR
	import	RESP_WIFI_GOT_IP
	import	RESP_CONNECT
	import	RESP_SEND_OK


;__Vectors   DCD 0x20020000      ; init SP
            DCD Reset_Handler   ; Reset handler
Reset_Handler PROC
    ; PUSH    {LR}              ; Not needed if it branches to an infinite loop

    ; peripherals
    BL      gpio_init           ;
    BL      game_init           ;
    BL      i2c_init            ;
    BL      lcd_init            ; Added LCD initialization
    BL      usart_init          ;
    BL      delay_init          ; Initialize SysTick for delays

    BL      esp8266_setup       ; Call a new routine for ESP8266 initialization

    ; POP     {PC}              ; Don't pop PC, branch to main_loop instead
    B       main_loop           ; Go to the main game loop
	ENDP

; -----------------------------------------------------------------------------
; esp8266_setup: Initializes the ESP8266 module with AT commands.
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

    ; --- 1. Test AT command ---
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
    ; You might want to clear the RX buffer or read an expected "ready" message here.
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
    ; This is using the CMD_AT_CWJAP_TEST defined in usart_init.s
    MOV     R0, #CMD_AT_CWJAP_TEST ; Command: "AT+CWJAP=\"YourSSID\",\"YourPassword\"\r\n"
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



main_loop PROC
    PUSH    {LR}                ; Save LR, though this function loops back to itself

    ; Read local buttons
    BL      read_buttons        ; R0 will contain button state (0-3)

    ; Send local button state over UART (e.g., as a single character '0', '1', '2', '3')
    ADD     R0, R0, #'0'        ; Convert numerical button state to ASCII char
    MOV     R1, R0              ; Move to R1 for send_input_uart (or send_string_uart if you build a string)
    BL      send_input_uart     ; Send the local button state character
    MOV     R1, #0x0D           ; Send Carriage Return
    BL      send_input_uart
    MOV     R1, #0x0A           ; Send Line Feed
    BL      send_input_uart

    ; Receive remote button state (from the other board)
    ; Use uart_read_line to get a full line, then parse it.
    MOV     R0, #50             ; Timeout for receiving (e.g., 50ms, shorter than game delay)
    BL      uart_read_line
    CMP     R0, #1              ; Check if a line was successfully received
    BNE     L_skip_remote_paddle_update ; If not, skip update

    ; Parse the received character from uart_rx_buffer
    LDR     R0, =uart_rx_buffer
    LDRB    R1, [R0]            ; Get the first char (should be '0','1','2','3')
    CMP     R1, #'0'            ; Check if it's a digit
    BLT     L_skip_remote_paddle_update
    CMP     R1, #'3'
    BGT     L_skip_remote_paddle_update

    SUB     R1, R1, #'0'        ; Convert ASCII digit back to numerical value (0-3)
    LDR     R0, =paddle2_y      ; Load address of paddle2_y
    STR     R1, [R0]            ; Update remote paddle position

L_skip_remote_paddle_update

    BL      game_update         ; Update game logic (ball, local paddle)
    BL      lcd_render          ; Render game state to LCD
    MOV     r0, #30             ; Add a delay to control game speed (e.g., 30ms)
    BL      delay_ms            ;
    POP     {PC}                ; Pop PC to return. Then the B main_loop takes over.
    B       main_loop           ; This creates an infinite loop.
	ENDP


    END