// esp_at_commands.c
#include "esp_at_commands.h"

#include "delay.h"          // For delay_ms function (assuming delay.s provides a C-callable version)
#include <string.h>         // For strlen, strstr, memset
#include <stdio.h>          // For sprintf (if you need to format strings)


#include "main.h" // ADD THIS, assuming main.h declares huart2, etc.

// If main.h doesn't declare them, add externs:
extern UART_HandleTypeDef huart2;
extern uint8_t uart_rx_buffer[];
extern volatile uint16_t uart_rx_index;
extern volatile uint8_t  uart_rx_ready;
extern volatile uint8_t  uart_rx_char;

// ... rest of esp_at_commands.c ...

// Define AT Command and Response Strings
// These could also be in a header if shared widely
const char CMD_AT[] = "AT\r\n";
const char CMD_AT_RST[] = "AT+RST\r\n";
const char CMD_AT_CWMODE1[] = "AT+CWMODE=1\r\n";
const char CMD_AT_CWMODE2[] = "AT+CWMODE=2\r\n";
const char CMD_AT_CWJAP_TEST[] = "AT+CWJAP=\"Stack.SynergyWifi.com\",\"sweetbutter91\"\r\n";
const char CMD_AT_CIFSR[] = "AT+CIFSR\r\n";
const char CMD_AT_CIPMUX1[] = "AT+CIPMUX=1\r\n";
const char CMD_AT_CIPSERVER_P1[] = "AT+CIPSERVER=1,8080\r\n"; // IMPORTANT: Your Port
const char CMD_AT_CIPSEND_0_1[] = "AT+CIPSEND=0,1\r\n";

const char RESP_OK[] = "OK\r\n";
const char RESP_ERROR[] = "ERROR\r\n";
const char RESP_WIFI_GOT_IP[] = "WIFI GOT IP\r\n";
const char RESP_CONNECT[] = "CONNECT\r\n";
const char RESP_SEND_OK[] = "SEND OK\r\n";
const char RESP_CLOSED[] = "CLOSED\r\n";
const char RESP_IPD_PREFIX[] = "+IPD,";


// Helper function to send string via UART (blocking)
void UART_SendString(const char* str)
{
    HAL_UART_Transmit(&huart2, (uint8_t*)str, strlen(str), 100); // 100ms timeout
}

// Helper function to read a line from UART with timeout
// Returns 1 on success, 0 on timeout. Populates uart_rx_buffer
uint8_t UART_ReadLine(uint32_t timeout_ms)
{
    uint32_t start_time = Get_ms_ticks(); // Assuming Get_ms_ticks() from delay.s or C
    uart_rx_index = 0; // Reset buffer index
    uart_rx_ready = 0; // Clear ready flag
    memset(uart_rx_buffer, 0, UART_RX_BUFFER_SIZE); // Clear buffer content

    // Re-enable reception in case it was stopped
    HAL_UART_Receive_IT(&huart2, (uint8_t*)&uart_rx_char, 1);

    while (!uart_rx_ready && (Get_ms_ticks() - start_time < timeout_ms))
    {
        // Wait for line to be received by interrupt
    }
    return uart_rx_ready;
}

// Helper function to check if string contains substring
// (Could use C's strstr, but let's mimic the assembly logic for understanding)
uint8_t Str_Contains(const char* haystack, const char* needle)
{
    if (strstr(haystack, needle) != NULL)
    {
        return 1;
    }
    return 0;
}


/**
  * @brief Sends an AT command and waits for an expected response.
  * @param command: Pointer to the AT command string (null-terminated).
  * @param expected_response: Pointer to the expected response string (null-terminated).
  * @param timeout_ms: Timeout in milliseconds for receiving the response.
  * @retval 1 on success (expected response received), 0 on timeout/error.
  */
uint8_t ESP_SendATCommand(const char* command, const char* expected_response, uint32_t timeout_ms)
{
    UART_SendString(command);
    if (UART_ReadLine(timeout_ms))
    {
        if (Str_Contains((char*)uart_rx_buffer, expected_response))
        {
            return 1; // Success
        }
    }
    return 0; // Failure
}


