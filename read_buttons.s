    AREA  JumpTable, CODE, READONLY
    EXPORT read_buttons

read_buttons 
        LDR r0, = 0x400020010 ; gpioa_IDR
        LDR r1, [r0] ; reads input state
        AND r1, r1, #0x03 ; mask pa0 and pa1 bits 0 and 1
        

