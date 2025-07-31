// esp_at_commands_common.c - Common ESP8266 functions for both boards
#include "esp_at_commands_common.h"
#include "delay.h"
#include <string.h>
#include <stdio.h>
#include "main.h"
extern UART_HandleTypeDef huart2;