/**
  * @brief Initializes the ESP8266 module with AT commands.
  * @param lcd_send_cmd_ptr: Function pointer to lcd_send_cmd (from assembly)
  * @param lcd_send_data_ptr: Function pointer to lcd_send_data (from assembly)
  * @param delay_ms_ptr: Function pointer to delay_ms (from assembly/C)
  * @retval 1 on success, 0 on fatal error (traps internally)
  */
uint8_t ESP8266_Setup(void (*lcd_send_cmd_ptr)(uint8_t), void (*lcd_send_data_ptr)(uint8_t), void (*delay_ms_ptr)(uint32_t))
{
    // Use function pointers to call assembly LCD functions
    // Example: lcd_send_cmd_ptr(0x80);

    // Display "ESP INIT"
    lcd_send_cmd_ptr(0x80);
    char esp_init_str[] = "ESP INIT";
    for (unsigned int i = 0; i < strlen(esp_init_str); i++) {
        lcd_send_data_ptr(esp_init_str[i]);
    }
    delay_ms_ptr(500);

    // 1. Test AT command
    if (!ESP_SendATCommand(CMD_AT, RESP_OK, 1000)) {
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0; // Should not reach here
    }
    lcd_send_cmd_ptr(0xC0);
    char at_ok_str[] = "AT OK";
    for (unsigned int i = 0; i < strlen(at_ok_str); i++) {
        lcd_send_data_ptr(at_ok_str[i]);
    }
    delay_ms_ptr(100);

    // 2. Reset ESP8266
    if (!ESP_SendATCommand(CMD_AT_RST, RESP_OK, 2000)) {
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0;
    }
    lcd_send_cmd_ptr(0x94);
    char rst_ok_str[] = "RST OK";
    for (unsigned int i = 0; i < strlen(rst_ok_str); i++) {
        lcd_send_data_ptr(rst_ok_str[i]);
    }
    delay_ms_ptr(3000); // Wait for ESP to reboot

    // 3. Set Wi-Fi Mode to Station (Client)
    if (!ESP_SendATCommand(CMD_AT_CWMODE1, RESP_OK, 1000)) {
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0;
    }
    lcd_send_cmd_ptr(0xD4);
    char mode_ok_str[] = "MODE OK";
    for (unsigned int i = 0; i < strlen(mode_ok_str); i++) {
        lcd_send_data_ptr(mode_ok_str[i]);
    }
    delay_ms_ptr(100);

    // 4. Connect to Wi-Fi Access Point
    if (!ESP_SendATCommand(CMD_AT_CWJAP_TEST, RESP_OK, 15000)) { // Longer timeout
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0;
    }
    lcd_send_cmd_ptr(0x80);
    char wifi_conn_str[] = "WIFI CONNECTED";
    for (unsigned int i = 0; i < strlen(wifi_conn_str); i++) {
        lcd_send_data_ptr(wifi_conn_str[i]);
    }
    delay_ms_ptr(500);

    // 5. Get Local IP Address (This is for Player 1)
    if (!ESP_SendATCommand(CMD_AT_CIFSR, RESP_OK, 1000)) {
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0;
    }
    // Display "IP: "
    lcd_send_cmd_ptr(0xC0);
    char ip_str[] = "IP: ";
    for (unsigned int i = 0; i < strlen(ip_str); i++) {
        lcd_send_data_ptr(ip_str[i]);
    }
    // !!! WARNING: Parsing IP from uart_rx_buffer is complex in C.
    // For actual display, you'd need to extract the IP string from uart_rx_buffer
    // and send it char by char to lcd_send_data_ptr.
    // For now, we'll just indicate "IP OK"
    lcd_send_cmd_ptr(0xD4);
    char ip_ok_str[] = "IP OK";
    for (unsigned int i = 0; i < strlen(ip_ok_str); i++) {
        lcd_send_data_ptr(ip_ok_str[i]);
    }
    delay_ms_ptr(500);


    // 6. Enable Multiple Connections (CIPMUX)
    if (!ESP_SendATCommand(CMD_AT_CIPMUX1, RESP_OK, 1000)) {
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0;
    }
    lcd_send_cmd_ptr(0x80);
    char mux_ok_str[] = "MUX OK";
    for (unsigned int i = 0; i < strlen(mux_ok_str); i++) {
        lcd_send_data_ptr(mux_ok_str[i]);
    }
    delay_ms_ptr(100);

    // 7. Start TCP Server (Player 1 will be server)
    if (!ESP_SendATCommand(CMD_AT_CIPSERVER_P1, RESP_OK, 2000)) {
        Trap_ESP_Error(lcd_send_cmd_ptr, lcd_send_data_ptr, delay_ms_ptr);
        return 0;
    }
    lcd_send_cmd_ptr(0xC0);
    char srv_ok_str[] = "SRV OK";
    for (unsigned int i = 0; i < strlen(srv_ok_str); i++) {
        lcd_send_data_ptr(srv_ok_str[i]);
    }
    delay_ms_ptr(500);

    return 1; // Setup complete
}

