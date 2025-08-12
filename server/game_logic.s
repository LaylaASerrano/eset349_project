
    AREA    |.text|, CODE, READONLY
    export  game_update
    export  game_init
    export  reset_ball
    ;written by Layla Serrano
    ; Export global variables to other assembly files and C
    EXPORT  ball_x
    EXPORT  ball_y
    EXPORT  ball_vx
    EXPORT  ball_vy
    EXPORT  paddle1_y

    ; Import paddle2_y from C file (main_server.c)
    IMPORT  paddle2_y

    ; constants section for a 2-line LCD
MAX_Y          EQU     1           ; Max Y-coordinate for the ball (0-1 for 2 lines)
MAX_X          EQU     15          ; 16 characters (0–15)
PADDLE_HEIGHT  EQU     1           ; Paddle is 1 character tall
BALL_START_X   EQU     8           ; Center X
BALL_START_Y   EQU     0           ; Start at top of the display

game_init PROC
    PUSH    {r0-r3, LR}         ; Save registers and LR

    ; Initialize all game state variables
    LDR     r0, =ball_x         ;
    MOV     r1, #BALL_START_X   ;
    STR     r1, [r0]            ; Initialize ball_x

    LDR     r0, =ball_y         ;
    MOV     r1, #BALL_START_Y   ;
    STR     r1, [r0]            ; Initialize ball_y

    LDR     r0, =ball_vx        ;
    MOV     r1, #1              ; Start moving to the right
    STR     r1, [r0]            ;

    LDR     r0, =ball_vy        ;
    MOV     r1, #1              ; Start moving DOWN
    STR     r1, [r0]            ;

    LDR     r0, =paddle1_y      ;
    MOV     r1, #0              ; Initial position for paddle1_y
    STR     r1, [r0]            ;

    LDR     r0, =paddle2_y      ;
    MOV     r1, #0              ; Initial position for paddle2_y
    STR     r1, [r0]            ;

    POP     {r0-r3, PC}         ; Restore registers and return
	ENDP

reset_ball PROC
    PUSH    {r0-r2, LR}         ; Save registers and LR

    ; Reset ball to center position
    LDR     r0, =ball_x         ;
    MOV     r1, #BALL_START_X   ;
    STR     r1, [r0]            ; Reset ball_x

    LDR     r0, =ball_y         ;
    MOV     r1, #BALL_START_Y   ;
    STR     r1, [r0]            ; Reset ball_y

    ; Reset ball velocity
    LDR     r0, =ball_vx        ;
    MOV     r1, #1              ; Reset ball_vx (moving right)
    STR     r1, [r0]            ;

    LDR     r0, =ball_vy        ;
    MOV     r1, #1              ; Reset ball_vy (moving down)
    STR     r1, [r0]            ;

    POP     {r0-r2, PC}         ; Restore registers and return
	ENDP

game_update PROC
    PUSH    {r0-r7, LR}         ; Save registers and LR

    ; Update ball X position
    LDR     r0, =ball_x
    LDR     r1, [r0]            ; r1 = ball_x
    LDR     r2, =ball_vx
    LDR     r3, [r2]            ; r3 = ball_vx
    ADD     r1, r1, r3          ; ball_x += ballvx
    STR     r1, [r0]            ; stores new ball_x

    ; Update ball Y position
    LDR     r0, =ball_y
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r2, =ball_vy
    LDR     r5, [r2]            ; r5 = ball_vy
    ADD     r4, r4, r5          ; ball_y += ball_vy
    STR     r4, [r0]            ; stores new ball_y

    ; --- Implement "Random" Bounces ---
    LDR     r0, =ball_x
    LDR     r1, [r0]            ; r1 = current ball_x
    LDR     r0, =ball_y
    LDR     r3, [r0]            ; r3 = current ball_y
    LDR     r0, =ball_vx
    LDR     r5, [r0]            ; r5 = current ball_vx
    LDR     r0, =ball_vy
    LDR     r7, [r0]            ; r7 = current ball_vy

    ; Condition 1: ball is (3,0) and moving left
    CMP     r1, #3
    BNE     check_random_2
    CMP     r3, #0
    BNE     check_random_2
    CMP     r5, #-1
    BNE     check_random_2
    ADD     r1, r1, #1          ; ball_x = 4
    STR     r1, [r0]            ; r0 holds ball_x address
    ADD     r3, r3, #1          ; ball_y = 1
    STR     r3, [r0]            ; r0 holds ball_y address
    MOV     r5, #1              ; ball_vx = 1
    STR     r5, [r0]            ; r0 holds ball_vx address
    MOV     r7, #1              ; ball_vy = 1
    STR     r7, [r0]            ; r0 holds ball_vy address
    B       post_random_bounce

check_random_2
    ; Condition 2: ball is (9,1) and moving right
    CMP     r1, #9
    BNE     check_random_3
    CMP     r3, #1
    BNE     check_random_3
    CMP     r5, #1
    BNE     check_random_3
    ADD     r1, r1, #1          ; ball_x = 10
    STR     r1, [r0]
    SUB     r3, r3, #1          ; ball_y = 0
    STR     r3, [r0]
    MOV     r7, #-1             ; ball_vy = -1
    STR     r7, [r0]
    B       post_random_bounce

