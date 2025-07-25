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

; NOTE: may want to subroutine some of theses branches but im not sure how to efficantly do that


game_init
        push {r0-r3, LR}

        ;position set
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
        mov r1, #-1            ; Corrected: mvn r1, #0 sets r1 to -1. mov r1, #-1 is clearer.
        str r1, [r0]

        pop {r0-r3, PC}        ; Corrected: Pop r0-r3 (as pushed), not r0-r2.

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

        ldr r0, =ball_vy
        mov r1, #-1          ; Corrected: mvn r1, #0 sets r1 to -1. mov r1, #-1 is clearer.
        str r1, [r0]

        pop {r0-r2, PC}

; TODO: game_update:
game_update
;     - Update ball position based on direction

        ;loads the balls x postion and velocity and then updates
        push {r0-r7, LR} ; Corrected: Push all used registers and LR. Original only pushed r4-r7.

        ldr r0, =ball_x
        ldr r1, [r0]    ; r1= ball_x

        ldr r2, =ball_vx
        ldr r3, [r2]    ;r3 = ball_vx

        add r1,r1,r3  ; ball_x += ballvx
        str r1, [r0]    ;stores new ball_x

        ;loads balls y postion and velocity and then updates

        ldr r0, =ball_y
        ldr r4, [r0]    ;r4 = ball_y

        ldr r2, = ball_vy
        ldr r5, [r2]    ;r5 = ball_vy

        add r4, r4, r5
        str r4, [r0]    ;stores new ball_y

        ;boundary check for Y
        ldr r0, =ball_y ; Load address of ball_y again for consistency
        ldr r4, [r0]    ; Load current ball_y value

        cmp r4, #0
        bge check_y_max_boundary ; Corrected: Branch to a distinct label for clarity

        ; if y goes above the screen then it bounces down from the top
        ; This block handles ball_y < 0
        mov r4, #0
        str r4, [r0]            ; Set ball_y to 0
        ldr r0, =ball_vy        ; Load address of ball_vy
        ldr r5, [r0]
        rsbs r5, r5, #0         ; Reverse the velocity (rsbs reverse subtract)
        str r5, [r0]
        b check_x_collision     ; Jump to X collision check

check_y_max_boundary: ; Corrected: New label for max Y check
        ldr r0, =ball_y ; Load address of ball_y again for consistency
        ldr r4, [r0]    ; Load current ball_y value

        cmp r4, #MAX_Y
        ble check_x_collision ; branch if less or equal to MAX_Y

        ;else (ball_y > MAX_Y)
        mov r4, #MAX_Y
        str r4, [r0]            ; Set ball_y to MAX_Y

        ldr r0, =ball_vy
        ldr r5, [r0]

        rsbs r5, r5, #0         ; Reverse the velocity
        str r5, [r0]

check_x_collision
        ; check x boundary w/ paddle

        ldr r0, = ball_x
        ldr r1, [r0]                    ;r1 - ball_x

        cmp r1, #0      ;checks left wall
        bne check_right_wall ; branch if not equal (if not at left wall)

        ;check p1 paddle collision (ball_x == 0)
        ldr r0, = ball_y
        ldr r4, [r0]                    ;r4 = ball_y
        ldr r0, =paddle1_y
        ldr r5, [r0]                    ;r5 = paddle1_y

        ;check if ball_y is in paddle range
        cmp r4, r5                      ;compare ball_y w/paddle1_y
        blt miss_left                   ;branch if ball_y < paddle1_y
        add r6, r5, #PADDLE_HEIGHT
        sub r6, r6, #1                  ; r6 = paddle_y + height - 1
        cmp r4, r6                      ; Compare ball_y with (paddle1_y + PADDLE_HEIGHT - 1)
        bgt miss_left                   ; branch if ball_y > paddle1_y_bottom

        ;hit paddle reverse xv
        ldr r0, =ball_vx
        ldr r1, [r0]
        rsbs r1, r1, #0
        str r1, [r0]

        ;adjust yv based on the position
        sub r7, r4, r5                  ; r7 = hit position relative to paddle top (0 or 1)
        ldr r0, =ball_vy
        cmp r7, #0
        moveq r1, #-1                   ; if hit at top of paddle (r7=0), set ball_vy to -1
        movne r1, #1                    ; if hit at bottom of paddle (r7=1), set ball_vy to 1
        str r1, [r0]

        ;move ball away from the wall
        ldr r0, =ball_x
        mov r1, #1                      ; Move ball to X=1 to avoid re-collision with wall
        str r1, [r0]
        b done

miss_left
        ; p1 missed
        bl reset_ball ; branch link reset ball
        b done

check_right_wall
        ldr r0, =ball_x
        ldr r1, [r0]
        cmp r1, #MAX_X  ;check right wall
        bne done        ; If not at MAX_X, no collision with right wall/paddle

        ; p2 paddle collision (ball_x == MAX_X)
        ldr r0, =ball_y
        ldr r4, [r0]                    ;r4 = ball_y
        ldr r0, =paddle2_y              ; Corrected: Use paddle2_y for right paddle
        ldr r5, [r0]                    ;r5 = paddle2_y

        ;check if ball_y in paddle range
        cmp r4, r5
        blt miss_right
        add r6, r5, #PADDLE_HEIGHT
        sub r6, r6, #1
        cmp r4, r6
        bgt miss_right

        ;hit paddle reverse xv
        ldr r0, =ball_vx
        ldr r1, [r0]
        rsbs r1, r1, #0
        str r1, [r0]

        ;adjust yv based on the position
        sub r7, r4, r5 ;r7 = hit postion (0 or 1)
        ldr r0, =ball_vy
        cmp r7, #0
        moveq r1, #-1
        movne r1, #1
        str r1, [r0]


        ldr r0, =ball_x
        mov r1, #MAX_X-1                ; Move ball away from right wall
        str r1, [r0]
        b done

miss_right
        ;p2 missed
        bl reset_ball
        b done ; Corrected: Added 'done' to jump after reset_ball

done
        pop {r0-r7, PC} ; Corrected: Pop all registers pushed at the start

;TODO: Provide data for lcd_render to show updated game state. !!!