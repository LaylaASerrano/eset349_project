/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : STM32 Pong Server - UART Client Command Handler
  ******************************************************************************
  */
/* USER CODE END Header */

/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "usart.h"
#include "gpio.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Private define ------------------------------------------------------------*/
#define UART_BUFFER_SIZE 64  // Max UART input length

/* Private variables ---------------------------------------------------------*/

// UART variables for command buffering
uint8_t uart_rx_buffer[UART_BUFFER_SIZE];
uint8_t uart_rx_data;
volatile uint8_t uart_data_ready = 0;
volatile uint16_t uart_rx_index = 0;

// Paddle2 position (0 = up, 1 = down). This is updated by processing UART commands.
volatile int32_t paddle2_y = 0;

/* Function prototypes */
void SystemClock_Config(void);
extern void main_server(void); // Defined in main.s
void Error_Handler(void);
void MX_GPIO_Init(void); // Prototype for the new GPIO init function

/* USER CODE BEGIN 0 */
/**
  * @brief Processes the buffered UART data to update the remote paddle position.
  * This function should be called frequently from the main game loop (in assembly).
  * @retval None
  */
void process_uart_commands(void) {
    if (uart_data_ready) {
        // Null-terminate the received data for string comparison
        uart_rx_buffer[uart_rx_index] = '\0';

        // Process the command and update paddle2_y
        if (strcmp((char*)uart_rx_buffer, "UP") == 0) {
            paddle2_y = 0;
        } else if (strcmp((char*)uart_rx_buffer, "DOWN") == 0) {
            paddle2_y = 1;
        }

        // Reset buffer for the next command
        uart_data_ready = 0;
        uart_rx_index = 0;
    }
}
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{
  // MCU Configuration
  HAL_Init();
  SystemClock_Config();

  // Initialize all configured peripherals (including GPIO for LCD and buttons)
  MX_GPIO_Init();
  MX_USART2_UART_Init();

  // Start UART receive interrupt. We wait for a single character.
  // The callback will buffer the full command.
  HAL_UART_Receive_IT(&huart2, &uart_rx_data, 1);

  // Call the main game loop defined in main.s.
  // This function is expected to contain an infinite loop.
  main_server();

  // This part of the code should not be reached.
  while (1)
  {
  }
}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};

  // GPIO Ports Clock Enable
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOC_CLK_ENABLE();

  // Configure LCD control pins PA5, PA7 as GPIO output
  GPIO_InitStruct.Pin = GPIO_PIN_5 | GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

  // Configure LCD data pins PC0-PC7 as GPIO output
  GPIO_InitStruct.Pin = GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3
                      | GPIO_PIN_4 | GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);

  // Configure button pins PC10, PC11 as GPIO input with pull-ups
  GPIO_InitStruct.Pin = GPIO_PIN_10 | GPIO_PIN_11;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_PULLUP;
  HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);
}


/**
  * @brief This function handles UART receive complete interrupt.
  * This interrupt is triggered every time a single byte is received.
  * It buffers the incoming characters and sets a flag when a newline
  * character is received, indicating a complete command.
  */
void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2) {
        // Buffer the character if there is space
        if (uart_rx_index < UART_BUFFER_SIZE) {
            uart_rx_buffer[uart_rx_index++] = uart_rx_data;

            // Check for newline or carriage return to signal a complete command
            if (uart_rx_data == '\r' || uart_rx_data == '\n') {
                uart_data_ready = 1;
            }
        } else {
            // If buffer is full, discard the new character but
            // signal that a command is ready for processing.
            // This prevents the system from getting stuck.
            uart_data_ready = 1;
        }

        // Restart RX to listen for the next character
        HAL_UART_Receive_IT(&huart2, &uart_rx_data, 1);
    }
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE2);

  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_NONE;

  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK) {
    Error_Handler();
  }

  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK
                              | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_HSI;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_0) != HAL_OK) {
    Error_Handler();
  }
}

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  __disable_irq();
  while (1) {}
}

#ifdef USE_FULL_ASSERT
void assert_failed(uint8_t *file, uint32_t line)
{
}
#endif
