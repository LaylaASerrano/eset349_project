	AREA    |.text|, CODE, READONLY
    export  delay_init
    export  delay_ms
    export  delay_us

; delay_init
delay_init PROC
    PUSH    {LR}    ; Always push LR for proper function return
    BX      LR
    POP     {PC}    ; Pop PC to return from function
ENDP

; delay_ms [register 0 is # of ms]
; Calibrated for 16MHz clock (adjust R1 literal for different clocks)
delay_ms PROC
    PUSH    {r1, LR}            ; Push r1 and LR for proper context saving
ms_outer_loop
    CMP     r0, #0
    BEQ     ms_done

    MOV     r1, #8000           ; Calibrated for 16MHz clock to achieve ~1ms delay.

ms_inner_loop
    SUBS    r1, r1, #1
    BNE     ms_inner_loop

    SUBS    r0, r0, #1
    B       ms_outer_loop

ms_done
    POP     {r1, PC}            ; Pop r1 and PC to restore and return
    ENDP

; delay_us [optional we probably won't need for such finetuning?]
; Calibrated for 16MHz clock
delay_us PROC
    PUSH    {r1, LR}            ; Push r1 and LR for proper context saving
us_outer_loop
    CMP     r0, #0
    BEQ     us_done

    MOV     r1, #8              ; Calibrated for 16MHz clock to achieve ~1us delay.

us_inner_loop
    SUBS    r1, r1, #1
    BNE     us_inner_loop

    SUBS    r0, r0, #1
    B       us_outer_loop

us_done
    POP     {r1, PC}            ; Pop r1 and PC to restore and return
    ENDP

    END