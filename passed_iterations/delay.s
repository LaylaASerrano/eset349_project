	AREA    |.text|, CODE, READONLY
    ; EXPORT  delay_ms         ; REMOVE THIS
    EXPORT  delay_us
    ; EXPORT  Get_ms_ticks     ; REMOVE THIS


delay_us PROC
    PUSH    {R1, LR}            ; Push R1 and LR for proper context saving

us_outer_loop
    CMP     R0, #0
    BEQ     us_done             ; If R0 is 0, delay is done

    MOV     R1, #8              ; Calibrated for 16MHz clock to achieve ~1us delay.
                                ; (Each iteration of inner loop takes a few cycles)
us_inner_loop
    SUBS    R1, R1, #1          ; Decrement R1
    BNE     us_inner_loop       ; Loop until R1 is 0

    SUBS    R0, R0, #1          ; Decrement outer loop counter
    B       us_outer_loop       ; Loop until R0 is 0

us_done
    POP     {R1, PC}            ; Restore R1 and return
	ENDP



    END