	AREA    |.text|, CODE, READONLY
    export  gpio_init
    export  read_buttons

gpio_init PROC
    PUSH    {r0, r1, LR}        ; Save registers and LR
    ; ... (rest of gpio_init code as previously provided) ...
    ; No change in the logic for GPIO configuration from the previous version.
    ; The redundancy with I2C config remains as noted.
    ; Enable GPIOA and GPIOB clocks
    LDR     r0, =0x40023830     ; RCC_AHB1ENR
    LDR     r1, [r0]            ; Read current value
    ORR     r1, r1, #0x00000003 ; Set bits for GPIOA (bit 0) and GPIOB (bit 1)
    STR     r1, [r0]            ;

    ; Configure GPIOA
    LDR     r0, =0x40020000     ; GPIOA base address

    ; GPIOA MODER - Configure PA0, PA1 as inputs, preserve PA13/PA14 for SWD
    LDR     r1, [r0, #0x00]     ; Read current MODER value
    BIC     r1, r1, #0x0000000F ; Clear MODER bits for PA0, PA1 (bits 0-3) (00 for input mode)
    STR     r1, [r0, #0x00]     ;

    ; GPIOA PUPDR - Set pull-up for PA0 and PA1
    LDR     r1, [r0, #0x0C]     ; Read current PUPDR value
    BIC     r1, r1, #0x0000000F ; Clear PUPDR bits for PA0, PA1
    ORR     r1, r1, #0x00000005 ; Set PA0 and PA1 to pull-up (01)
    STR     r1, [r0, #0x0C]     ;

    ; Configure GPIOB for I2C1 (PB8=SCL, PB9=SDA)
    LDR     r0, =0x40020400     ; GPIOB base address

    ; GPIOB MODER - Set PB8 and PB9 to alternate function
    LDR     r1, [r0, #0x00]     ; Read current MODER value
    BIC     r1, r1, #0x000F0000 ; Clear MODER bits for PB8 and PB9 (bits 16-19)
    ORR     r1, r1, #0x000A0000 ; Set PB8 and PB9 to alternate function (10)
    STR     r1, [r0, #0x00]     ;

    ; GPIOB AFRH - Set alternate function 4 (AF4) for I2C1
    LDR     r1, [r0, #0x24]     ; Read current AFRH value (offset 0x24)
    BIC     r1, r1, #0x000000FF ; Clear AF bits for PB8 and PB9 (bits 0-7)
    ORR     r1, r1, #0x00000044 ; Set AF4 (0100) for both PB8 and PB9
    STR     r1, [r0, #0x24]     ;

    POP     {r0, r1, PC}        ; Restore registers and return
    ENDP

read_buttons PROC
    PUSH    {r1, LR}            ; Save r1 and LR

    LDR     r0, =0x40020000     ; GPIOA base address
    LDR     r1, [r0, #0x10]     ; Read GPIOA_IDR
    AND     r1, r1, #0x03       ; Mask bits 0 and 1 (PA0 and PA1)

    ; Check button states (assuming active low with pull-ups)
    ; Return button state in r0
    EOR     r0, r1, #0x03       ; Invert bits (pressed = 1, released = 0)

    POP     {r1, PC}            ; Restore r1 and return
    ENDP

    END