	AREA    |.text|, CODE, READONLY
    export  game_update
    export  game_init
    export  reset_ball
    export  ball_x
    export  ball_y
    export  ball_vx
    export  ball_vy
    export  paddle1_y
    export  paddle2_y

    ; constants section
MAX_Y          EQU     1           ; Since it's a 4-line LCD (0–3)
MAX_X          EQU     15          ; 16 characters (0–15)
PADDLE_HEIGHT  EQU     1           ; Paddle is 2 pixels tall
BALL_START_X   EQU     8           ; Center X
BALL_START_Y   EQU     0           ; Center Y

game_init PROC
    PUSH    {r0-r3, LR}         ; Save registers and LR

    ; position set
    LDR     r0, =ball_x         ;
    MOV     r1, #BALL_START_X   ;
    STR     r1, [r0]            ; Initialize ball_x

    LDR     r0, =ball_y         ;
    MOV     r1, #BALL_START_Y   ;
    STR     r1, [r0]            ; Initialize ball_y

    ; velocity set
    LDR     r0, =ball_vx        ;
    MOV     r1, #1              ; start moving to the right
    STR     r1, [r0]            ;

    LDR     r0, =ball_vy        ;
    MOV     r1, #-1             ; start moving up
    STR     r1, [r0]            ;

    ; Initialize paddle positions
    LDR     r0, =paddle1_y      ;
    MOV     r1, #1              ; Initial position for paddle1_y (e.g., center of screen)
    STR     r1, [r0]            ;

    LDR     r0, =paddle2_y      ;
    MOV     r1, #1              ; Initial position for paddle2_y
    STR     r1, [r0]            ;

    POP     {r0-r3, PC}         ; Restore registers and return
	ENDP

; resets ball to center with random direction
reset_ball PROC
    PUSH    {r0-r2, LR}         ; Save registers and LR

    LDR     r0, =ball_x         ;
    MOV     r1, #BALL_START_X   ;
    STR     r1, [r0]            ; Reset ball_x

    LDR     r0, =ball_y         ;
    MOV     r1, #BALL_START_Y   ;
    STR     r1, [r0]            ; Reset ball_y

    LDR     r0, =ball_vx        ;
    MOV     r1, #1              ; Reset ball_vx
    STR     r1, [r0]            ;

    LDR     r0, =ball_vy        ;
    MOV     r1, #-1             ; Reset ball_vy
    STR     r1, [r0]            ;

    POP     {r0-r2, PC}         ; Restore registers and return
	ENDP

game_update PROC
    ; - Update ball position based on direction

    ; loads the balls x position and velocity and then updates
    PUSH    {r0-r7, LR}         ; Save registers and LR

    LDR     r0, =ball_x         ;
    LDR     r1, [r0]            ; r1 = ball_x

    LDR     r2, =ball_vx        ;
    LDR     r3, [r2]            ; r3 = ball_vx

    ADD     r1, r1, r3          ; ball_x += ballvx
    STR     r1, [r0]            ; stores new ball_x

    ; loads balls y position and velocity and then updates

    LDR     r0, =ball_y         ;
    LDR     r4, [r0]            ; r4 = ball_y

    LDR     r2, =ball_vy        ;
    LDR     r5, [r2]            ; r5 = ball_vy

    ADD     r4, r4, r5          ; ball_y += ball_vy
    STR     r4, [r0]            ; stores new ball_y

    ; boundary check for Y
    LDR     r0, =ball_y         ; Load address of ball_y again for consistency
    LDR     r4, [r0]            ; Load current ball_y value

    CMP     r4, #0              ;
    BGE     check_y_max_boundary ;

    ; if y goes above the screen then it bounces down from the top
    ; This block handles ball_y < 0
    MOV     r4, #0              ; Set ball_y to 0
    STR     r4, [r0]            ;
    LDR     r0, =ball_vy        ; Load address of ball_vy
    LDR     r5, [r0]            ;
    RSB     r5, r5, #0          ; Reverse the velocity (rsb reverse subtract)
    STR     r5, [r0]            ;
    B       check_x_collision   ;

