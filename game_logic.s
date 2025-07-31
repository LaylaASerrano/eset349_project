	AREA    |.text|, CODE, READONLY
    export  game_update
    export  game_init
    export  reset_ball

    ; Export global variables to other assembly files and C
    EXPORT  ball_x
    EXPORT  ball_y
    EXPORT  ball_vx
    EXPORT  ball_vy
    EXPORT  paddle1_y
    EXPORT  paddle2_y

    ; constants section
MAX_Y          EQU     1           ; Max Y-coordinate for the ball (0-1 for 2 lines) 
MAX_X          EQU     15          ; 16 characters (0–15) 
PADDLE_HEIGHT  EQU     1           ; Paddle is 1 character tall 
BALL_START_X   EQU     8           ; Center X 
BALL_START_Y   EQU     0           ; Changed to 0 as per comment 

; New constant for paddle max Y, consistent with 2-line game (0 or 1)
MAX_PADDLE_Y_GAME_POS EQU 1 ; If game is 2 lines (Y=0, Y=1) 
                           ; Note: main.s uses MAX_PADDLE_Y_POS which is 2.
                           ; This implies MAX_PADDLE_Y_POS in main.s is for a 4-line display,
                           ; but the game logic here is for 2 lines. This is a crucial design decision.
                           ; Let's assume the game is 2-lines (0,1) and paddles occupy 1 line within it.

game_init PROC
    PUSH    {r0-r3, LR}         ; Save registers and LR

    ; position set
    LDR     r0, =ball_x         ;
    MOV     r1, #BALL_START_X   ;
    STR     r1, [r0]            ; Initialize ball_x 

    LDR     r0, =ball_y         ;
    MOV     r1, #BALL_START_Y   ;
    STR     r1, [r0]            ; Initialize ball_y (now 0) 

    ; velocity set
    LDR     r0, =ball_vx        ;
    MOV     r1, #1              ; start moving to the right 
    STR     r1, [r0]            ;

    LDR     r0, =ball_vy        ;
    MOV     r1, #1              ; Changed to 1: start moving DOWN (away from y=0) 
    STR     r1, [r0]            ;

    ; Initialize paddle positions
    LDR     r0, =paddle1_y      ;
    MOV     r1, #0              ; Initial position for paddle1_y (e.g., top of screen, or center if MAX_PADDLE_Y_GAME_POS allows) 
    STR     r1, [r0]            ;

    LDR     r0, =paddle2_y      ;
    MOV     r1, #0              ; Initial position for paddle2_y 
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
    LDR     r0, =ball_x         ;
    LDR     r1, [r0]            ; r1 = ball_x 
    LDR     r2, =ball_vx        ;
    LDR     r3, [r2]            ; r3 = ball_vx 
    ADD     r1, r1, r3          ; ball_x += ballvx
    STR     r1, [r0]            ; stores new ball_x

    ; Update ball Y position
    LDR     r0, =ball_y         ;
    LDR     r4, [r0]            ; r4 = ball_y 
    LDR     r2, =ball_vy        ;
    LDR     r5, [r2]            ; r5 = ball_vy 
    ADD     r4, r4, r5          ; ball_y += ball_vy
    STR     r4, [r0]            ; stores new ball_y

    ; --- Implement "Random" Bounces (before boundary checks) ---
    ; This is an example, you need to add all your specific rules here
    ; For (3,0) and moving left -> (4,1) and still moving right (as per your comment)
    LDR     r0, =ball_x
    LDR     r1, [r0]            ; r1 = current ball_x
    LDR     r2, =ball_y
    LDR     r3, [r2]            ; r3 = current ball_y
    LDR     r4, =ball_vx
    LDR     r5, [r4]            ; r5 = current ball_vx
    LDR     r6, =ball_vy
    LDR     r7, [r6]            ; r7 = current ball_vy

    ; Condition: ball_x == 3 && ball_y == 0 && ball_vx == -1 (moving left)
    CMP     r1, #3
    BNE     check_random_2      ; Not at X=3
    CMP     r3, #0
    BNE     check_random_2      ; Not at Y=0
    CMP     r5, #-1
    BNE     check_random_2      ; Not moving left

    ; Apply bounce rule for (3,0) moving left
    ADD     r1, r1, #1          ; ball_x = 4 (ball moves one step right from 3)
    STR     r1, [r0]

    ADD     r3, r3, #1          ; ball_y = 1
    STR     r3, [r2]

    MOV     r5, #1              ; ball_vx = 1 (moving right)
    STR     r5, [r4]

    MOV     r7, #1              ; ball_vy = 1 (bounces down)
    STR     r7, [r6]
    B       post_random_bounce  ; Skip other random checks

