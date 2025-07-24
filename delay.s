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
; [Tharun Delay 1.2]
; -------------------------------
    AREA |.text|, CODE, READONLY

; delay_init
    EXPORT  delay_init
delay_init
     BX LR


; delay_ms [register 0 is # of ms]
    EXPORT delay_ms
delay_ms

ms_outer_loop
    CMP r0, #0
    BEQ ms_done                              ; if r0 == 0 exit loop
   
    MOV r1, #8000                            ; need to adjust this when we flash and test

ms_inner_loop
    SUBS r1, r1, #1                          ; decrement r1 by 1
    BNE ms_inner_loop                        ; if != 0 
   
    SUBS r0, r0 , #1                         ; decrement r0 by 1
    B ms_outer_loop                          ; repeat outer loop again

ms_done
    BX LR                                    ; return from function



; delay_us [optional we probably won't need for such finetuning?]

    EXPORT delay_us
delay_us

us_outer_loop
    CMP r0, #0
    BEQ us_done                             ; if r0 == 0 i.e. if done exit
   
    MOV r1, #8                              ; we need to adjust this up or down depending on the actual clock

us_inner_loop
    SUBS r1, r1, #1                         ; decrement r1 by 1
    BNE us_inner_loop                       ; loop until r1 == 0

    SUBS r0, r0, #1                         ; decrement r0 by 1
    B us_outer_loop                         ; repeat outer again

us_done
    BX LR                                   ; return from function