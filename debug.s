    AREA    |.text|, CODE, READONLY
    EXPORT  debug_main          ; Export the main entry point for debugging

    ; Import communication functions from usart_init.s
    IMPORT  usart_init
    IMPORT  send_input_uart
    IMPORT  recv_input_uart
    IMPORT  send_string_uart
    IMPORT  uart_read_line
    IMPORT  str_contains
    IMPORT  send_at_command

    ; Import delay functions and global tick counter from delay.s
    IMPORT  delay_init
    IMPORT  delay_ms
    IMPORT  g_ms_ticks

    ; Import global UART buffer and flags from usart_init.s
    IMPORT  uart_rx_buffer
    IMPORT  uart_rx_index
    IMPORT  uart_rx_ready

    ; Import LCD functions for basic output (optional, for visual feedback)
    IMPORT  lcd_init
    IMPORT  lcd_send_data
    IMPORT  lcd_send_cmd

debug_main PROC
    PUSH    {r0-r7, LR}         ; Save registers and LR

    ; -------------------------------------------------------------------------
    ; 1. Initialize necessary peripherals for communication and display
    ;    (GPIO, USART, SysTick, LCD)
    ; -------------------------------------------------------------------------
    BL      usart_init          ; Initialize USART2
    BL      delay_init          ; Initialize SysTick for delays
    BL      lcd_init            ; Initialize LCD for visual feedback

    ; Optional: Display a "DEBUG" message on LCD to indicate entry
    MOV     R0, #0x80           ; Set LCD cursor to start of line 0
    BL      lcd_send_cmd
    MOV     R0, #'D'
    BL      lcd_send_data
    MOV     R0, #'E'
    BL      lcd_send_data
    MOV     R0, #'B'
    BL      lcd_send_data
    MOV     R0, #'U'
    BL      lcd_send_data
    MOV     R0, #'G'
    BL      lcd_send_data
    MOV     R0, #200            ; Short delay
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 2. Test send_input_uart (single character transmit)
    ;    Expected: "Hello!\r\n" in serial terminal
    ; -------------------------------------------------------------------------
    MOV     R0, #0xC0           ; Set LCD cursor to start of line 1
    BL      lcd_send_cmd
    MOV     R0, #'1'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    MOV     R1, #'H'
    BL      send_input_uart
    MOV     R1, #'e'
    BL      send_input_uart
    MOV     R1, #'l'
    BL      send_input_uart
    MOV     R1, #'l'
    BL      send_input_uart
    MOV     R1, #'o'
    BL      send_input_uart
    MOV     R1, #'!'
    BL      send_input_uart
    MOV     R1, #0x0D           ; CR
    BL      send_input_uart
    MOV     R1, #0x0A           ; LF
    BL      send_input_uart
    MOV     R0, #500            ; Delay 500ms
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 3. Test send_string_uart (null-terminated string transmit)
    ;    Expected: "String Test!\r\n" in serial terminal
    ; -------------------------------------------------------------------------
    MOV     R0, #0xC0 + 8       ; Set LCD cursor to middle of line 1
    BL      lcd_send_cmd
    MOV     R0, #'2'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    LDR     R0, =TEST_STRING_SEND ; Load address of test string
    BL      send_string_uart
    MOV     R0, #500            ; Delay 500ms
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 4. Test recv_input_uart (single character receive & echo)
    ;    Expected: Type a char in terminal, it should be echoed back.
    ;    LCD will show '3.' and then 'R' if a char is received.
    ; -------------------------------------------------------------------------
    MOV     R0, #0x94           ; Set LCD cursor to start of line 2
    BL      lcd_send_cmd
    MOV     R0, #'3'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    MOV     R0, #'R'            ; Display 'R' on LCD to prompt receive
    BL      lcd_send_data
    MOV     R0, #500            ; Delay 500ms
    BL      delay_ms

    BL      recv_input_uart     ; Wait for and receive a character (R0)
    MOV     R1, R0              ; Move received char to R1 for echo
    BL      send_input_uart     ; Echo it back to terminal
    MOV     R1, #0x0D           ; CR
    BL      send_input_uart
    MOV     R1, #0x0A           ; LF
    BL      send_input_uart
    MOV     R0, #500            ; Delay 500ms
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 5. Test uart_read_line (read a full line or timeout)
    ;    Expected: Echoes line typed, or prints 'T' on timeout.
    ;    LCD will show '4.'
    ; -------------------------------------------------------------------------
    MOV     R0, #0x94 + 8       ; Set LCD cursor to middle of line 2
    BL      lcd_send_cmd
    MOV     R0, #'4'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    MOV     R0, #3000           ; 3 second timeout
    BL      uart_read_line      ; R0 = 1 on success, 0 on timeout
    CMP     R0, #1
    BEQ     L_line_read_ok
    ; If timeout/fail, display 'T' on LCD and terminal
    MOV     R0, #'T'
    BL      lcd_send_data
    MOV     R1, #'T'
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
    B       L_line_read_done

