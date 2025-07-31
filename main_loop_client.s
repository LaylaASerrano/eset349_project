    AREA    |.text|, CODE, READONLY

    EXPORT  main_loop_client    ; Export the main game loop

    ; Removed IMPORT of game_init_client_asm (it's defined below)
    IMPORT  HAL_Delay           ; Import HAL_Delay from C
    IMPORT  ESP8266_Setup_Client ; Import C function for ESP setup
    IMPORT  Send_Paddle_Wifi_Client ; Import C function to send paddle

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
    BL      game_init_client_asm    ; Call local version of init

    ; Setup UART communication
    LDR     R0, =HAL_Delay
    BL      ESP8266_Setup_Client

client_game_loop
    ; PLAYER 2 SPECIFIC LOGIC

    ; 1. Read local buttons
    LDR     r0, =0x40020000
    LDR     r1, [r0, #0x10]

    MOV     r0, #0x00000003
    AND     r1, r1, r0
    EOR     r1, r1, r0

    LDR     r2, =paddle2_y
    LDR     r3, [r2]

    TST     r1, #0x01
    BNE     L_p2_move_up

    TST     r1, #0x02
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

    ; 2. Send paddle position
    MOV     r0, r3
    BL      Send_Paddle_Wifi_Client
    CMP     R0, #0
    BEQ     L_send_fail_handler_client

L_send_ok_continue_client
    ; Toggle LED
    LDR     R0, =0x40020000
    LDR     R1, [R0, #0x14]
    EOR     R1, R1, #(1 << 5)
    STR     R1, [R0, #0x14]

    MOV     r0, #50
    BL      HAL_Delay

    POP     {r0-r3, LR}
    PUSH    {r0-r3, LR}

    B       client_game_loop

L_send_fail_handler_client
    MOV r0, #1000
    BL HAL_Delay
    B client_game_loop

    ENDP

; --- Define game_init_client_asm function ---
    EXPORT  game_init_client_asm
game_init_client_asm PROC
    PUSH    {r0, r1, LR}

    LDR     r0, =paddle2_y
    MOV     r1, #0
    STR     r1, [r0]

    POP     {r0, r1, PC}
    ENDP

    align 4
    AREA    |.bss|, NOINIT, READWRITE
    EXPORT  paddle2_y
paddle2_y   SPACE   4
    align
    END
