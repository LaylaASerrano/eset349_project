// delay.h
#ifndef __DELAY_H
#define __DELAY_H

#include <stdint.h>

// Function prototypes for C

void delay_ms(uint32_t ms);
void delay_us(uint32_t us);
uint32_t Get_ms_ticks(void); // Function to get current ticks

// If g_ms_ticks is accessed directly by C
extern uint32_t g_ms_ticks;

#endif // __DELAY_H