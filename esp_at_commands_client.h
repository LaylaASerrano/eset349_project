#ifndef __ESP_AT_COMMANDS_CLIENT_H
#define __ESP_AT_COMMANDS_CLIENT_H

#include <stdint.h>

// Client-specific function prototypes
uint8_t ESP8266_Setup_Client(void (*delay_ms_ptr)(uint32_t));
uint8_t Send_Paddle_Wifi_Client(uint8_t paddle_y);
uint8_t Receive_Paddle_Wifi_Client(void);
void Trap_ESP_Error_Client(void);

#endif