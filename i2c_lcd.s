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
