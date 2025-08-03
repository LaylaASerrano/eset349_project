    AREA    |.text|, CODE, READONLY

    ; Export the main_server so C can call it
    EXPORT  main_server

    ; Import functions from other assembly files
    IMPORT  game_init
    IMPORT  lcd_init
    IMPORT  game_update
    IMPORT  lcd_render
    IMPORT  LCDString           ; New function to display a string
    IMPORT  LCDSetCursor        ; New function to set cursor position
    IMPORT  HAL_Delay

    ; Import GPIO functions to read button input
    IMPORT  HAL_GPIO_ReadPin
    IMPORT  GPIOC_BASE          ; GPIO Base address for buttons

    ; Import the new C function to process UART commands
    IMPORT  process_uart_commands

    ; Import paddle variables and game state
    IMPORT  ball_x
    IMPORT  ball_y
    IMPORT  ball_vx
    IMPORT  ball_vy
    IMPORT  paddle1_y           ; Player 1's paddle Y (local, controlled by buttons)
    IMPORT  paddle2_y           ; Player 2's paddle Y (remote, received via UART)

; --- Constants for GPIO buttons ---
; Assumes UP button on PC10 and DOWN button on PC11, active-low
GPIO_BUTTON_UP_PIN EQU 0x0400   ; 1 << 10
GPIO_BUTTON_DOWN_PIN EQU 0x0800 ; 1 << 11

; -----------------------------------------------------------------------------
; main_server: The main game loop for Player 1.
; This function is called from C main() after all initialization is complete.
; -----------------------------------------------------------------------------
main_server PROC
    PUSH    {r0-r4, LR}

    ; Initialize LCD and game (now that peripherals are ready)
    BL      lcd_init            ; Initialize direct-link LCD module
    BL      game_init           ; Initialize game variables

    ; Display "SUCCESS" message on LCD
    MOV     R0, #0x80           ; Set cursor to line 1, column 0
    BL      LCDSetCursor

    LDR     R0, =welcome_msg    ; Load address of the welcome message
    BL      LCDString

    MOV     r0, #1000           ; Delay for 1 second to show the message
    BL      HAL_Delay

game_loop
    ; --- Process incoming UART commands from the C buffer ---
    ; This call updates the paddle2_y variable if a new command is ready.
    BL      process_uart_commands

    ; --- Read local button input for paddle1 ---
    ; Read UP button (PC10)
    LDR     R0, =GPIOC_BASE     ; Load GPIOC base address
    MOV     R1, #GPIO_BUTTON_UP_PIN ; Load pin number for UP button
    BL      HAL_GPIO_ReadPin    ; Call C function to read pin state
    CMP     R0, #0              ; Compare result to GPIO_PIN_RESET (0)
    BNE     check_down_button   ; If not pressed, skip to next button check

    ; If UP button is pressed, move paddle1_y up
    LDR     R0, =paddle1_y      ; Load address of paddle1_y
    LDR     R1, [R0]            ; Load current value
    CMP     R1, #0              ; Check if already at the top (y=0)
    BEQ     check_down_button   ; If so, do nothing
    SUBS    R1, R1, #1          ; Decrement y position
    STR     R1, [R0]            ; Store new value

check_down_button
    ; Read DOWN button (PC11)
    LDR     R0, =GPIOC_BASE
    MOV     R1, #GPIO_BUTTON_DOWN_PIN
    BL      HAL_GPIO_ReadPin
    CMP     R0, #0              ; Compare result to GPIO_PIN_RESET (0)
    BNE     update_game_state   ; If not pressed, skip

    ; If DOWN button is pressed, move paddle1_y down
    LDR     R0, =paddle1_y
    LDR     R1, [R0]
    CMP     R1, #1              ; Check if already at the bottom (y=1)
    BEQ     update_game_state   ; If so, do nothing
    ADDS    R1, R1, #1          ; Increment y position
    STR     R1, [R0]

update_game_state
    ; Update game state (ball position, etc.)
    BL      game_update

    ; Render the new game state to the LCD
    BL      lcd_render

    ; Add a short delay to control game speed
    MOV     r0, #50             ; Load 50 into R0 for a 50ms delay
    BL      HAL_Delay

    ; Continue the game loop
    B       game_loop

    ; String data for the welcome message

welcome_msg DCB "SUCCESS: PONG!", 0
    ALIGN
	ENDP

    ; Import lcd functions
    IMPORT  lcd_send_cmd
    IMPORT  lcd_send_data

    END
