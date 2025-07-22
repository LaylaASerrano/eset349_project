    AREA  RESET, DATA, READONLY
    EXPORT __Vectors

__Vectors 
        DCD 0x20020000      ;init SP 
        DCD Reset_Handler   ;Reset handler

        AREA |.text|, CODE, READONLY
        EXPORT Reset_Handler
        ALIGN Reset_Handler
        ALIGN

Reset_Handler 

        ;perpherals
        BL gpio_init 
        BL i2C_init 
        BL usart_init 
        BL delay_init

main_loop 
        BL read_buttons
        BL game_update
        BL send_recive_wifi 
        B main_loop

        END

        

