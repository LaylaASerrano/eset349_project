    AREA |.text|, CODE, READONLY
    EXPORT gpio_init

gpio_init
        ;enable the gpio clock 
        ldr r0, =0x40023830    ; RCC_AHB1ENR
        ldr r1, #0x00000003    ; enable gpioA and gpioB
        str r1, [r0]
        