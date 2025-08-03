// esp_at_commands_client.c - Client-side ESP8266 functions
#include "esp_at_commands_client.h"
#include "esp_at_commands_common.h" // Keep for common UART variables (uart_rx_buffer etc.) and ESP_SendATCommand if needed for other boards, but its contents should be minimal now
#include "delay.h"          // No longer strictly needed if all delays are HAL_Delay, but keep for delay_us if any assembly uses it directly.
#include <string.h>         // For strlen, memset
#include <stdio.h>          // For sprintf

// ADD THESE INCLUDES for HAL functions
#include "main.h"

// Client-specific AT commands - REMOVE OR COMMENT OUT THESE
// const char CMD_AT_CIPSTART_CLIENT[] = "AT+CIPSTART=\"TCP\",\"192.168.4.1\",8080\r\n";
// const char CMD_AT_CIPSEND_CLIENT[] = "AT+CIPSEND=1\r\n";

// External declarations for common UART variables from esp_at_commands_common.c
extern UART_HandleTypeDef huart2;
extern uint8_t uart_rx_buffer[];
extern volatile uint16_t uart_rx_index;
extern volatile uint8_t uart_rx_ready;
extern volatile uint8_t uart_rx_char;


/**
  * @brief Initializes UART for Player 2 (Client). No longer ESP8266 setup.
  * @param delay_ms_ptr: Function pointer to delay_ms (now unused as HAL_Delay is direct)
  * @retval 1 on success, 0 on failure
  */
uint8_t ESP8266_Setup_Client(void (*delay_ms_ptr)(uint32_t))
{
    // Clear any pending data (UART_ClearBuffer should be commented out from common.c if you fully remove ESP_SendATCommand logic)
    // If you plan to only send from client, no need to clear Rx buffer actively here.
    // UART_ClearBuffer(); // This function relies on uart_rx_buffer/index which are now external

    // This function now simply indicates readiness. UART initialization
    // should be handled by CubeMX-generated code in main.c and usart.c.
    HAL_Delay(100); // Small delay for stabilization

    return 1; // Success
}

/**
  * @brief Sends paddle position from Client to Server directly over UART.
  * @param paddle_y: Paddle position (0-1 for 2-line display)
  * @retval 1 on success, 0 on failure
  */
// In your esp_at_commands_client.c or another C file where Send_Paddle_Wifi_Client is defined

#include "usart.h"  // Make sure this header declares your UART handle

extern UART_HandleTypeDef huart2;  // Adjust if you use USART2 or another UART

uint8_t Send_Paddle_Wifi_Client(uint8_t paddle_y) {
    // Transmit 1 byte (paddle_y) over UART, timeout 10 ms
    if (HAL_UART_Transmit(&huart2, &paddle_y, 1, 10) == HAL_OK) {
        return 1;   // success
    } else {
        return 0;   // failure
    }
}


/**
  * @brief Wrapper function for assembly code - matches the import name
  * (This function acts as a passthrough to Send_Paddle_Wifi_Client)
  * @param paddle_y: Paddle position (0-1 for 2-line display)
  * @retval 1 on success, 0 on failure
  */
uint8_t Send_Paddle_Wifi(uint8_t paddle_y)
{
    return Send_Paddle_Wifi_Client(paddle_y);
}

/**
  * @brief Receives paddle position at Client (not used in current implementation).
  * If the client board needs to receive data from the server, implement this
  * to read from uart_rx_buffer similar to the server's Receive_Paddle_Wifi.
  * @retval Received paddle_y or 0xFF on error
  */
uint8_t Receive_Paddle_Wifi_Client(void)
{
    // For now, client only sends, doesn't receive in this setup.
    // If needed, implement similar to server's Receive_Paddle_Wifi reading from uart_rx_buffer.
    return 0xFF;
}

/**
  * @brief Error handler for Client. Repurposed to just blink an LED.
  */
void Trap_ESP_Error_Client(void)
{
    // Since client doesn't have LCD, use LED blinking
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    // Assuming LED on PA5 (check your board's setup)
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