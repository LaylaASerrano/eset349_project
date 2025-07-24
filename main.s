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
        bl gpio_init
        bl game_init
        ;bl i2c_init
        ;bl usart_init
        ;bl delay_init (optional)
        b main_loop

main_loop 
        bl read_buttons
        ;bl send_input_uart
        ;bl recv_input_uart
        bl game_update
        ;bl lcd_render
        b  main_loop

        endp
        end

        

