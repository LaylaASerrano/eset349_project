// delay.h
#ifndef __DELAY_H
#define __DELAY_H

#include <stdint.h>
#include "stm32f4xx_hal.h" // ADD THIS, as HAL_Delay and HAL_GetTick will be used

// Function prototypes for C
// void delay_ms(uint32_t ms); // REMOVE THIS
void delay_us(uint32_t us);
// uint32_t Get_ms_ticks(void); // REMOVE THIS

// If g_ms_ticks is accessed directly by C
// extern uint32_t g_ms_ticks; // REMOVE THIS

#endif // __DELAY_H