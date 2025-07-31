#ifndef __ESP_AT_COMMANDS_COMMON_H
#define __ESP_AT_COMMANDS_COMMON_H

#include <stdint.h>
#include "stm32f4xx_hal.h" // Added for HAL types if needed, now essential

// Buffer configuration - KEEP THIS, as main.c uses it.
#define UART_RX_BUFFER_SIZE 256


// UART buffer variables - KEEP THESE EXTERN
extern uint8_t uart_rx_buffer[];
extern volatile uint16_t uart_rx_index;
extern volatile uint8_t uart_rx_ready;
extern volatile uint8_t uart_rx_char;



#endif