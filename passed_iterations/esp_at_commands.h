// esp_at_commands.h
#ifndef __ESP_AT_COMMANDS_H
#define __ESP_AT_COMMANDS_H

#include <stdint.h> // For uint8_t, uint32_t

// Function prototypes that will be called from assembly
uint8_t ESP_SendATCommand(const char* command, const char* expected_response, uint32_t timeout_ms);
uint8_t ESP8266_Setup(void (*lcd_send_cmd_ptr)(uint8_t), void (*lcd_send_data_ptr)(uint8_t), void (*delay_ms_ptr)(uint32_t));
uint8_t Send_Paddle_Wifi(uint8_t paddle_y);
uint8_t Receive_Paddle_Wifi(void);

// Global utility functions if needed by assembly
void UART_SendString(const char* str);
uint8_t UART_ReadLine(uint32_t timeout_ms);
uint8_t Str_Contains(const char* haystack, const char* needle);

// Error trap for ESP
void Trap_ESP_Error(void (*lcd_send_cmd_ptr)(uint8_t), void (*lcd_send_data_ptr)(uint8_t), void (*delay_ms_ptr)(uint32_t));


#endif // __ESP_AT_COMMANDS_H