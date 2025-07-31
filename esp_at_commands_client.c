// esp_at_commands_client.c - Client-side ESP8266 functions
#include "esp_at_commands_client.h"
#include "delay.h"
#include <string.h>
#include <stdio.h>

// Client-specific AT commands
const char CMD_AT_CIPSTART_CLIENT[] = "AT+CIPSTART=\"TCP\",\"192.168.4.1\",8080\r\n"; // Connect to server
const char CMD_AT_CIPSEND_CLIENT[] = "AT+CIPSEND=1\r\n"; // Send 1 byte

// External declarations
extern UART_HandleTypeDef huart2;
extern uint8_t uart_rx_buffer[];
extern volatile uint16_t uart_rx_index;
extern volatile uint8_t uart_rx_ready;
extern volatile uint8_t uart_rx_char;

/**
  * @brief Initializes ESP8266 for Player 2 (Client)
  * @param delay_ms_ptr: Function pointer to delay_ms
  * @retval 1 on success, 0 on failure
  */
uint8_t ESP8266_Setup_Client(void (*delay_ms_ptr)(uint32_t))
{
    // Clear any pending data
    memset(uart_rx_buffer, 0, UART_RX_BUFFER_SIZE);
    uart_rx_index = 0;
    uart_rx_ready = 0;

    // 1. Test AT command
    if (!ESP_SendATCommand(CMD_AT, RESP_OK, 1000)) {
        Trap_ESP_Error_Client();
        return 0;
    }
    delay_ms_ptr(100);

    // 2. Reset ESP8266
    if (!ESP_SendATCommand(CMD_AT_RST, RESP_OK, 2000)) {
        Trap_ESP_Error_Client();
        return 0;
    }
    delay_ms_ptr(3000); // Wait for reboot

    // 3. Set WiFi Mode to Station (Client)
    if (!ESP_SendATCommand(CMD_AT_CWMODE1, RESP_OK, 1000)) {
        Trap_ESP_Error_Client();
        return 0;
    }
    delay_ms_ptr(100);

    // 4. Connect to WiFi Access Point
    if (!ESP_SendATCommand(CMD_AT_CWJAP_TEST, RESP_OK, 15000)) {
        Trap_ESP_Error_Client();
        return 0;
    }
    delay_ms_ptr(500);

    // 5. Connect to TCP Server (Player 1)
    // Wait a bit for server to be ready
    delay_ms_ptr(2000);

    if (!ESP_SendATCommand(CMD_AT_CIPSTART_CLIENT, RESP_OK, 5000)) {
        // Try again after delay
        delay_ms_ptr(2000);
        if (!ESP_SendATCommand(CMD_AT_CIPSTART_CLIENT, RESP_OK, 5000)) {
            Trap_ESP_Error_Client();
            return 0;
        }
    }

    // Check for "CONNECT" response
    if (UART_ReadLine(3000)) {
        if (!Str_Contains((char*)uart_rx_buffer, RESP_CONNECT)) {
            Trap_ESP_Error_Client();
            return 0;
        }
    }

    return 1; // Success
}

/**
  * @brief Sends paddle position from Client to Server
  * @param paddle_y: Paddle position (0-1 for 2-line display)
  * @retval 1 on success, 0 on failure
  */
uint8_t Send_Paddle_Wifi_Client(uint8_t paddle_y)
{
    char data_char = paddle_y + '0'; // Convert to ASCII

    // Send AT+CIPSEND=1
    if (!ESP_SendATCommand(CMD_AT_CIPSEND_CLIENT, ">", 500)) {
        return 0; // Failed to get prompt
    }

    // Send the actual data
    if (HAL_UART_Transmit(&huart2, (uint8_t*)&data_char, 1, 100) != HAL_OK) {
        return 0;
    }

    // Wait for "SEND OK"
    if (UART_ReadLine(1000)) {
        if (Str_Contains((char*)uart_rx_buffer, RESP_SEND_OK)) {
            return 1; // Success
        }
    }

    return 0; // Failed
}

/**
  * @brief Receives paddle position at Client (not used in current implementation)
  * @retval Received paddle_y or 0xFF on error
  */
uint8_t Receive_Paddle_Wifi_Client(void)
{
    // Client only sends, doesn't receive in current implementation
    // But this could be used for future enhancements
    return 0xFF;
}

/**
  * @brief Error handler for Client ESP8266
  */
void Trap_ESP_Error_Client(void)
{
    // Since client doesn't have LCD, use LED blinking
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    // Assuming LED on PA5
    __HAL_RCC_GPIOA_CLK_ENABLE();
    GPIO_InitStruct.Pin = GPIO_PIN_5;
    GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

    // Blink LED rapidly to indicate error
    while(1) {
        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);
        HAL_Delay(100); // Fast blink
    }
}