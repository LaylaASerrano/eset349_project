; -------------------------------
; File: i2c_lcd.s
; Description: I2C initialization and LCD control (16x4 with I2C backpack)
; -------------------------------

; TODO: i2c_init:
;     - Enable GPIOB and I2C1 clocks
;     - Configure PB8 (SCL), PB9 (SDA) for AF4
;     - Set timing registers for I2C
;     - Enable I2C1 peripheral

; TODO: lcd_send_cmd:
;     - Send a command byte over I2C to LCD

; TODO: lcd_send_data:
;     - Send a data byte (character) to LCD

; TODO: lcd_render:
;     - Convert game state (paddles, ball) into LCD characters
;     - Call lcd_send_data repeatedly to write to LCD

; -------------------------------

; Int statements 
AREA i2c_lcd, CODE, READONLY
        EXPORT i2c_init
        EXPORT lcd_send_cmd
        EXPORT lcd_send_data
        EXPORT lcd_render

        IMPORT paddleLeftY
        IMPORT paddleRightY
        IMPORT ballX
        IMPORT ballY
LCD_ADDR EQU 0x27                           ; Need accurate i2c address of backpack

; -------------------------------
; i2c_init: enable gpiob | enable i2c1 | configure pb8/pb9 
; -------------------------------

    ; enable clocks
    
    ; GPIOB clock
    LDR r0, = 0x40023830                ; RCC_AHB1ENR
    LDR r1, [r0]
    ORR r1, r1, #(1 << 1)               ; set bit to enable gpiob
    STR r1, [r0]

    ; i2c1  clock
    LDR r0, =40023840                   ; RCC_APB1ENR
    LDR r1, [r0]
    ORR r1, r1, #(1 << 21)              ; set bit to enable i2c1
    STR r1, [r0]


    ; configure PB8 & PB9 as AF4
    LDR r0, =40020400                       ; base address
    LDR r1, [r0]
    BIC r1, r1, #(0xF << 16)                ; clear bits MODER8 and 9
    ORR r1, r1, #(0xA << 16)                ; set to af mode
    str r1, [r0]                            ; store back to MODER

    ; Set AFRH for PB8 and PB9 to AF4

    LDR r1, [r0, #0x24]
    BIC r1, r1, #(0xFF << 0)                ; clear AFRH8/9
    ORR r1, r1, #(0x44 << 0)                ; AF4 for both
    STR r1, [r0, #0x24]

    ; Configure I2C1 for standard 100kHz

    LDR r0, =0x40005400                     ; i2c1 base
    
    ; CR2: set peripheral clock frequency (assuming 16 MHz)
    MOV r1, #16
    STR r1, [r0, #0x04]
  
    ; CCR: 100kHz speed
    MOV r1, #80
    STR r1, [r0, #0x1C]
   
    ; TRISE
    MOV r1, #17
    STR r1, [r0, #0x20]
  
    ; Enable I2C1
    LDR r1, [r0]
    ORR r1, r1, #1
    STR r1, [r0]
        
    BX LR
    ENDP


; -------------------------------
; helper func
; -------------------------------

send_i2c_byte                                                
        PUSH {r1, r2, lr}                          
        LDR r1, =0x40005400                         ; i2c1 base address

    wait_TXE 
        LDR r2, [r1, #0x14]                         ; i2c_sr1
        TST r2, #(1 << 7)                           ; check TXE flag set
        BEQ wait_TXE                                ; if not sent wait
        STRB r0, [r1, #0x10]                        ; i2c_dr

    wait_BTF
        LDR r2, [r1, #0x14]                         ; i2c_sr1
        TST r2, #(1 << 2)                           ; check BTF flag set
        BEQ wait_BTF                                ; if not set wait
        POP {r1, r2, pc}                            ; return from


; -------------------------------
; send comamand
; -------------------------------

lcd_send_cmd function
    PUSH {r1, r2, LR}                               ; save registers
    LDR r1, =0x40005400                             ; load i2c1 base

    ; generate start condition
    LDR r2, [r1]                          
    ORR r2, r2, #(1 << 8)                           ; set start bit
    STR r2, [r1] 

    wait_SB
    LDR r2, [r1, #0x14]
    TST r2, #(1 << 0)                               ; check SB flag set
    BEQ wait_SB                                     ; if not set, wait

    ; send address with write bit
    MOV r2, #(LCD_ADDR << 1)                        ; shift address left and set write bit
    STRB r2, [r1, #0x10]

    wait_ADDR
    LDR r2, [r1, #0x14]
    TST r2, #(1 << 1)                               ; check ADDR flag set
    BEQ wait_ADDR                                   ; if not set wait
    LDR r2, [r1, #0x18]                             ; clear ADDR flag

    ; send command byte
    BL send_i2c_byte

    ; generate stop condition
    LDR r2, [r1]                                    ; read i2c1 base
    ORR r2, r2, #(1 << 9)                           ; set stop bit
    STR r2, [r1]                                    ; write back 
    
    POP {r1, r2, PC}                                ; restore registers and return
    ENDP

; -------------------------------
; send data
; -------------------------------
lcd_send_data FUNCTION
    BL lcd_send_cmd
    BX LR
    ENDP

; -------------------------------
; lcd_render: draw paddles and ball based on game state
; -------------------------------





; Need to define these variables in main.s 
;       AREA GameData, DATA, READWRITE
; paddleLeftY   DCD 1
; paddleRightY  DCD 2
; ballX         DCD 7
; ballY         DCD 1
;    END