L_line_read_ok
    ; If line received, display 'L' on LCD and echo buffer to terminal
    MOV     R0, #'L'
    BL      lcd_send_data
    LDR     R0, =uart_rx_buffer ; Load address of received buffer
    BL      send_string_uart    ; Echo the received line
L_line_read_done
    MOV     R0, #1000           ; Delay 1 second
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 6. Test str_contains (substring search)
    ;    Expected: LCD shows '5.' and then 'S' if tests pass, 'F' if fail.
    ;    Terminal also shows 'S' or 'F'.
    ; -------------------------------------------------------------------------
    MOV     R0, #0xD4           ; Set LCD cursor to start of line 3
    BL      lcd_send_cmd
    MOV     R0, #'5'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    ; Test 1: Needle found
    LDR     R0, =HAYSTACK_TEST
    LDR     R1, =NEEDLE_FOUND_TEST
    BL      str_contains
    CMP     R0, #1
    BEQ     .L_str_test1_pass
    B       .L_str_test_fail_display

.L_str_test1_pass:
    ; Test 2: Needle not found
    LDR     R0, =HAYSTACK_TEST
    LDR     R1, =NEEDLE_NOT_FOUND_TEST
    BL      str_contains
    CMP     R0, #0
    BEQ     .L_str_test_success_display
    B       .L_str_test_fail_display

.L_str_test_success_display:
    MOV     R0, #'S'            ; Display 'S' for success
    BL      lcd_send_data
    MOV     R1, #'S'            ; Send 'S' to terminal
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
    B       .L_str_test_done

.L_str_test_fail_display:
    MOV     R0, #'F'            ; Display 'F' for failure
    BL      lcd_send_data
    MOV     R1, #'F'            ; Send 'F' to terminal
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
.L_str_test_done:
    MOV     R0, #1000           ; Delay 1 second
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 7. Test send_at_command (AT command to ESP8266)
    ;    Expected: LCD shows '6.' and then 'A' if AT command OK, 'F' if fail.
    ;    Terminal also shows 'A' or 'F'.
    ;    Requires ESP8266 connected and powered correctly.
    ; -------------------------------------------------------------------------
    MOV     R0, #0xD4 + 8       ; Set LCD cursor to middle of line 3
    BL      lcd_send_cmd
    MOV     R0, #'6'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    MOV     R0, =CMD_AT         ; Command: "AT\r\n"
    MOV     R1, =RESP_OK        ; Expected response: "OK\r\n"
    MOV     R2, #1000           ; Timeout: 1000ms
    BL      send_at_command
    CMP     R0, #1
    BEQ     .L_at_cmd_test_success
    B       .L_at_cmd_test_fail_display

.L_at_cmd_test_success:
    MOV     R0, #'A'            ; Display 'A' for AT success
    BL      lcd_send_data
    MOV     R1, #'A'            ; Send 'A' to terminal
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
    B       .L_at_cmd_test_done

