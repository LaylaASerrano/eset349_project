    AREA |.text|, CODE, READONLY
    EXPORT gpio_init
    ; -------------------------------
    ; File: gpio_init.s
    ; Description: Initialize GPIOA pins PA0, PA1 as input and read them
    ; -------------------------------

    ; TODO: gpio_init:
    ;     - Enable GPIOA clock (RCC_AHB1ENR)
    ;     - Set PA0 and PA1 to input mode (MODER = 00)
    ;     - Optionally set pull-up/pull-down resistors (PUPDR)

    ; TODO: read_buttons:
    ;     - Read GPIOA_IDR (0x40020010)
    ;     - Mask bits 0 and 1 (for PA0/PA1)
    ;     - Return result in R1 (or R0 depending on convention)


gpio_init
        ;enable the gpio clock 
        ldr r0, =0x40023830    ; RCC_AHB1ENR
        ldr r1, #0x00000003    ; enable gpioA and gpioB
        str r1, [r0]

        ;configure pA0 and pa1 as inputs under pgioA
        ldr r0, =0x40020000     ;gpioA base address


    
        