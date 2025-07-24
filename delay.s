; -------------------------------
; File: delay.s. (optional file may or may not use/need)
; Description: Millisecond or microsecond delays using loop or SysTick
; -------------------------------

; TODO: delay_init:
;     - Set up SysTick or use CPU clock for timing loops

; TODO: delay_ms:
;     - Accept R0 = number of ms
;     - Implement a simple loop or SysTick wait

; TODO: delay_us:
;     - Accept R0 = number of µs
;     - Shorter delay loop for fine-tuning

; -------------------------------
; [Tharun Delay 1.0]

     AREA |.text|, CODE, READONLY

; delay_init
  
    EXPORT delay_init
delay_init
    BX LR

; delay_ms [R0 = # of ms]

    EXPORT delay_ms
delay_ms    




     EXPORT delay_ms

delay_ms
     PUSH {R4, LR}          ; Save R4 and LR on stack
     MOV R4, R0            ; Move delay count to R4 
        MOV R0, #0            ; Clear R0 for loop counter
delay_loop_ms
     CMP R0, R4            ; Compare loop counter with delay count
     BGE end_delay_ms       ; If loop counter >= delay count, exit loop
     NOP                    ; No operation (can be replaced with actual delay logic)
     ADD R0, R0, #1         ; Increment loop counter
     B delay_loop_ms        ; Repeat the loop
end_delay_ms
        POP {R4, PC}          ; Restore R4 and return from function

    EXPORT delay_init
delay_init
     BX LR 
        




