; -------------------------------
; File: game_logic.s
; Description: Update positions of paddles, ball, and detect collisions
; -------------------------------

    AREA |.text|, CODE, READONLY
    EXPORT game_update
    EXPORT game_init
    EXPORT ball_x
    EXPORT ball_y
    EXPORT paddle1_y
    EXPORT paddle2_y

        ;constants section
MAX_Y       EQU     3           ; Since it's a 4-line LCD (0–3)
MAX_X       EQU     15          ; 16 characters (0–15)
PADDLE_HEIGHT EQU   2           ; Paddle is 2 pixels tall
BALL_START_X  EQU   8           ; Center X
BALL_START_Y  EQU   2           ; Center Y

        ;data section
        AREA    |.bss|, NOINIT, READWRITE

ball_x      SPACE   4
ball_y      SPACE   4
ball_vx     SPACE   4           ; +1 or -1 (horizontal direction)
ball_vy     SPACE   4           ; +1, 0, -1 (vertical direction)
paddle1_y   SPACE   4           ; Local paddle Y (0–3)
paddle2_y   SPACE   4           ; Remote paddle Y (0–3)


    ; TODO: Define memory layout or registers for:
    ;     - Paddle 1 position
    ;     - Paddle 2 position
    ;     - Ball X/Y position and direction
    ;     - Score counters (optional)

game_int 
        push {r0-r3, LR}

        ;postion set
        ldr r0, =ball_x
        mov r1, #BALL_START_X
        str r1, [r0]

        ldr r0, =ball_y
        mov r1, #BALL_START_Y
        str r1, [r0]

        ;velocity set
        ldr r0, =ball_vx
        mov r1, #1 ; start moving to the right 
        str r1, [r0]

        ldr r0, =ball_vy
        mvn r1, #1      
        add r1, #1      ; makes it negative so it can go up 
        str r1, [r0]

        pop {r0-r2, PC}

; resets ball to center with random direction
reset_ball 
        push {r0-r2, LR}

        ldr r0, =ball_x
        mov r1, #BALL_START_X
        str r1, [r0]

        ldr r0, =ball_y
        mov r1, #BALL_START_Y
        str r1, [r0]

        ldr r0, =ball_vx
        mov r1, #1
        str r1, [r0]

        lsr r0, =ball_vy
        mvn r1, #1      
        add r1, #1      ; makes it negative so it can go up 
        str r1, [r0]

        pop {r0-r2, PC}


; TODO: game_update:
game_update
;     - Update ball position based on direction

        ;loads the balls x postion and velocity and then updates
        push {r4-r7, LR} ; begins game update logic

        ldr r0, =ball_x
        ldr r1, [r0]    ; r1= ball_x

        ldr r2, =ball_vx 
        ldr r3, [r2]    ;r3 = ball_vx

        add r1,r1,r3  ; ball_x += ballvx
        str r1, [r0]    ;stores new ball

        ;loads balls y postion and velocity and then updates

        ldr r0, =ball_y 
        ldr r4, [r0]    ;r4 = ball_y

        ldr r2, = ball_vy
        ldr r5, [r2]    ;r5 = ball_vy

        add r4, r4, r5
        str r4, [r0]    ;stores new ball_y

        ;boundy check for Y
        cmp r1, #0
        bge check_y_max

        ; if y goes above the screen then it bounces down from the top 
        mov r4, #0
        str r4, [r0]
        ldr r0, =ball_vy
        ldr r5, [r0]
        rsbs r5,r5, #0  ;reverse the velocity
        str r5, [r0]

        b check_x_collision



check_y_max


check_x_collision

;     - Check for paddle collision
;     - Check for wall/goal collision
;     - Clamp paddles within bounds
;     - Update score if ball goes out

; TODO: Provide data for lcd_render to show updated game state
