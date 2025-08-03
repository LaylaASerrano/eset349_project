	AREA    |.text|, CODE, READONLY
    
    ; Export the main_loop so C can call it
    EXPORT  main_loop
    
    ; Import functions from other assembly files
    IMPORT  game_init
	import  i2c_scan
    IMPORT  lcd_init
    IMPORT  game_update
    IMPORT  lcd_render
    IMPORT  HAL_Delay           ; ADD THIS: Import HAL_Delay
		
    
    ; Import C functions for ESP8266 Communication
    IMPORT  ESP8266_Setup       ; From esp_at_commands.c
    IMPORT  Send_Paddle_Wifi    ; From esp_at_commands.c
    IMPORT  Receive_Paddle_Wifi ; From esp_at_commands.c
    
    ; Import paddle variables
    IMPORT  ball_x
    IMPORT  ball_y
    IMPORT  ball_vx
    IMPORT  ball_vy
    IMPORT  paddle1_y           ; Player 1's paddle Y (local, controlled by buttons)
    IMPORT  paddle2_y           ; Player 2's paddle Y (remote, received via Wi-Fi)

; --- Constants for paddle movement boundaries ---
MAX_PADDLE_Y_POS EQU 1      ; Max Y position for paddle on a 2-line LCD (0-1)

; -----------------------------------------------------------------------------
; main_loop: The main game loop for Player 1.
; This function is called from C main() after all initialization is complete.
; Handles local paddle input, sends/receives paddle data over Wi-Fi,
; updates game, and renders.
; -----------------------------------------------------------------------------
main_loop PROC
    PUSH    {r0-r3, LR}
    
    ; Initialize LCD and game (now that peripherals are ready)
	bl      i2c_scan
    BL      lcd_init            ; Initialize LCD module
    BL      game_init           ; Initialize game variables
    
    ; Setup UART communication (formerly ESP8266 Setup)
    LDR     R0, =lcd_send_cmd   ; Pass lcd_send_cmd_ptr
    LDR     R1, =lcd_send_data  ; Pass lcd_send_data_ptr  
    LDR     R2, =HAL_Delay      ; CHANGE THIS: Pass HAL_Delay_ptr
    BL      ESP8266_Setup       ; This will now just perform basic UART readiness

game_loop
    ; ... (rest of game_loop remains the same until delay calls) ...

    MOV     r0, #500            ; Load 500 into R0 for a 500ms delay
    BL      HAL_Delay           ; CHANGE THIS: Call HAL_Delay function

    POP     {r0-r3, LR}
    PUSH    {r0-r3, LR}        ; Re-save registers for next iteration
    
    B       game_loop           ; Continue the game loop

L_send_fail_handler
    ; Handle the case where sending paddle failed
    ; Clear LCD and display error
    MOV     R0, #0x01
    BL      lcd_send_cmd        ; Clear display
    MOV     R0, #2
    BL      HAL_Delay           ; CHANGE THIS: Call HAL_Delay
    MOV     R0, #0x80           ; First line
    BL      lcd_send_cmd
    
    ; Display "SND FAIL"
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
    MOV     r0, #1000           ; Wait 1 second
    BL      HAL_Delay           ; CHANGE THIS: Call HAL_Delay
    B       game_loop           ; Try to continue instead of infinite trap
    
	ENDP
    
    ; Import lcd functions
    IMPORT  lcd_send_cmd
    IMPORT  lcd_send_data
    
    END