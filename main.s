    AREA  RESET, DATA, READONLY
    EXPORT __Vectors
    ; -------------------------------
    ; File: main.s
    ; Description: Startup vector, initialization, and game loop
    ; -------------------------------

    ; TODO: Define __Vectors section with initial SP and Reset_Handler
    ; TODO: Implement Reset_Handler:
    ;     - BL gpio_init
    ;     - BL i2c_init
    ;     - BL usart_init
    ;     - BL delay_init (optional)
    ;     - Enter main_loop
    ;
    ; TODO: In main_loop:
    ;     - BL read_buttons
    ;     - BL send_input_uart
    ;     - BL recv_input_uart
    ;     - BL game_update
    ;     - BL lcd_render
    ;     - B  main_loop

__Vectors 
        DCD 0x20020000      ;init SP 
        DCD Reset_Handler   ;Reset handler

        AREA |.text|, CODE, READONLY
        EXPORT Reset_Handler
        ALIGN Reset_Handler
        ALIGN

Reset_Handler 

        ;perpherals
        BL gpio_init ;dontchange
        BL i2C_init 
        BL usart_init 
        BL delay_init
        BL game_init  ;dontchange

main_loop 
        BL read_buttons
        BL game_update
        BL send_recive_wifi 
        B main_loop

        END

        

