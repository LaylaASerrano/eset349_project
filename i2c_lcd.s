	AREA    |.text|, CODE, READONLY
    export  i2c_init
    export  lcd_init
    export  lcd_send_cmd
    export  lcd_send_data
    export  lcd_render

    IMPORT  ball_x
    IMPORT  ball_y
    IMPORT  paddle1_y
    IMPORT  paddle2_y
    IMPORT  delay_ms

LCD_ADDR EQU 0x27

; -------------------------------
; i2c_init: enable gpiob | enable i2c1 | configure pb8/pb9
; -------------------------------

i2c_init PROC
    PUSH    {r0, r1, LR}        ; Save registers and LR

    ; enable clocks

    ; GPIOB clock
    LDR     r0, =0x40023830     ; RCC_AHB1ENR
    LDR     r1, [r0]            ;
    ORR     r1, r1, #(1 << 1)   ; set bit to enable gpiob
    STR     r1, [r0]            ;

    ; i2c1 clock
    LDR     r0, =0x40023840     ; RCC_APB1ENR
    LDR     r1, [r0]            ;
    ORR     r1, r1, #(1 << 21)  ; Enable I2C1 clock
    STR     r1, [r0]            ;

    ; configure PB8 & PB9 as AF4
    LDR     r0, =0x40020400     ; GPIOB base address
    LDR     r1, [r0, #0x00]     ; Read current MODER value
    BIC     r1, r1, #(0xF << 16) ; Clear bits MODER8 and 9
    ORR     r1, r1, #(0xA << 16) ; Set to af mode (10b) for PB8, PB9
    STR     r1, [r0, #0x00]     ; Store back to MODER

    ; Set AFRH for PB8 and PB9 to AF4
    LDR     r1, [r0, #0x24]     ; Read AFRH
    BIC     r1, r1, #(0xFF << 0) ; Clear AFRH8/9
    ORR     r1, r1, #(0x44 << 0) ; AF4 for both (0100b for each nibble)
    STR     r1, [r0, #0x24]     ;

    ; Configure I2C1 for standard 100kHz
    LDR     r0, =0x40005400     ; I2C1 base address

    ; CR2: set peripheral clock frequency (assuming 16 MHz)
    MOV     r1, #16             ; PCLK1 frequency in MHz
    STR     r1, [r0, #0x04]     ; I2C_CR2

    ; CCR: 100kHz speed (standard mode)
    MOV     r1, #80             ; (PCLK1 / (2 * 100kHz)) = (16MHz / 200kHz) = 80
    STR     r1, [r0, #0x1C]     ; I2C_CCR

    ; TRISE: (Trise / Tpclk1) + 1 for standard mode. Trise = 1000ns. Tpclk1 = 1/16MHz = 62.5ns
    ; (1000ns / 62.5ns) + 1 = 16 + 1 = 17
    MOV     r1, #17             ; TRISE calculation
    STR     r1, [r0, #0x20]     ; I2C_TRISE

    ; Enable I2C1
    LDR     r1, [r0, #0x00]     ; Read I2C_CR1 (offset 0x00)
    ORR     r1, r1, #1          ; Set PE bit (bit 0) to enable I2C
    STR     r1, [r0, #0x00]     ; Write back to I2C_CR1

    POP     {r0, r1, PC}        ; Restore registers and return
ENDP

; -------------------------------
; Helper function to send a byte over I2C to the PCF8574.
; R0 = byte to send to PCF8574 (includes backlight, EN, RW, RS bits)
; This function assumes START and ADDRESS (with ACK) have already been handled.
; It only handles the data byte transfer and waits for TXE.
; -------------------------------
i2c_write_byte PROC
    PUSH    {r1, r2, LR}        ; Save registers and LR
    LDR     r1, =0x40005400     ; I2C1 base address

wait_TXE_byte
    LDR     r2, [r1, #0x14]     ; Read I2C_SR1
    TST     r2, #(1 << 7)       ; Test TXE (Transmit data register empty)
    BEQ     wait_TXE_byte       ; Loop if not empty

    STRB    r0, [r1, #0x10]     ; Write data byte from R0 to I2C_DR
    POP     {r1, r2, PC}        ; Restore registers and return
    ENDP

; -------------------------------
; Helper function for pulsing the EN bit and sending nibbles
; R0 = nibble data (with RS, RW, Backlight, but without EN)
; -------------------------------
lcd_pulse_en PROC
    PUSH    {r1, LR}            ; Save r1 and LR

    ; Send with EN high
    ORR     r0, r0, #0x04       ; Set EN bit (bit 2)
    BL      i2c_write_byte      ;

    ; Small delay for EN pulse
    MOV     r1, #1              ; Tiny delay (adjust if needed, NOPs often sufficient)
    SUBS    r1, r1, #1          ;
    BNE     .-4                 ;

    ; Send with EN low
    BIC     r0, r0, #0x04       ; Clear EN bit
    BL      i2c_write_byte      ;

    POP     {r1, PC}            ; Restore r1 and return
    ENDP


; -------------------------------
; lcd_send_byte: sends a full byte (command or data) to LCD via 4-bit mode
; R0 = byte to send
; R1 = RS_BIT (0 for command, 1 for data)
; -------------------------------
lcd_send_byte PROC
    PUSH    {r0, r1, r2, r3, r4, LR} ; Save all used registers and LR
    MOV     r2, r0              ; Store original byte in r2
    MOV     r3, r1              ; Store RS_BIT in r3 (0 or 1)

    LDR     r1, =0x40005400     ; I2C1 base address

    ; Generate Start condition
    LDR     r0, [r1, #0x00]     ; Read I2C_CR1
    ORR     r0, r0, #(1 << 8)   ; Set START bit
    STR     r0, [r1, #0x00]     ;

wait_SB_tx
    LDR     r0, [r1, #0x14]     ; Read I2C_SR1
    TST     r0, #(1 << 0)       ; Test SB (Start Bit)
    BEQ     wait_SB_tx          ;

    ; Send address with write bit
    MOV     r0, #(LCD_ADDR << 1) ; LCD I2C address + R/W=0 (write)
    STRB    r0, [r1, #0x10]     ; Write address to DR

wait_ADDR_tx
    LDR     r0, [r1, #0x14]     ; Read I2C_SR1
    TST     r0, #(1 << 1)       ; Test ADDR (Address sent)
    BEQ     wait_ADDR_tx        ;
    LDR     r0, [r1, #0x18]     ; Clear ADDR flag by reading SR2

    ; Prepare common bits: Backlight ON (bit 3), RW=0 (bit 1)
    MOV     r0, #0x08           ; Backlight ON (BL=1)
    ORR     r0, r0, r3          ; Add RS bit (r3: 0 for cmd, 1 for data)

    ; Send high nibble
    LSR     r4, r2, #4          ; Get high nibble of original byte
    AND     r4, r4, #0x0F       ; Mask to ensure only nibble bits
    ORR     r4, r4, r0          ; Combine with backlight and RS
    MOV     r0, r4              ; Pass to lcd_pulse_en
    BL      lcd_pulse_en        ;

    ; Send low nibble
    AND     r4, r2, #0x0F       ; Get low nibble of original byte
    ORR     r4, r4, r0          ; Combine with backlight and RS
    MOV     r0, r4              ; Pass to lcd_pulse_en
    BL      lcd_pulse_en        ;

    ; Generate Stop condition
    LDR     r0, [r1, #0x00]     ; Read I2C_CR1
    ORR     r0, r0, #(1 << 9)   ; Set STOP bit
    STR     r0, [r1, #0x00]     ;

    POP     {r0, r1, r2, r3, r4, PC} ; Restore registers and return
    ENDP

; -------------------------------
; lcd_send_cmd: sends a command to LCD
; R0 = command byte
; -------------------------------
lcd_send_cmd PROC
    PUSH    {LR}                ; Save LR
    MOV     r1, #0              ; RS=0 for command
    BL      lcd_send_byte       ;
    POP     {PC}                ; Return
    ENDP

; -------------------------------
; lcd_send_data: sends a data byte (character) to LCD
; R0 = data byte (character)
; -------------------------------
lcd_send_data PROC
    PUSH    {LR}                ; Save LR
    MOV     r1, #1              ; RS=1 for data
    BL      lcd_send_byte       ;
    POP     {PC}                ; Return
    ENDP

; -------------------------------
; lcd_init: initializes the LCD module
; -------------------------------
lcd_init PROC
    PUSH    {r0, LR}            ; Save r0 and LR

    MOV     r0, #50             ; Delay 50ms after power-on
    BL      delay_ms            ;

    ; 4-bit initialization sequence
    MOV     r0, #0x30           ; Function set: 8-bit mode (first command to LCD, ignores lower 4 bits)
    MOV     r1, #0              ; RS=0 for command
    BL      lcd_send_byte       ; Use the full send_byte for initial 8-bit command
    MOV     r0, #5              ; Delay 5ms
    BL      delay_ms            ;

    MOV     r0, #0x30           ; Repeat function set
    MOV     r1, #0              ;
    BL      lcd_send_byte       ;
    MOV     r0, #1              ; Delay 1ms
    BL      delay_ms            ;

    MOV     r0, #0x30           ; Repeat function set (third time)
    MOV     r1, #0              ;
    BL      lcd_send_byte       ;
    MOV     r0, #1              ; Delay 1ms
    BL      delay_ms            ;

    MOV     r0, #0x20           ; Function set: 4-bit mode
    MOV     r1, #0              ;
    BL      lcd_send_byte       ;
    MOV     r0, #1              ; Delay 1ms
    BL      delay_ms            ;

    ; Now in 4-bit mode, send standard initialization commands
    MOV     r0, #0x28           ; Function Set: 4-bit, 2 lines, 5x8 dots
    BL      lcd_send_cmd        ;

    MOV     r0, #0x0C           ; Display ON, Cursor OFF, Blink OFF
    BL      lcd_send_cmd        ;

    MOV     r0, #0x06           ; Entry Mode Set: Increment cursor, No shift
    BL      lcd_send_cmd        ;

    MOV     r0, #0x01           ; Clear Display
    BL      lcd_send_cmd        ;
    MOV     r0, #2              ; Delay 2ms for clear display
    BL      delay_ms            ;

    POP     {r0, PC}            ; Restore r0 and return
    ENDP


; -------------------------------
; lcd_render: draw paddles and ball based on game state
; -------------------------------
lcd_render PROC
    PUSH    {r0-r9, LR}         ; Save all used registers and LR

    ; Clear display
    MOV     r0, #0x01           ; Command to clear display
    BL      lcd_send_cmd        ;
    MOV     r0, #2              ; Small delay after clear display, around 2ms
    BL      delay_ms            ;

    ; Load game state (from game_logic.s)
    LDR     r6, =paddle1_y      ;
    LDR     r6, [r6]            ; r6 = paddle1_y
    LDR     r7, =paddle2_y      ;
    LDR     r7, [r7]            ; r7 = paddle2_y
    LDR     r8, =ball_x         ;
    LDR     r8, [r8]            ; r8 = ball_x
    LDR     r9, =ball_y         ;
    LDR     r9, [r9]            ; r9 = ball_y

    ; Row loop
    MOV     r4, #0              ; r4 = current row (0-3)

row_loop
    CMP     r4, #4              ;
    BEQ     render_done         ;

    ; Set DDRAM address for the current row
    ; Addresses: 0x80 (row 0), 0xC0 (row 1), 0x94 (row 2), 0xD4 (row 3)
    CMP     r4, #0              ;
    BEQ     set_row0_addr       ;
    CMP     r4, #1              ;
    BEQ     set_row1_addr       ;
    CMP     r4, #2              ;
    BEQ     set_row2_addr       ;
    CMP     r4, #3              ;
    BEQ     set_row3_addr       ;
    ; Fall through or branch to common point if needed

set_row0_addr
    MOV     r0, #0x80           ; Row 0 address
    BL      lcd_send_cmd        ;
    B       continue_col_loop   ;

set_row1_addr
    MOV     r0, #0xC0           ; Row 1 address
    BL      lcd_send_cmd        ;
    B       continue_col_loop   ;

set_row2_addr
    MOV     r0, #0x94           ; Row 2 address
    BL      lcd_send_cmd        ;
    B       continue_col_loop   ;

set_row3_addr
    MOV     r0, #0xD4           ; Row 3 address
    BL      lcd_send_cmd        ;
    B       continue_col_loop   ;

continue_col_loop
    ; Column loop
    MOV     r5, #0              ; r5 = current column (0-15)

col_loop
    CMP     r5, #16             ;
    BEQ     next_row            ;

    ; Default char
    MOV     r0, #' '            ; Default to space

    ; Left paddle (always at X=0)
    CMP     r5, #0              ;
    BNE     check_right_paddle  ;
    ; Check if current row (r4) is at paddle1_y or paddle1_y + 1
    CMP     r4, r6              ;
    BEQ     draw_left_paddle_char ;
    ADD     r1, r6, #1          ;
    CMP     r4, r1              ;
    BEQ     draw_left_paddle_char ;
    B       check_right_paddle  ;

draw_left_paddle_char
    MOV     r0, #'|'            ; Draw paddle character
    B       send_char           ;

check_right_paddle
    CMP     r5, #15             ;
    BNE     check_ball          ;
    ; Check if current row (r4) is at paddle2_y or paddle2_y + 1
    CMP     r4, r7              ;
    BEQ     draw_right_paddle_char ;
    ADD     r1, r7, #1          ;
    CMP     r4, r1              ;
    BEQ     draw_right_paddle_char ;
    B       check_ball          ;

draw_right_paddle_char
    MOV     r0, #'|'            ; Draw paddle character
    B       send_char           ;

check_ball
    CMP     r5, r8              ; Is current column the ball's X?
    BNE     send_char           ;
    CMP     r4, r9              ; Is current row the ball's Y?
    BNE     send_char           ;
    MOV     r0, #'O'            ; Draw ball character

send_char
    BL      lcd_send_data       ; Send the character to LCD
    ADD     r5, r5, #1          ;
    B       col_loop            ;

next_row
    ADD     r4, r4, #1          ;
    B       row_loop            ;

render_done
    POP     {r0-r9, PC}         ; Restore registers and return
    ENDP

    END