check_random_3
    ; Condition 3: ball is (6,1) and moving left
    CMP     r1, #6
    BNE     check_random_4
    CMP     r3, #1
    BNE     check_random_4
    CMP     r5, #-1
    BNE     check_random_4
    SUB     r1, r1, #1          ; ball_x = 5
    STR     r1, [r0]
    SUB     r3, r3, #1          ; ball_y = 0
    STR     r3, [r0]
    MOV     r7, #-1             ; ball_vy = -1
    STR     r7, [r0]
    B       post_random_bounce

check_random_4
    ; Condition 4: ball is (12,0) and moving left
    CMP     r1, #12
    BNE     post_random_bounce
    CMP     r3, #0
    BNE     post_random_bounce
    CMP     r5, #-1
    BNE     post_random_bounce
    ADD     r3, r3, #1          ; ball_y = 1
    STR     r3, [r0]
    SUB     r1, r1, #1          ; ball_x = 11
    STR     r1, [r0]
    MOV     r7, #1              ; ball_vy = 1
    STR     r7, [r0]

post_random_bounce
    ; Reload ball positions after potential bounce
    LDR     r0, =ball_x
    LDR     r1, [r0]            ; r1 = ball_x
    LDR     r0, =ball_y
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r0, =ball_vx
    LDR     r3, [r0]            ; r3 = ball_vx
    LDR     r0, =ball_vy
    LDR     r5, [r0]            ; r5 = ball_vy

    ; boundary check for Y (top/bottom walls)
    CMP     r4, #0
    BLT     bounce_y_top
    CMP     r4, #MAX_Y
    BGT     bounce_y_bottom
    B       check_x_collision

bounce_y_top
    MOV     r4, #0
    STR     r4, [r0]
    LDR     r0, =ball_vy
    LDR     r5, [r0]
    RSB     r5, r5, #0
    STR     r5, [r0]
    B       check_x_collision

bounce_y_bottom
    MOV     r4, #MAX_Y
    STR     r4, [r0]
    LDR     r0, =ball_vy
    LDR     r5, [r0]
    RSB     r5, r5, #0
    STR     r5, [r0]

check_x_collision
    ; check x boundary with paddles
    LDR     r0, =ball_x
    LDR     r1, [r0]
    CMP     r1, #0              ; checks left wall (player 1's side)
    BNE     check_right_wall

    ; Check P1 paddle collision
    LDR     r0, =ball_y
    LDR     r4, [r0]
    LDR     r0, =paddle1_y
    LDR     r5, [r0]
    CMP     r4, r5
    BLT     miss_left
    ADD     r6, r5, #PADDLE_HEIGHT
    SUB     r6, r6, #1
    CMP     r4, r6
    BGT     miss_left

    ; HIT: Reverse horizontal velocity
    LDR     r0, =ball_vx
    LDR     r1, [r0]
    RSB     r1, r1, #0
    STR     r1, [r0]

    ; Adjust vertical velocity based on hit position
    SUB     r7, r4, r5
    LDR     r0, =ball_vy
    CMP     r7, #0
    MOVEQ   r1, #-1
    MOVNE   r1, #1
    STR     r1, [r0]

    ; Move ball away from the wall
    LDR     r0, =ball_x
    MOV     r1, #1
    STR     r1, [r0]
    B       game_done

miss_left
    BL      reset_ball
    B       game_done

check_right_wall
    LDR     r0, =ball_x
    LDR     r1, [r0]
    CMP     r1, #MAX_X          ; Check right wall (player 2's side)
    BNE     game_done

    ; Check P2 paddle collision
    LDR     r0, =ball_y
    LDR     r4, [r0]
    LDR     r0, =paddle2_y
    LDR     r5, [r0]
    CMP     r4, r5
    BLT     miss_right
    ADD     r6, r5, #PADDLE_HEIGHT
    SUB     r6, r6, #1
    CMP     r4, r6
    BGT     miss_right

    ; HIT: Reverse horizontal velocity
    LDR     r0, =ball_vx
    LDR     r1, [r0]
    RSB     r1, r1, #0
    STR     r1, [r0]

    ; Adjust vertical velocity based on hit position
    SUB     r7, r4, r5
    LDR     r0, =ball_vy
    CMP     r7, #0
    MOVEQ   r1, #-1
    MOVNE   r1, #1
    STR     r1, [r0]

    ; Move ball away from the wall
    LDR     r0, =ball_x
    MOV     r1, #MAX_X-1
    STR     r1, [r0]
    B       game_done

miss_right
    BL      reset_ball
    B       game_done

game_done
    POP     {r0-r7, PC}
	ENDP

	align 4
    AREA    |.bss|, NOINIT, READWRITE
    EXPORT  ball_x
    EXPORT  ball_y
    EXPORT  ball_vx
    EXPORT  ball_vy
    EXPORT  paddle1_y

    ; Allocate memory for the game variables
ball_x      SPACE   4
ball_y      SPACE   4
ball_vx     SPACE   4
ball_vy     SPACE   4
paddle1_y   SPACE   4
	align
    END