.L_at_cmd_test_fail_display:
    MOV     R0, #'F'            ; Display 'F' for AT failure
    BL      lcd_send_data
    MOV     R1, #'F'            ; Send 'F' to terminal
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
.L_at_cmd_test_done:
    MOV     R0, #1000           ; Delay 1 second
    BL      delay_ms

    ; -------------------------------------------------------------------------
    ; 8. Test AT+RST command (ESP8266 reset)
    ;    Expected: LCD shows '7.' and then 'R' if Reset OK, 'F' if fail.
    ;    Terminal also shows 'R' or 'F'.
    ;    Requires ESP8266 connected and powered correctly.
    ; -------------------------------------------------------------------------
    MOV     R0, #0x80           ; Set LCD cursor to start of line 0
    BL      lcd_send_cmd
    MOV     R0, #'7'
    BL      lcd_send_data
    MOV     R0, #'.'
    BL      lcd_send_data
    MOV     R0, #' '
    BL      lcd_send_data

    MOV     R0, =CMD_AT_RST     ; Command: "AT+RST\r\n"
    MOV     R1, =RESP_OK        ; Expected response: "OK\r\n"
    MOV     R2, #2000           ; Timeout: 2000ms (reset takes longer)
    BL      send_at_command
    CMP     R0, #1
    BEQ     .L_rst_cmd_test_success
    B       .L_rst_cmd_test_fail_display

.L_rst_cmd_test_success:
    MOV     R0, #'R'            ; Display 'R' for Reset success
    BL      lcd_send_data
    MOV     R1, #'R'            ; Send 'R' to terminal
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
    MOV     R0, #3000           ; Delay for ESP to reboot
    BL      delay_ms
    B       .L_rst_cmd_test_done

.L_rst_cmd_test_fail_display:
    MOV     R0, #'F'            ; Display 'F' for Reset failure
    BL      lcd_send_data
    MOV     R1, #'F'            ; Send 'F' to terminal
    BL      send_input_uart
    MOV     R1, #0x0D
    BL      send_input_uart
    MOV     R1, #0x0A
    BL      send_input_uart
.L_rst_cmd_test_done:
    MOV     R0, #1000           ; Delay 1 second
    BL      delay_ms


    ; -------------------------------------------------------------------------
    ; Infinite loop to keep the debugger attached and observe state
    ; -------------------------------------------------------------------------
    infinite_debug_loop:
    B       infinite_debug_loop

    POP     {r0-r7, PC}         ; Restore registers and return (should not be reached)
    ENDP

    ; -------------------------------------------------------------------------
    ; Data Section for Test Strings and AT Commands
    ; -------------------------------------------------------------------------
    AREA    |.data_debug|, DATA, READONLY

TEST_STRING_SEND    DCB     "String Test!\r\n", 0

HAYSTACK_TEST       DCB     "This is a test string.\r\n", 0
NEEDLE_FOUND_TEST   DCB     "test", 0
NEEDLE_NOT_FOUND_TEST DCB   "xyz", 0

; AT Commands (copied from usart_init.s for clarity in this file)
CMD_AT              DCB     "AT", 0x0D, 0x0A, 0
CMD_AT_RST          DCB     "AT+RST", 0x0D, 0x0A, 0
CMD_AT_CWMODE1      DCB     "AT+CWMODE=1", 0x0D, 0x0A, 0
CMD_AT_CWJAP        DCB     "AT+CWJAP=", 0
CMD_AT_CIFSR        DCB     "AT+CIFSR", 0x0D, 0x0A, 0

; Expected Responses (copied for clarity)
RESP_OK             DCB     "OK", 0x0D, 0x0A, 0
RESP_ERROR          DCB     "ERROR", 0x0D, 0x0A, 0
RESP_WIFI_GOT_IP    DCB     "WIFI GOT IP", 0x0D, 0x0A, 0
RESP_CONNECT        DCB     "CONNECT", 0x0D, 0x0A, 0
RESP_SEND_OK        DCB     "SEND OK", 0x0D, 0x0A, 0

    ALIGN
    END
