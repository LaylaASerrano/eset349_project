    AREA |.text|, CODE, READONLY
    EXPORT gpio_init
    EXPORT read_buttons
    ; -------------------------------
    ; File: gpio_init.s
    ; Description: Initialize GPIOA pins PA0, PA1 as input and read them 
    ;              Initialise GPIOB pins PB8, PB9 as alt funtion
    ; -------------------------------
    
    ; WARNING: Only use direct LDR =value if you're sure about the full register context

    ;Summary of Critical Pins: UNSAFE PINS
    ; SWD (PA13, PA14): Essential for debugging and programming.

    ; USART (PA9, PA10 for USART1 or PA2, PA3 for USART2): Essential for serial communication.

    ; SPI (PA5, PA6, PA7 for SPI1): Important for high-speed peripheral communication.

    ; I2C (PB6, PB7 for I2C1): Important for low-speed communication with peripherals.

    ; TIM (PA0, PA1, PA2, PA3 for TIM2): Important for PWM, input capture, or other timing functions.

    ; USB OTG FS (PA11, PA12): Important for USB communication, if used.

    ; CAN (PA11, PA12): Important in automotive or industrial applications.
gpio_init
        
        ;enable the gpioA and gpioB clock 
        ldr r0, =0x40023830    ; RCC_AHB1ENR
        mov r1, #0x00000003    ; enable gpioA and gpioB
        str r1, [r0]

        ;moderA
        ;configure pA0 and pa1 as inputs under gpioA
        ldr r0, =0x40020000     ;gpioA_MODER
        mov r1, #0x28000000     ;pa0/pa1 = 00 pa13 and pa14 need to be in alt mode
        str r1, [r0, #0x00]

        ; pull up for gpioA
        ldr r1, =0x00000002     ;pa0 up and pa1 up 
        str r1, [r0, #0x0C]     ;gpioA_PUPDR

        ;moderB (ASK ABOUT THIS PART)
        ;configure pb8 and pb9 ( i2c1_scl and i2c1_sda)
        ldr r0, =0x40020400     ;gpioB base address
        mov r1, #0x00280000     ;set as pb8 and pb9 to alt function for i2c (MAKE SURE TO COMMENT OUT FOR PROJECT BOARD 2) 
        str r1, [r0, #0x00]

        ;set pb8 and pb9 to AF4 
        ldr r1, =0x00000044
        str r1, [r0, #0x20]


        ;pullup for gpioB
        ldr r1, =0x00050000
        str r1, [r0, #0x0C]    ;gpioB_PUPDR 


read_buttons
        ldr r0, =0x40020010    ;GPIOA_IDR
        ldr r2, [r0, #0x10]    ;Read GPIOA_IDR 
        and r2, r2, #0x03      ;Mask bits 0 and 1 (for PA0/PA1)
        cmp r2, #0x03          ;compare to high
        str r1, [r2]           ;Return result in R1 (or R0 depending on convention)

        endp
        end