check_y_max_boundary
    LDR     r0, =ball_y         ; Load address of ball_y again for consistency
    LDR     r4, [r0]            ; Load current ball_y value

    CMP     r4, #MAX_Y          ;
    BLE     check_x_collision   ;

    ; else (ball_y > MAX_Y)
    MOV     r4, #MAX_Y          ; Set ball_y to MAX_Y
    STR     r4, [r0]            ;

    LDR     r0, =ball_vy        ;
    LDR     r5, [r0]            ;

    RSB     r5, r5, #0          ; Reverse the velocity
    STR     r5, [r0]            ;

check_x_collision
    ; check x boundary w/ paddle

    LDR     r0, =ball_x         ;
    LDR     r1, [r0]            ; r1 - ball_x

    CMP     r1, #0              ; checks left wall
    BNE     check_right_wall    ;

    ; check p1 paddle collision (ball_x == 0)
    LDR     r0, =ball_y         ;
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r0, =paddle1_y      ;
    LDR     r5, [r0]            ; r5 = paddle1_y

    ; check if ball_y is in paddle range
    CMP     r4, r5              ; compare ball_y w/paddle1_y
    BLT     miss_left           ;
    ADD     r6, r5, #PADDLE_HEIGHT ; r6 = paddle_y + height
    SUB     r6, r6, #1          ; r6 = paddle_y + height - 1 (last valid paddle row)
    CMP     r4, r6              ; Compare ball_y with (paddle1_y + PADDLE_HEIGHT - 1)
    BGT     miss_left           ;

    ; hit paddle reverse xv
    LDR     r0, =ball_vx        ;
    LDR     r1, [r0]            ;
    RSB     r1, r1, #0          ; Reverse horizontal velocity
    STR     r1, [r0]            ;

    ; adjust yv based on the position (0=top, 1=bottom of 2-char paddle)
    SUB     r7, r4, r5          ; r7 = hit position relative to paddle top (0 or 1)
    LDR     r0, =ball_vy        ;
    CMP     r7, #0              ;
    MOVEQ   r1, #-1             ; if hit at top of paddle (r7=0), set ball_vy to -1
    MOVNE   r1, #1              ; if hit at bottom of paddle (r7=1), set ball_vy to 1
    STR     r1, [r0]            ;

    ; move ball away from the wall
    LDR     r0, =ball_x         ;
    MOV     r1, #1              ; Move ball to X=1 to avoid re-collision with wall
    STR     r1, [r0]            ;
    B       game_done           ;

miss_left
    ; p1 missed
    BL      reset_ball          ; Reset ball position
    B       game_done           ;

check_right_wall
    LDR     r0, =ball_x         ;
    LDR     r1, [r0]            ;
    CMP     r1, #MAX_X          ; check right wall
    BNE     game_done           ;

    ; p2 paddle collision (ball_x == MAX_X)
    LDR     r0, =ball_y         ;
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r0, =paddle2_y      ;
    LDR     r5, [r0]            ; r5 = paddle2_y

    ; check if ball_y in paddle range
    CMP     r4, r5              ;
    BLT     miss_right          ;
    ADD     r6, r5, #PADDLE_HEIGHT ;
    SUB     r6, r6, #1          ;
    CMP     r4, r6              ;
    BGT     miss_right          ;

    ; hit paddle reverse xv
    LDR     r0, =ball_vx        ;
    LDR     r1, [r0]            ;
    RSB     r1, r1, #0          ; Reverse horizontal velocity
    STR     r1, [r0]            ;

    ; adjust yv based on the position
    SUB     r7, r4, r5          ; r7 = hit position (0 or 1)
    LDR     r0, =ball_vy        ;
    CMP     r7, #0              ;
    MOVEQ   r1, #-1             ;
    MOVNE   r1, #1              ;
    STR     r1, [r0]            ;

    LDR     r0, =ball_x         ;
    MOV     r1, #MAX_X-1        ; Move ball away from right wall
    STR     r1, [r0]            ;
    B       game_done           ;

miss_right
    ; p2 missed
    BL      reset_ball          ; Reset ball position
    B       game_done           ;

game_done
    POP     {r0-r7, PC}         ; Restore registers and return
    endp

    AREA    |.bss|, NOINIT, READWRITE
ball_x      SPACE   4
ball_y      SPACE   4
ball_vx     SPACE   4           ; +1 or -1 (horizontal direction)
ball_vy     SPACE   4           ; +1, 0, -1 (vertical direction)
paddle1_y   SPACE   4           ; Local paddle Y (0–3)
paddle2_y   SPACE   4           ; Remote paddle Y (0–3)

    END