/**
  * @brief Sends a paddle position (0-3) over Wi-Fi.
  * @param paddle_y: The paddle Y position (0-3).
  * @retval 1 on success, 0 on failure.
  */
uint8_t Send_Paddle_Wifi(uint8_t paddle_y)
{
    char data_char = paddle_y + '0'; // Convert numeric paddle_y to ASCII '0'-'3'

    // Send AT+CIPSEND=0,1\r\n
    if (!ESP_SendATCommand(CMD_AT_CIPSEND_0_1, ">", 500)) { // Wait for '>' prompt
        return 0; // Failed to get prompt
    }

    // Send the actual data byte
    if (HAL_UART_Transmit(&huart2, (uint8_t*)&data_char, 1, 100) != HAL_OK) {
         return 0; // Failed to send data
    }

    // Wait for "SEND OK"
    if (!ESP_SendATCommand("", RESP_SEND_OK, 1000)) { // No command, just wait for response
        return 0; // Failed to get SEND OK
    }
    return 1; // Success
}

/**
  * @brief Receives paddle position from Wi-Fi.
  * @retval Received paddle_y (0-3) on success, or 0xFF (error/no data).
  */
uint8_t Receive_Paddle_Wifi(void)
{
    // Poll for incoming data (e.g., check uart_rx_ready for a new line)
    // If uart_rx_ready is set, process the buffer.
    // This example assumes continuous polling in the main loop and
    // the callback sets uart_rx_ready on '\n' or buffer full.

    if (uart_rx_ready)
    {
        uart_rx_ready = 0; // Clear the flag immediately

        // Check if the received line contains "+IPD,"
        if (Str_Contains((char*)uart_rx_buffer, RESP_IPD_PREFIX))
        {
            // Find the colon ':' in the buffer
            char* colon_ptr = strchr((char*)uart_rx_buffer, ':');
            if (colon_ptr != NULL)
            {
                // The character after the colon is the data
                char received_char = *(colon_ptr + 1);
                uint8_t received_paddle_y = received_char - '0';

                // Basic validation (0-3)
                if (received_paddle_y >= 0 && received_paddle_y <= 3)
                {
                    uart_rx_index = 0; // Reset index for next reception
                    memset(uart_rx_buffer, 0, UART_RX_BUFFER_SIZE); // Clear buffer
                    return received_paddle_y;
                }
            }
        }
        uart_rx_index = 0; // Reset index for next reception
        memset(uart_rx_buffer, 0, UART_RX_BUFFER_SIZE); // Clear buffer
    }
    return 0xFF; // Indicate no valid data or error
}

// Error Trap function
void Trap_ESP_Error(void (*lcd_send_cmd_ptr)(uint8_t), void (*lcd_send_data_ptr)(uint8_t), void (*delay_ms_ptr)(uint32_t))
{
    lcd_send_cmd_ptr(0x01); // Clear display 
    delay_ms_ptr(2);      // Use the passed function pointer for delay
    lcd_send_cmd_ptr(0x80); // Line 0 
    char err_str[] = "ESP ERR";
    for (unsigned int i = 0; i < strlen(err_str); i++) {
        lcd_send_data_ptr(err_str[i]);
    }
    while(1); // Infinite loop 
}