check_random_2
    ; Condition: ball is (9,1) and ball is moving right then bound up
    ; (9,1) moving right -> (10,0) and still moving right
    CMP     r1, #9
    BNE     check_random_3
    CMP     r3, #1
    BNE     check_random_3
    CMP     r5, #1
    BNE     check_random_3

    ; Apply bounce rule for (9,1) moving right
    ADD     r1, r1, #1          ; ball_x = 10
    STR     r1, [r0]

    SUB     r3, r3, #1          ; ball_y = 0 (bounces up)
    STR     r3, [r2]

    ; ball_vx stays the same (r5 is already 1)
    MOV     r7, #-1             ; ball_vy = -1 (bounces up)
    STR     r7, [r6]
    B       post_random_bounce

check_random_3
    ; Condition: ball position (6,1) and ball is moving left then bounce up
    ; (6,1) moving left -> (5,0) and still moving left
    CMP     r1, #6
    BNE     check_random_4
    CMP     r3, #1
    BNE     check_random_4
    CMP     r5, #-1
    BNE     check_random_4

    ; Apply bounce rule for (6,1) moving left
    SUB     r1, r1, #1          ; ball_x = 5
    STR     r1, [r0]

    SUB     r3, r3, #1          ; ball_y = 0 (bounces up)
    STR     r3, [r2]

    ; ball_vx stays the same (r5 is already -1)
    MOV     r7, #-1             ; ball_vy = -1 (bounces up)
    STR     r7, [r6]
    B       post_random_bounce

check_random_4
    ; Condition: ball position (12,0) and ball is moving left then bounce down
    ; (12,0) moving left -> (11,1) and still moving left
    CMP     r1, #12
    BNE     post_random_bounce ; No more random checks
    CMP     r3, #0
    BNE     post_random_bounce
    CMP     r5, #-1
    BNE     post_random_bounce

    ; Apply bounce rule for (12,0) moving left
    SUB     r1, r1, #1          ; ball_x = 11
    STR     r1, [r0]

    ADD     r3, r3, #1          ; ball_y = 1 (bounces down)
    STR     r3, [r2]

    ; ball_vx stays the same (r5 is already -1)
    MOV     r7, #1              ; ball_vy = 1 (bounces down)
    STR     r7, [r6]

post_random_bounce
    ; Reload current ball_x, ball_y, ball_vx, ball_vy after potential random bounce
    ; This is important because the random bounce might have altered them.
    LDR     r0, =ball_x
    LDR     r1, [r0]            ; r1 = ball_x
    LDR     r0, =ball_y
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r0, =ball_vx
    LDR     r3, [r0]            ; r3 = ball_vx
    LDR     r0, =ball_vy
    LDR     r5, [r0]            ; r5 = ball_vy


    ; boundary check for Y (top/bottom walls)
    CMP     r4, #0              ; If ball_y < 0
    BLT     bounce_y_top        ;

    CMP     r4, #MAX_Y          ; If ball_y > MAX_Y
    BGT     bounce_y_bottom     ;

    B       check_x_collision   ; No Y-boundary collision, proceed to X

bounce_y_top
    MOV     r4, #0              ; Set ball_y to 0
    STR     r4, [r0]            ; (r0 holds ball_y address)
    LDR     r0, =ball_vy        ; Load address of ball_vy
    LDR     r5, [r0]            ;
    RSB     r5, r5, #0          ; Reverse the velocity (e.g., -1 becomes 1)
    STR     r5, [r0]            ;
    B       check_x_collision   ; Continue to X collision check

bounce_y_bottom
    MOV     r4, #MAX_Y          ; Set ball_y to MAX_Y
    STR     r4, [r0]            ; (r0 holds ball_y address)
    LDR     r0, =ball_vy        ; Load address of ball_vy
    LDR     r5, [r0]            ;
    RSB     r5, r5, #0          ; Reverse the velocity (e.g., 1 becomes -1)
    STR     r5, [r0]            ;

