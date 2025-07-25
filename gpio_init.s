
	AREA |.text|, CODE, READONLY
    EXPORT gpio_init
    EXPORT read_buttons
    ; -------------------------------
    ; File: gpio_init.s
    ; Description: Initialize GPIOA pins PA0, PA1 as input and read them 
    ;              Initialize GPIOB pins PB8, PB9 as alternate function (I2C1)
    ; -------------------------------
    
gpio_init
    ; Enable GPIOA and GPIOB clocks
    ldr r0, =0x40023830    ; RCC_AHB1ENR
    ldr r1, [r0]           ; Read current value
    orr r1, r1, #0x00000003 ; Set bits for GPIOA and GPIOB
    str r1, [r0]
    
    ; Configure GPIOA
    ldr r0, =0x40020000    ; GPIOA base address
    
    ; GPIOA MODER - Configure PA0, PA1 as inputs, preserve PA13/PA14 for SWD
    ldr r1, [r0, #0x00]    ; Read current MODER value
    bic r1, r1, #0x0000000F ; Clear MODER bits for PA0, PA1 (bits 0-3)
    ; PA0 and PA1 are now inputs (00), PA13/PA14 should remain as alternate function
    str r1, [r0, #0x00]
    
    ; GPIOA PUPDR - Set pull-up for PA0 and PA1
    ldr r1, [r0, #0x0C]    ; Read current PUPDR value
    bic r1, r1, #0x0000000F ; Clear PUPDR bits for PA0, PA1
    orr r1, r1, #0x00000005 ; Set PA0 and PA1 to pull-up (01)
    str r1, [r0, #0x0C]
    
    ; Configure GPIOB for I2C1 (PB8=SCL, PB9=SDA)
    ldr r0, =0x40020400    ; GPIOB base address
    
    ; GPIOB MODER - Set PB8 and PB9 to alternate function
    ldr r1, [r0, #0x00]    ; Read current MODER value
    bic r1, r1, #0x000F0000 ; Clear MODER bits for PB8 and PB9 (bits 16-19)
    orr r1, r1, #0x000A0000 ; Set PB8 and PB9 to alternate function (10)
    str r1, [r0, #0x00]
    
    ; GPIOB AFRH - Set alternate function 4 (AF4) for I2C1
    ldr r1, [r0, #0x24]    ; Read current AFRH value (offset 0x24)
    bic r1, r1, #0x000000FF ; Clear AF bits for PB8 and PB9 (bits 0-7)
    orr r1, r1, #0x00000044 ; Set AF4 (0100) for both PB8 and PB9
    str r1, [r0, #0x24]    ; Write to AFRH
    
    ; GPIOB PUPDR - Set pull-up for PB8 and PB9
    ldr r1, [r0, #0x0C]    ; Read current PUPDR value
    bic r1, r1, #0x000F0000 ; Clear PUPDR bits for PB8 and PB9 (bits 16-19)
    orr r1, r1, #0x00050000 ; Set PB8 and PB9 to pull-up (01)
    str r1, [r0, #0x0C]
    
    bx lr                  ; Return from function
	endp
		
read_buttons
    ldr r0, =0x40020000    ; GPIOA base address
    ldr r1, [r0, #0x10]    ; Read GPIOA_IDR
    and r1, r1, #0x03      ; Mask bits 0 and 1 (PA0 and PA1)
    
    ; Check button states (assuming active low with pull-ups)
    ; Return button state in r0
    eor r0, r1, #0x03      ; Invert bits (pressed = 1, released = 0)
    
    bx lr                  ; Return from function
    endp
	end