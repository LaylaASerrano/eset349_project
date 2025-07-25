	AREA    |.text|, CODE, READONLY
    ;export  __Vectors
    export  Reset_Handler
    export  main_loop
	import	gpio_init
	import  game_init
	import  i2c_init
	import  lcd_init
	import  usart_init
	import  delay_init
	import 	read_buttons
	import	send_input_uart
	import	recv_input_uart
	import	game_update
	import	lcd_render
	import  delay_ms
		

;__Vectors   DCD 0x20020000      ; init SP
            DCD Reset_Handler   ; Reset handler

Reset_Handler PROC
    PUSH    {LR}                ; Save LR for proper function context
    ; peripherals
    BL      gpio_init           ;
    BL      game_init           ;
    BL      i2c_init            ;
    BL      lcd_init            ; Added LCD initialization
    BL      usart_init          ;
    BL      delay_init          ;
    POP     {PC}                ; Return from Reset_Handler. If this were a main loop, it would loop or branch.
	ENDP

main_loop PROC
    PUSH    {LR}                ; Save LR, though this function loops back to itself
    BL      read_buttons        ;
    MOV     r1, r0              ; Pass button state (from read_buttons) to send_input_uart
    BL      send_input_uart     ;
    BL      recv_input_uart     ;
    BL      game_update         ;
    BL      lcd_render          ;
    MOV     r0, #30             ; Add a delay to control game speed (e.g., 30ms)
    BL      delay_ms            ;
    POP     {PC}                ; Pop PC to return. Then the B main_loop takes over.
    B       main_loop           ; This creates an infinite loop.
	ENDP

    END