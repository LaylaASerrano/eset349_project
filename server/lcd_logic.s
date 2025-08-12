    AREA    |.text|, CODE, READONLY
    ; written by Layla Serrano
	; Export LCD functions for use by other files
	EXPORT  LCDInit
	EXPORT  LCDCommand
	EXPORT  LCDData
	EXPORT  delay
    EXPORT  LCDString
    EXPORT  LCDSetCursor
    EXPORT  lcd_render

    ; Import HAL_Delay for render loop
    IMPORT  HAL_Delay

    ; Import game state variables
    IMPORT  ball_x
    IMPORT  ball_y
    IMPORT  paddle1_y
    IMPORT  paddle2_y

	; LCD control pin definitions
RS			EQU 0x20	; RS connects to PA5 (bit 5)
RW			EQU 0x40	; RW connects to PA6 (bit 6) - tied to GND, not used
EN			EQU 0x80	; EN connects to PA7 (bit 7)

	; GPIO base addresses
GPIOA_BASE	EQU 0x40020000
GPIOC_BASE	EQU 0x40020800
RCC_AHB1ENR	EQU 0x40023830

; -----------------------------------------------------------------------------
; LCDInit: Initializes the LCD display.
; NOTE: GPIO pins are now initialized in main_server.c
; -----------------------------------------------------------------------------
LCDInit		PROC
			PUSH {r2, LR}

			; LCD initialization sequence
			MOV R2, #0x38			; 2 lines, 5x8 characters, 8-bit mode
			BL LCDCommand			; Send command in R2 to LCD

			MOV R2, #0x0E 			; Turn on display and cursor
			BL LCDCommand

			MOV R2, #0x01 			; Clear display
			BL LCDCommand

			MOV R2, #0x06 			; Shift cursor right
			BL LCDCommand

			POP {r2, LR}
			BX LR
			ENDP

LCDCommand	PROC					; R2 brings in the command byte
			PUSH {r0-r3, LR}

			LDR R0, =GPIOA_BASE		; GPIOA base address for control pins
			LDR R1, =GPIOC_BASE		; GPIOC base address for data pins

			STRB R2, [R1, #0x14]	; Send command to data pins (PC0-PC7)
			MOV R3, #0x00			; RS = 0, RW = 0, EN = 1
			ORR R3, R3, #EN
			STRB R3, [R0, #0x14]	; Set EN = 1 (enable pulse)

			BL delay

			MOV R3, #0x00
			STRB R3, [R0, #0x14]	; EN = 0, RS = 0, RW = 0

			POP {r0-r3, LR}
			BX LR
			ENDP

LCDData		PROC					; R3 brings in the character byte
			PUSH {r0-r2, r4, LR}

			LDR R0, =GPIOA_BASE		; GPIOA base address for control pins
			LDR R1, =GPIOC_BASE		; GPIOC base address for data pins

			STRB R3, [R1, #0x14] 	; Send data to data pins (PC0-PC7)
			MOV R4, #0x00			; RS = 1, RW = 0, EN = 1
			ORR R4, R4, #EN
			ORR R4, R4, #RS
			STRB R4, [R0, #0x14]	; Set EN = 1 and RS = 1 (enable pulse with data mode)

			BL delay

			MOV R4, #0x00
			STRB R4, [R0, #0x14]	; EN = 0, RS = 0, RW = 0

			POP {r0-r2, r4, LR}
			BX LR
			ENDP

delay		PROC
			PUSH {r4-r5}
			MOV R5, #50
loop1		MOV R4, #0xFF
loop2		SUBS R4, #1
			BNE loop2
			SUBS R5, #1
			BNE loop1
			POP {r4-r5}
			BX LR
			ENDP

	; Function to send a string to LCD
	; R0 = pointer to null-terminated string
LCDString	PROC
			PUSH {r0-r3, LR}
			MOV R1, R0
string_loop
			LDRB R3, [R1], #1
			CMP R3, #0
			BEQ string_done
			BL LCDData
			B string_loop
string_done
			POP {r0-r3, LR}
			BX LR
			ENDP

	; Function to set cursor position
	; R0 = position (0x80 for line 1, 0xC0 for line 2, add offset for column)
LCDSetCursor PROC
			PUSH {r2, LR}
            MOV R2, R0          ; Move argument R0 to R2 for LCDCommand
			BL LCDCommand
			POP {r2, LR}
			BX LR
			ENDP

; -----------------------------------------------------------------------------
; lcd_render: Renders the game state on the LCD.
; Reads ball_x, ball_y, paddle1_y, paddle2_y and updates LCD.
; -----------------------------------------------------------------------------
lcd_render PROC
    PUSH    {r0-r7, LR}

    ; Define characters
    BALL_CHAR EQU 'o'
    PADDLE_CHAR EQU '|'

    ; Clear display
    MOV     R0, #0x01
    BL      LCDCommand
    MOV     R0, #2
    BL      HAL_Delay

    ; Load game state variables
    LDR     r2, =ball_x         ; r2 = addr of ball_x
    LDR     r3, [r2]            ; r3 = ball_x
    LDR     r4, =ball_y         ; r4 = addr of ball_y
    LDR     r5, [r4]            ; r5 = ball_y
    LDR     r6, =paddle1_y      ; r6 = addr of paddle1_y
    LDR     r7, [r6]            ; r7 = paddle1_y
    LDR     r0, =paddle2_y      ; r0 = addr of paddle2_y
    LDR     r1, [r0]            ; r1 = paddle2_y

    ; Render Paddle 1
    MOV     r0, #0x80           ; Set cursor to line 1
    ADD     r0, r0, r7          ; Add paddle1_y offset to cursor
    BL      LCDSetCursor
    MOV     r3, #PADDLE_CHAR
    BL      LCDData

    ; Render Paddle 2
    MOV     r0, #0x8F           ; Set cursor to far right of line 1 (column 15)
    ADD     r0, r0, r1          ; Add paddle2_y offset to cursor
    BL      LCDSetCursor
    MOV     r3, #PADDLE_CHAR
    BL      LCDData

    ; Render Ball
    MOV     r0, #0x80           ; base address for line 1
    CMP     r5, #1              ; Is ball on line 2 (y=1)?
    ADDEQ   r0, r0, #0x40       ; Add line 2 offset if needed

    ADD     r0, r0, r8          ; Add ball_x offset to cursor
    BL      LCDSetCursor
    MOV     r3, #BALL_CHAR
    BL      LCDData

    POP     {r0-r7, PC}
    ENDP

	END