check_x_collision
    ; check x boundary with paddles

    LDR     r0, =ball_x         ;
    LDR     r1, [r0]            ; r1 = ball_x (re-loaded after y-checks)

    CMP     r1, #0              ; checks left wall (player 1's side)
    BNE     check_right_wall    ; Not at left wall

    ; Check P1 paddle collision (ball_x == 0)
    LDR     r0, =ball_y         ;
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r0, =paddle1_y      ;
    LDR     r5, [r0]            ; r5 = paddle1_y

    ; Check if ball_y is in paddle range
    ; Paddle occupies y to y + PADDLE_HEIGHT - 1
    CMP     r4, r5              ; Compare ball_y with paddle1_y (top of paddle)
    BLT     miss_left           ; Ball is above paddle (miss)
    ADD     r6, r5, #PADDLE_HEIGHT ; r6 = paddle_y + height
    SUB     r6, r6, #1          ; r6 = paddle_y + height - 1 (last valid paddle row)
    CMP     r4, r6              ; Compare ball_y with bottom of paddle
    BGT     miss_left           ; Ball is below paddle (miss)

    ; HIT: Reverse horizontal velocity (ball_vx)
    LDR     r0, =ball_vx        ;
    LDR     r1, [r0]            ;
    RSB     r1, r1, #0          ; Reverse the velocity (e.g., -1 becomes 1)
    STR     r1, [r0]            ;

    ; Adjust vertical velocity (ball_vy) based on hit position
    SUB     r7, r4, r5          ; r7 = hit position relative to paddle top (0 or 1)
    LDR     r0, =ball_vy        ;
    CMP     r7, #0              ; If hit at top of paddle segment (r7=0)
    MOVEQ   r1, #-1             ; Set ball_vy to -1 (bounces up)
    MOVNE   r1, #1              ; Else (hit at bottom segment, r7=1), set ball_vy to 1 (bounces down)
    STR     r1, [r0]            ;

    ; Move ball away from the wall to prevent re-collision
    LDR     r0, =ball_x         ;
    MOV     r1, #1              ; Move ball to X=1
    STR     r1, [r0]            ;
    B       game_done           ; Collision handled

miss_left
    ; Player 1 missed the ball
    ; This is where Player 2 scores a point.
    BL      reset_ball          ; Reset ball position for new round
    B       game_done           ;

check_right_wall
    LDR     r0, =ball_x         ;
    LDR     r1, [r0]            ;
    CMP     r1, #MAX_X          ; Check right wall (player 2's side)
    BNE     game_done           ; Not at right wall

    ; Check P2 paddle collision (ball_x == MAX_X)
    LDR     r0, =ball_y         ;
    LDR     r4, [r0]            ; r4 = ball_y
    LDR     r0, =paddle2_y      ;
    LDR     r5, [r0]            ; r5 = paddle2_y

    ; Check if ball_y in paddle range
    CMP     r4, r5              ; Compare ball_y with paddle2_y (top of paddle)
    BLT     miss_right          ; Ball is above paddle (miss)
    ADD     r6, r5, #PADDLE_HEIGHT ; r6 = paddle_y + height
    SUB     r6, r6, #1          ; r6 = paddle_y + height - 1 (last valid paddle row)
    CMP     r4, r6              ; Compare ball_y with bottom of paddle
    BGT     miss_right          ; Ball is below paddle (miss)

    ; HIT: Reverse horizontal velocity (ball_vx)
    LDR     r0, =ball_vx        ;
    LDR     r1, [r0]            ;
    RSB     r1, r1, #0          ; Reverse horizontal velocity (e.g., 1 becomes -1)
    STR     r1, [r0]            ;

    ; Adjust vertical velocity (ball_vy) based on hit position
    SUB     r7, r4, r5          ; r7 = hit position relative to paddle top (0 or 1)
    LDR     r0, =ball_vy        ;
    CMP     r7, #0              ; If hit at top of paddle segment (r7=0)
    MOVEQ   r1, #-1             ; Set ball_vy to -1 (bounces up)
    MOVNE   r1, #1              ; Else (hit at bottom segment, r7=1), set ball_vy to 1 (bounces down)
    STR     r1, [r0]            ;

    ; Move ball away from the wall
    LDR     r0, =ball_x         ;
    MOV     r1, #MAX_X-1        ; Move ball to X=MAX_X-1
    STR     r1, [r0]            ;
    B       game_done           ; Collision handled

miss_right
    ; Player 2 missed the ball
    ; This is where Player 1 scores a point.
    BL      reset_ball          ; Reset ball position for new round
    B       game_done           ;

game_done
    POP     {r0-r7, PC}         ; Restore registers and return
	ENDP
	
	align 4
    AREA    |.bss|, NOINIT, READWRITE
    EXPORT  ball_x
    EXPORT  ball_y
    EXPORT  ball_vx
    EXPORT  ball_vy
    EXPORT  paddle1_y
    EXPORT  paddle2_y

ball_x      SPACE   4           ; Allocate 4 bytes for ball_x
ball_y      SPACE   4           ; Allocate 4 bytes for ball_y
ball_vx     SPACE   4           ; +1 or -1 (horizontal direction) 
ball_vy     SPACE   4           ; +1, 0, -1 (vertical direction) 
paddle1_y   SPACE   4           ; Corrected to 4 bytes (DCD equivalent) 
paddle2_y   SPACE   4           ; Corrected to 4 bytes (DCD equivalent) 
	align 
    END