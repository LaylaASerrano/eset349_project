	AREA    |.text|, CODE, READONLY
    EXPORT  delay_ms
    EXPORT  delay_us
    EXPORT  Get_ms_ticks ; Function to get ms ticks from C

; -----------------------------------------------------------------------------
; delay_ms: Provides a blocking delay in milliseconds.
; R0 = number of milliseconds to delay.
; Calibrated for 16MHz clock (relies on g_ms_ticks incremented by SysTick at 1ms interval).
; -----------------------------------------------------------------------------
delay_ms PROC
    PUSH    {R1, R2, LR}        ; Save R1, R2, and Link Register

    MOV     R2, R0              ; Save the desired delay duration (ms) in R2
    LDR     R1, =g_ms_ticks     ; Load address of g_ms_ticks into R1
    LDR     R0, [R1]            ; Load current g_ms_ticks into R0 (start_time)
    ADD     R0, R0, R2          ; Calculate target_time = start_time + delay_ms (R0 now holds target_time)

delay_ms_loop
    LDR     R2, [R1]            ; Load current g_ms_ticks into R2
    CMP     R2, R0              ; Compare current_time (R2) with target_time (R0)
    BLT     delay_ms_loop       ; Loop while current_time < target_time

    POP     {R1, R2, PC}        ; Restore R1, R2, and return
	ENDP

; -----------------------------------------------------------------------------
; delay_us: Provides a blocking delay in microseconds.
; R0 = number of microseconds to delay.
; Calibrated for 16MHz clock (adjust loop count for different clocks).
; This is a busy-wait loop.
; -----------------------------------------------------------------------------
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

; -----------------------------------------------------------------------------
; Get_ms_ticks: Function to make g_ms_ticks accessible from C.
; Returns the current value of g_ms_ticks in R0.
; -----------------------------------------------------------------------------
Get_ms_ticks PROC
    LDR R0, =g_ms_ticks
    LDR R0, [R0]        ; Load the current tick count into R0 for return
    BX LR               ; Return to caller (C function)
	ENDP



; --- Global Millisecond Tick Counter ---
; Keep this single definition for g_ms_ticks in the BSS section
	AREA    |.bss_delay|, NOINIT, READWRITE
    EXPORT  g_ms_ticks
g_ms_ticks          DCD     0
    ALIGN

    END