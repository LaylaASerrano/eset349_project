	; I2C LCD Debug Version with timeout and error handling
	AREA    |.text|, CODE, READONLY

    export  lcd_init
    export  lcd_send_cmd
    export  lcd_send_data
    export  lcd_render
    export  i2c_scan        ; New function to scan for I2C devices

    IMPORT  ball_x
    IMPORT  ball_y
    IMPORT  paddle1_y
    IMPORT  paddle2_y
    IMPORT  delay_ms
    IMPORT  Get_ms_ticks    ; Import for timeout handling

; Try different common LCD I2C addresses
LCD_ADDR_3F EQU 0x3F
LCD_ADDR_27 EQU 0x27
LCD_ADDR_20 EQU 0x20
LCD_ADDR_3E EQU 0x3E

; Global variable to store working LCD address
	AREA    |.data|, DATA, READWRITE
lcd_working_addr DCD LCD_ADDR_3F  ; Default to 0x3F

	AREA    |.text|, CODE, READONLY

; -------------------------------
; I2C Scanner function - finds LCD address
; Returns: R0 = found address, or 0xFF if not found
; -------------------------------
i2c_scan PROC
    PUSH    {r1-r5, LR}
    LDR     r5, =0x40005400     ; I2C1 base address

    ; Try each possible address
    MOV     r4, #LCD_ADDR_3F
    BL      i2c_test_address
    CMP     r0, #1
    BEQ     scan_found

    MOV     r4, #LCD_ADDR_27
    BL      i2c_test_address
    CMP     r0, #1
    BEQ     scan_found

    MOV     r4, #LCD_ADDR_20
    BL      i2c_test_address
    CMP     r0, #1
    BEQ     scan_found

    MOV     r4, #LCD_ADDR_3E
    BL      i2c_test_address
    CMP     r0, #1
    BEQ     scan_found

    ; No device found
    MOV     r0, #0xFF
    B       scan_done

scan_found
    ; Store working address
    LDR     r1, =lcd_working_addr
    STR     r4, [r1]
    MOV     r0, r4

scan_done
    POP     {r1-r5, PC}
    ENDP

