	AREA    |.text|, CODE, READONLY
    export  Reset_Handler
    export  main_loop
	
	
	import  game_init
	import  lcd_init
	import	game_update
	import	lcd_render
	import  delay_ms
    import  lcd_send_cmd
    import  lcd_send_data
		
	; --- New C function Imports for ESP8266 Communication ---
	IMPORT  MX_USART2_UART_Init
	IMPORT  ESP8266_Setup       ; From esp_at_commands.c
	IMPORT  Send_Paddle_Wifi    ; From esp_at_commands.c
	IMPORT  Receive_Paddle_Wifi ; From esp_at_commands.c
	import  HAL_Init

	
	

    ; --- IMPORTANT: Add these imports for paddle variables ---
    IMPORT  ball_x              ; Also import ball_x, ball_y, etc. if needed in main,
    IMPORT  ball_y              ; though game_update and lcd_render handle them.
    IMPORT  ball_vx
    IMPORT  ball_vy
    IMPORT  paddle1_y           ; Player 1's paddle Y (local, controlled by buttons)
    IMPORT  paddle2_y           ; Player 2's paddle Y (remote, received via Wi-Fi)

    


; --- Constants for TCP Server (Player 1) ---
TCP_LINK_ID             EQU 0                   ; Link ID for TCP connection (usually 0 for single connection)
; This assumes only one client connects. If multiple clients, you need to manage link IDs.

; --- Constants for paddle movement boundaries ---
MAX_PADDLE_Y_POS EQU 1      ; Max Y position for the top of a 2-pixel paddle on a 4-line LCD (0-3)

; ... (before Reset_Handler PROC) ...



; -----------------------------------------------------------------------------
; Reset_Handler: Entry point after reset. Initializes peripherals and ESP8266.
; -----------------------------------------------------------------------------
Reset_Handler PROC
	PUSH    {LR}                ; Save LR for proper function context

    BL      HAL_Init            ; 1. HAL_Init must be very first for HAL framework and SysTick. (CORRECT)
    BL      game_init           ; 3. Initialize game state (not critical order-wise for hardware). (OK)
    BL      lcd_init            ; 5. Initialize LCD module (relies on I2C and GPIO). (GOOD)

  
    BL MX_USART2_UART_Init       ;uart2 init

    ; --- Call the ESP8266 setup ---
    LDR     R0, =lcd_send_cmd   ; Address of lcd_send_cmd
    LDR     R1, =lcd_send_data  ; Address of lcd_send_data
    LDR     R2, =delay_ms       ; Address of delay_ms
    BL      ESP8266_Setup       ; 7. Initialize ESP8266 (relies on UART, LCD for display, delay). (GOOD)

    POP     {LR}                ; Restore LR. (Correct for balancing PUSH)
    B       main_loop           ; Go to the main game loop. (Correct way to exit Reset_Handler)
	ENDP



; -----------------------------------------------------------------------------
; main_loop: The main game loop for Player 1.
; Handles local paddle input, sends/receives paddle data over Wi-Fi,
; updates game, and renders.
; -----------------------------------------------------------------------------
main_loop PROC
    PUSH    {r0-r3, LR}

    ; ----------------------------------------------------
    ; PLAYER 1 SPECIFIC LOGIC
    ; ----------------------------------------------------

    ; 1. Read local buttons for Player 1's paddle control (controlling paddle1_y)
    ; Replaces: BL read_buttons and MOV r1, r0
    LDR     r0, =0x40020000     ; GPIOA base address (you might need to import this constant from main.c or define it)
    LDR     r1, [r0, #0x10]     ; Read GPIOA_IDR (input data register) into R1

    ; Apply mask and invert (as previously fixed logic from read_buttons)
    MOV     r0, #0x00000003     ; Mask for PA0 and PA1 (assuming these are your buttons)
    AND     r1, r1, r0          ; Apply mask (R1 = raw_IDR & mask)
    EOR     r1, r1, r0          ; Invert bits: 1 = pressed, 0 = released (R1 is now processed button state)

    LDR     r2, =paddle1_y
    LDR     r3, [r2]

    TST     r1, #0x01           ; Check button 1 (PA0)
    BNE     L_p1_move_up

    TST     r1, #0x02           ; Check button 2 (PA1)
    BNE     L_p1_move_down

    B       L_p1_no_move



L_p1_move_up
    CMP     r3, #0
    BEQ     L_p1_no_move
    SUBS    r3, r3, #1
    STR     r3, [r2]
    B       L_p1_no_move

L_p1_move_down
    CMP     r3, #MAX_PADDLE_Y_POS
    BEQ     L_p1_no_move
    ADDS    r3, r3, #1
    STR     r3, [r2]

L_p1_no_move

    ; 2. Send local paddle position (paddle1_y) to Player 2 via Wi-Fi
    MOV     r0, r3              ; Move paddle1_y (from R3) into R0 for Send_Paddle_Wifi
    BL      Send_Paddle_Wifi    ; Call the C function
                                ; Returns 1 on success, 0 on failure (R0)
    ; You might add error handling here if the send fails
    CMP     R0, #0
    BEQ     L_send_fail_handler ; Branch to handle if send failed

L_send_ok_continue

    ; 3. Receive remote input (Player 2's paddle position) via Wi-Fi
    BL      Receive_Paddle_Wifi ; Call the C function; received paddle_y will be in R0 or 0xFF
    CMP     r0, #0xFF           ; Check if Receive_Paddle_Wifi returned error/no data (0xFF)
    BEQ     L_skip_paddle2_update ; If error, don't update paddle2_y

    LDR     r1, =paddle2_y
    STR     r0, [r1]            ; Store the received value (from R0) into paddle2_y

L_skip_paddle2_update

    ; ----------------------------------------------------
    ; COMMON GAME LOGIC
    ; ----------------------------------------------------
    BL      game_update
    BL      lcd_render

    MOV     r0, #30
    BL      delay_ms

    POP     {r0-r3, PC}
    B       main_loop

L_send_fail_handler
    ; Handle the case where sending paddle failed (e.g., connection lost)
    ; You might want to retry, display an error, or attempt re-initialization.
    ; For now, let's just loop infinitely on an error to indicate it.
    BL      lcd_send_cmd        ; Clear LCD
    MOV     R0, #0x01
    BL      lcd_send_cmd
    MOV     R0, #2
    BL      delay_ms
    MOV     R0, #0x80
    BL      lcd_send_cmd
    MOV     R0, #'S'
    BL      lcd_send_data
    MOV     R0, #'N'
    BL      lcd_send_data
    MOV     R0, #'D'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data
    MOV     R0, #'F'
    BL      lcd_send_data
    MOV     R0, #'A'
    BL      lcd_send_data
    MOV     R0, #'I'
    BL      lcd_send_data
    MOV     R0, #'L'
    BL      lcd_send_data
L_send_error_trap
    B       L_send_error_trap
	ENDP
	
	align 4
	AREA    |.data|, DATA, READONLY
PLAYER_GAME_PORT_STR    DCB "8080",0       ; e.g., "8080",0


    END
