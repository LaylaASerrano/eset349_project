	AREA    |.text|, CODE, READONLY
    EXPORT  delay_init
    EXPORT  delay_ms
    EXPORT  delay_us

; delay_init
delay_init PROC
    PUSH    {r0, r1, LR}        ; Push registers
    ; Configure SysTick for 1ms interrupts (assuming 16MHz CPU clock)
    ; SysTick_LOAD = (CPU_CLOCK / 1000) - 1
    ; For 16MHz, SysTick_LOAD = (16000000 / 1000) - 1 = 15999
    LDR     r0, =0xE000E014     ; SysTick_LOAD register address
    LDR     r1, =15999          ; 16MHz / 1kHz - 1
    STR     r1, [r0]

    ; SysTick_VAL = 0 (clear current value)
    LDR     r0, =0xE000E018     ; SysTick_VAL register address
    MOV     r1, #0
    STR     r1, [r0]

    ; SysTick_CTRL: Enable SysTick, Enable SysTick Interrupt, Use processor clock
    ; CTRL bits: 0=ENABLE, 1=TICKINT, 2=CLKSOURCE
    LDR     r0, =0xE000E010     ; SysTick_CTRL register address
    MOV     r1, #7              ; (1<<0) | (1<<1) | (1<<2)
    STR     r1, [r0]

    POP     {r0, r1, PC}        ; Pop registers and return

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

; -----------------------------------------------------------------------------
; SysTick_Handler: Increments the global millisecond counter.
; This needs to be exported and placed in the vector table in your startup file.
; -----------------------------------------------------------------------------
    EXPORT  SysTick_Handler
SysTick_Handler PROC
    PUSH    {R0, LR}            ; Save R0 and LR
    LDR     R0, =g_ms_ticks     ; Load address of g_ms_ticks
    LDR     R1, [R0]            ; Load current value of g_ms_ticks
    ADD     R1, R1, #1          ; Increment by 1
    STR     R1, [R0]            ; Store back
    POP     {R0, PC}            ; Restore R0 and return from interrupt
    ENDP

; --- Global Millisecond Tick Counter ---
    AREA    |.bss_delay|, NOINIT, READWRITE
    EXPORT  g_ms_ticks
g_ms_ticks          DCD     0
    ALIGN

    END