; Test if device responds at address in R4
; Returns R0 = 1 if found, 0 if not
i2c_test_address PROC
    PUSH    {r1-r3, LR}
    LDR     r5, =0x40005400     ; I2C1 base address

    ; Clear any pending errors first
    BL      i2c_clear_errors

    ; Generate Start
    LDR     r1, [r5, #0x00]     ; Read CR1
    ORR     r1, r1, #(1 << 8)   ; Set START bit
    STR     r1, [r5, #0x00]

    ; Wait for SB with timeout
    BL      Get_ms_ticks
    MOV     r3, r0              ; Save start time

test_wait_sb
    LDR     r1, [r5, #0x14]     ; Read SR1
    TST     r1, #(1 << 0)       ; Test SB
    BNE     test_sb_set

    ; Check timeout (10ms)
    BL      Get_ms_ticks
    SUB     r2, r0, r3
    CMP     r2, #10
    BLT     test_wait_sb

    ; Timeout - generate stop and fail
    BL      i2c_force_stop
    MOV     r0, #0
    POP     {r1-r3, PC}

test_sb_set
    ; Send address
    LSL     r1, r4, #1          ; Address + write bit
    STRB    r1, [r5, #0x10]     ; Write to DR

    ; Wait for ADDR or AF (address fail) with timeout
    BL      Get_ms_ticks
    MOV     r3, r0              ; Save start time

test_wait_addr
    LDR     r1, [r5, #0x14]     ; Read SR1
    TST     r1, #(1 << 1)       ; Test ADDR
    BNE     test_addr_ack
    TST     r1, #(1 << 10)      ; Test AF (ACK Failure)
    BNE     test_addr_nack

    ; Check timeout (10ms)
    BL      Get_ms_ticks
    SUB     r2, r0, r3
    CMP     r2, #10
    BLT     test_wait_addr

test_addr_nack
    ; No ACK or timeout - clear AF and stop
    LDR     r1, [r5, #0x14]     ; Read SR1
    BIC     r1, r1, #(1 << 10)  ; Clear AF
    STR     r1, [r5, #0x14]     ; Write back
    BL      i2c_force_stop
    MOV     r0, #0              ; Not found
    POP     {r1-r3, PC}

test_addr_ack
    ; Clear ADDR by reading SR2
    LDR     r1, [r5, #0x18]

    ; Generate stop
    BL      i2c_force_stop

    MOV     r0, #1              ; Found
    POP     {r1-r3, PC}
    ENDP

; Force I2C stop condition
i2c_force_stop PROC
    PUSH    {r1, LR}
    LDR     r1, =0x40005400
    LDR     r0, [r1, #0x00]     ; Read CR1
    ORR     r0, r0, #(1 << 9)   ; Set STOP
    STR     r0, [r1, #0x00]

    ; Small delay for stop to complete
    MOV     r0, #1
    BL      delay_ms

    POP     {r1, PC}
    ENDP

; Clear I2C error flags
i2c_clear_errors PROC
    PUSH    {r0-r1, LR}
    LDR     r1, =0x40005400

    ; Clear error flags in SR1
    LDR     r0, [r1, #0x14]
    BIC     r0, r0, #(1 << 10)  ; Clear AF
    BIC     r0, r0, #(1 << 14)  ; Clear TIMEOUT
    BIC     r0, r0, #(1 << 11)  ; Clear OVR
    BIC     r0, r0, #(1 << 8)   ; Clear BERR
    STR     r0, [r1, #0x14]

    POP     {r0-r1, PC}
    ENDP

; -------------------------------
; Modified lcd_send_byte with timeout and error recovery
; -------------------------------
lcd_send_byte PROC
    PUSH    {r0-r5, LR}
    MOV     r2, r0              ; Store original byte
    MOV     r3, r1              ; Store RS_BIT
    LDR     r1, =0x40005400     ; I2C1 base

    ; Get LCD address
    LDR     r0, =lcd_working_addr
    LDR     r4, [r0]            ; R4 = LCD address

    ; Clear any errors first
    BL      i2c_clear_errors

    ; Generate Start
    LDR     r0, [r1, #0x00]
    ORR     r0, r0, #(1 << 8)
    STR     r0, [r1, #0x00]

    ; Wait for SB with timeout
    BL      Get_ms_ticks
    MOV     r5, r0              ; Save start time

wait_SB_tx_timeout
    LDR     r0, [r1, #0x14]
    TST     r0, #(1 << 0)
    BNE     sb_set

    ; Check 50ms timeout
    BL      Get_ms_ticks
    SUB     r0, r0, r5
    CMP     r0, #50
    BLT     wait_SB_tx_timeout

    ; Timeout - try recovery
    BL      i2c_force_stop
    MOV     r0, #2
    BL      delay_ms
    B       lcd_send_byte_retry ; Retry once

sb_set
    ; Send address
    LSL     r0, r4, #1          ; Address + write
    STRB    r0, [r1, #0x10]

    ; Wait for ADDR with timeout
    BL      Get_ms_ticks
    MOV     r5, r0

wait_ADDR_tx_timeout
    LDR     r0, [r1, #0x14]
    TST     r0, #(1 << 1)       ; ADDR bit
    BNE     addr_set
    TST     r0, #(1 << 10)      ; AF bit
    BNE     addr_failed

    ; Check 50ms timeout
    BL      Get_ms_ticks
    SUB     r0, r0, r5
    CMP     r0, #50
    BLT     wait_ADDR_tx_timeout

addr_failed
    ; Address not acknowledged or timeout
    BL      i2c_force_stop
    MOV     r0, #5
    BL      delay_ms

lcd_send_byte_retry
    ; Try to rescan for LCD
    BL      i2c_scan
    CMP     r0, #0xFF
    BEQ     lcd_send_byte_fail

    ; Retry send with new address
    MOV     r0, r2              ; Restore byte
    MOV     r1, r3              ; Restore RS
    POP     {r0-r5, LR}
    PUSH    {r0-r5, LR}        ; Re-save for retry
    B       lcd_send_byte       ; Try again

addr_set
    ; Clear ADDR by reading SR2
    LDR     r0, [r1, #0x18]

    ; Continue with data transmission...
    ; (Rest of original lcd_send_byte code here)
    MOV     r0, #0x08           ; Backlight ON
    ORR     r0, r0, r3          ; Add RS bit

    ; Send high nibble
    LSR     r4, r2, #4
    AND     r4, r4, #0x0F
    ORR     r4, r4, r0
    MOV     r0, r4
    BL      lcd_pulse_en

    ; Send low nibble
    AND     r4, r2, #0x0F
    ORR     r4, r4, r0
    MOV     r0, r4
    BL      lcd_pulse_en

    ; Generate Stop
    LDR     r0, [r1, #0x00]
    ORR     r0, r0, #(1 << 9)
    STR     r0, [r1, #0x00]

    POP     {r0-r5, PC}

lcd_send_byte_fail
    ; Complete failure - return without sending
    POP     {r0-r5, PC}
    ENDP

; -------------------------------
; Modified lcd_init with I2C scanning
; -------------------------------
lcd_init PROC
    PUSH    {r0-r1, LR}

    ; First, scan for LCD
    BL      i2c_scan
    CMP     r0, #0xFF
    BEQ     lcd_init_fail       ; No LCD found

    ; Continue with normal init
    MOV     r0, #50
    BL      delay_ms

    ; Rest of initialization sequence...
    MOV     r0, #0x30
    MOV     r1, #0
    BL      lcd_send_byte
    MOV     r0, #5
    BL      delay_ms

    MOV     r0, #0x30
    MOV     r1, #0
    BL      lcd_send_byte
    MOV     r0, #1
    BL      delay_ms

    MOV     r0, #0x30
    MOV     r1, #0
    BL      lcd_send_byte
    MOV     r0, #1
    BL      delay_ms

    MOV     r0, #0x20
    MOV     r1, #0
    BL      lcd_send_byte
    MOV     r0, #1
    BL      delay_ms

    MOV     r0, #0x28
    BL      lcd_send_cmd

    MOV     r0, #0x0C
    BL      lcd_send_cmd

    MOV     r0, #0x06
    BL      lcd_send_cmd

    MOV     r0, #0x01
    BL      lcd_send_cmd
    MOV     r0, #2
    BL      delay_ms

    MOV     r0, #0              ; Success
    POP     {r0-r1, PC}

lcd_init_fail
    MOV     r0, #1              ; Failure code
    POP     {r0-r1, PC}
    ENDP

; Include rest of original functions (lcd_send_cmd, lcd_send_data, etc.)
; with the working address from lcd_working_addr instead of fixed LCD_ADDR

	END