#ifndef __ESP_AT_COMMANDS_CLIENT_H
#define __ESP_AT_COMMANDS_CLIENT_H

#include <stdint.h>
#include "stm32f4xx_hal.h" // ADD THIS, as HAL_StatusTypeDef etc. might be used

// Add this definition here so it's accessible to esp_at_commands_client.c
#define UART_RX_BUFFER_SIZE 256

// Client-specific function prototypes
uint8_t ESP8266_Setup_Client(void (*delay_ms_ptr)(uint32_t));
uint8_t Send_Paddle_Wifi_Client(uint8_t paddle_y);
uint8_t Receive_Paddle_Wifi_Client(void);
void Trap_ESP_Error_Client(void);

// --- REMOVE OR COMMENT OUT ALL THESE EXTERNS ---
// extern const char CMD_AT_CIPSTART_CLIENT[];
// extern const char CMD_AT_CIPSEND_CLIENT[];

#endif