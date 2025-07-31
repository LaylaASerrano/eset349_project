AREA    |.text|, CODE, READONLY

    EXPORT  main_loop_client

    IMPORT  game_init_client    ; Initialize paddle2_y locally
    IMPORT  delay_ms
    IMPORT  ESP8266_Setup_Client
    IMPORT  Send_Paddle_Wifi

    ; Import paddle variable (Board 2 controls paddle2_y)
    IMPORT  paddle2_y           ; Player 2's paddle Y (local, controlled by buttons)

; --- Constants for paddle movement boundaries ---
MAX_PADDLE_Y_POS EQU 1      ; Max Y position for paddle on a 2-line LCD (0-1)

; -----------------------------------------------------------------------------
; main_loop_client: The main loop for Player 2 (Client).
; This function is called from C main().
; Handles local paddle input and sends paddle data over Wi-Fi.
; -----------------------------------------------------------------------------
main_loop_client PROC
    PUSH    {r0-r3, LR}

    ; Initialize game variables (only paddle2_y)
    BL      game_init_client    ; Initialize paddle2_y

    ; Setup ESP8266 (Client mode)
    LDR     R0, =delay_ms       ; Pass delay_ms_ptr
    BL      ESP8266_Setup_Client

client_game_loop
    ; ----------------------------------------------------
    ; PLAYER 2 SPECIFIC LOGIC (LOCAL PADDLE CONTROL & SENDING)
    ; ----------------------------------------------------

    ; 1. Read local buttons for Player 2's paddle control (controlling paddle2_y)
    LDR     r0, =0x40020000     ; GPIOA base address (Assuming PA0/PA1 for buttons on Board 2)
    LDR     r1, [r0, #0x10]     ; Read GPIOA_IDR (input data register) into R1

    ; Apply mask and invert (buttons are active low with pullup)
    MOV     r0, #0x00000003     ; Mask for PA0 and PA1
    AND     r1, r1, r0          ; Apply mask (R1 = raw_IDR & mask)
    EOR     r1, r1, r0          ; Invert bits: 1 = pressed, 0 = released

    LDR     r2, =paddle2_y      ; Load address of paddle2_y
    LDR     r3, [r2]            ; Load current paddle2_y into R3

    TST     r1, #0x01           ; Check button 1 (PA0) - move up
    BNE     L_p2_move_up

    TST     r1, #0x02           ; Check button 2 (PA1) - move down
    BNE     L_p2_move_down

    B       L_p2_no_move

L_p2_move_up
    CMP     r3, #0
    BEQ     L_p2_no_move
    SUBS    r3, r3, #1
    STR     r3, [r2]
    B       L_p2_no_move

L_p2_move_down
    CMP     r3, #MAX_PADDLE_Y_POS
    BEQ     L_p2_no_move
    ADDS    r3, r3, #1
    STR     r3, [r2]

L_p2_no_move

    ; 2. Send local paddle position (paddle2_y) to Player 1 (Server) via Wi-Fi
    MOV     r0, r3              ; Move paddle2_y (from R3) into R0 for Send_Paddle_Wifi
    BL      Send_Paddle_Wifi    ; Call the C function
    CMP     R0, #0
    BEQ     L_send_fail_handler_client ; Branch to handle if send failed

L_send_ok_continue_client

    ; --- (Optional) LED Toggling Code for debug on Board 2 ---
    ; LDR     R0, =0x40020000     ; GPIOA Base Address (where PA5 resides)
    ; LDR     R1, [R0, #0x14]     ; Read ODR (Output Data Register) for GPIOA
    ; EOR     R1, R1, #(1 << 5)   ; Toggle PA5 (bit 5)
    ; STR     R1, [R0, #0x14]     ; Write the toggled value back to ODR

    MOV     r0, #50             ; Load 50ms into R0 for a short delay (adjust as needed)
    BL      delay_ms            ; Call the delay_ms function

    POP     {r0-r3, LR}
    PUSH    {r0-r3, LR}        ; Re-save registers for next iteration

    B       client_game_loop    ; Continue the game loop

L_send_fail_handler_client
    ; You might want to indicate this failure (e.g., via LED blinks)
    ; For now, it will just trap in the C Trap_ESP_Error_Client function
    ; if Send_Paddle_Wifi returns 0 and then Trap_ESP_Error_Client is called.
    ; This branch is mostly for if Send_Paddle_Wifi *doesn't* trap but returns 0.
    ; If Send_Paddle_Wifi is designed to call Trap_ESP_Error, this branch might be skipped.
    MOV r0, #1000 ; Example: brief delay then try again
    BL delay_ms
    B client_game_loop

    ENDP

    ; --- Client-specific game logic section for Board 2 ---
    AREA    |.text|, CODE, READONLY
    EXPORT  game_init_client

    ; Export global variable for paddle2_y
    EXPORT  paddle2_y

; New constant for paddle max Y, consistent with 2-line game (0 or 1)
MAX_PADDLE_Y_GAME_POS_CLIENT EQU 1

game_init_client PROC
    PUSH    {r0, r1, LR}

    ; Initialize paddle2_y
    LDR     r0, =paddle2_y
    MOV     r1, #0              ; Initial position for paddle2_y (e.g., top of screen, or center if MAX_PADDLE_Y_GAME_POS_CLIENT allows)
    STR     r1, [r0]

    POP     {r0, r1, PC}
    ENDP

    align 4
    AREA    |.bss|, NOINIT, READWRITE
    EXPORT  paddle2_y
paddle2_y   SPACE   4           ; Allocate 4 bytes for paddle2_y
    align
    END