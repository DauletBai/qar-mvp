#include "hal_init.h"

#include <stdint.h>

#include "hal/gpio.h"
#include "hal/uart.h"
#include "hal/timer.h"
#include "hal/can.h"
#include "hal/spi.h"
#include "hal/i2c.h"
#include "hal/adc.h"

#define QAR_UART_BOOT_DIV      500u
#define QAR_CAN_BOOT_BITTIME   0x00000013u
#define QAR_SPI_BOOT_CLKDIV    4u
#define QAR_I2C_BOOT_CLKDIV    64u

#define QAR_UART_IRQ_ALL   (\
    QAR_UART_IRQ_RX_READY   | \
    QAR_UART_IRQ_TX_EMPTY   | \
    QAR_UART_IRQ_ERROR      | \
    QAR_UART_IRQ_IDLE       | \
    QAR_UART_IRQ_LIN_BREAK  | \
    QAR_UART_IRQ_LIN_HEADER | \
    QAR_UART_IRQ_LIN_SLAVE)

#define QAR_CAN_IRQ_ALL    (\
    QAR_CAN_IRQ_RX_READY | \
    QAR_CAN_IRQ_TX_DONE  | \
    QAR_CAN_IRQ_RX_OVF)

#define QAR_TIMER_STATUS_ALL (\
    QAR_TIMER_STATUS_CMP0     | \
    QAR_TIMER_STATUS_CMP1     | \
    QAR_TIMER_STATUS_WDT      | \
    QAR_TIMER_STATUS_CAPTURE0 | \
    QAR_TIMER_STATUS_CAPTURE1)

#define QAR_SPI_IRQ_ALL   (\
    QAR_SPI_IRQ_RX_READY  | \
    QAR_SPI_IRQ_TX_EMPTY  | \
    QAR_SPI_IRQ_FAULT     | \
    QAR_SPI_IRQ_TX_OVF    | \
    QAR_SPI_IRQ_RX_OVF    | \
    QAR_SPI_IRQ_CS_FAULT)

#define QAR_I2C_IRQ_ALL   (\
    QAR_I2C_IRQ_RX_READY | \
    QAR_I2C_IRQ_TX_EMPTY | \
    QAR_I2C_IRQ_FAULT    | \
    QAR_I2C_IRQ_TX_OVF   | \
    QAR_I2C_IRQ_RX_OVF   | \
    QAR_I2C_IRQ_NACK)

#define QAR_ADC_IRQ_ALL   (\
    QAR_ADC_IRQ_DATA_READY | \
    QAR_ADC_IRQ_OVERRUN)

static void init_gpio_block(uint32_t base)
{
    qar_gpio_config_dir(base, 0x0u);
    qar_gpio_write(base, 0x0u);
    QAR_GPIO_ALT_PWM(base) = 0x0u;
    qar_gpio_config_irq(base, 0x0u, 0x0u, 0x0u);
    qar_gpio_config_debounce(base, 0x0u, 0);
    qar_gpio_clear_irq(base, 0xFFFFFFFFu);
}

static void init_timer_block(uint32_t base)
{
    QAR_TIMER_CTRL(base) = 0x0u;
    QAR_TIMER_IRQ_EN(base) = 0x0u;
    QAR_TIMER_STATUS(base) = QAR_TIMER_STATUS_ALL;
    QAR_TIMER_PRESCALE(base) = 0x0u;
    QAR_TIMER_CMP0(base) = 0x0u;
    QAR_TIMER_CMP0_PERIOD(base) = 0x0u;
    QAR_TIMER_CMP1(base) = 0x0u;
    QAR_TIMER_CMP1_PERIOD(base) = 0x0u;
    QAR_TIMER_PWM0_PERIOD(base) = 0x0u;
    QAR_TIMER_PWM0_DUTY(base) = 0x0u;
    QAR_TIMER_PWM1_PERIOD(base) = 0x0u;
    QAR_TIMER_PWM1_DUTY(base) = 0x0u;
    QAR_TIMER_WDT_LOAD(base) = 0x0u;
    QAR_TIMER_WDT_CTRL(base) = 0x0u;
    QAR_TIMER_CAPTURE_CTRL(base) = 0x0u;
}

static void init_uart_block(uint32_t base)
{
    QAR_UART_CTRL(base) = 0x0u;
    QAR_UART_BAUD(base) = QAR_UART_BOOT_DIV;
    QAR_UART_RS485(base) = 0x0u;
    QAR_UART_IDLE_CFG(base) = 0x0u;
    QAR_UART_LIN_CTRL(base) = 13u; /* 13 bit-period break by default */
    QAR_UART_LIN_SLAVE(base) = 0x0u;
    qar_uart_disable_irq(base, QAR_UART_IRQ_ALL);
    qar_uart_clear_irq(base, QAR_UART_IRQ_ALL);
    qar_uart_lin_clear_break(base);
}

static void init_can_block(uint32_t base)
{
    QAR_CAN_CTRL(base) = 0x0u;
    QAR_CAN_BITTIME(base) = QAR_CAN_BOOT_BITTIME;
    QAR_CAN_FILTER_ID(base) = 0x0u;
    QAR_CAN_FILTER_MASK(base) = 0x0u;
    qar_can_disable_irq(base, QAR_CAN_IRQ_ALL);
    qar_can_clear_irq(base, QAR_CAN_IRQ_ALL);
    qar_can_flush_rx(base);
}

static void init_spi_block(uint32_t base)
{
    QAR_SPI_CTRL(base) = 0x0u;
    QAR_SPI_CLKDIV(base) = QAR_SPI_BOOT_CLKDIV;
    QAR_SPI_CS(base) = 0xFFFFFFFFu;
    QAR_SPI_IRQ_EN(base) = 0x0u;
    QAR_SPI_IRQ_STATUS(base) = QAR_SPI_IRQ_ALL;
}

static void init_i2c_block(uint32_t base)
{
    QAR_I2C_CTRL(base) = 0x0u;
    QAR_I2C_CLKDIV(base) = QAR_I2C_BOOT_CLKDIV;
    QAR_I2C_IRQ_EN(base) = 0x0u;
    QAR_I2C_IRQ_STATUS(base) = QAR_I2C_IRQ_ALL;
}

static void init_adc_block(uint32_t base)
{
    QAR_ADC_CTRL(base) = 0x0u;
    QAR_ADC_SEQ_MASK(base) = 0x0u;
    QAR_ADC_SAMPLE_DIV(base) = 0x0u;
    QAR_ADC_IRQ_EN(base) = 0x0u;
    QAR_ADC_IRQ_STATUS(base) = QAR_ADC_IRQ_ALL;
}

void qar_sdk_init(void)
{
    init_gpio_block(QAR_GPIO0_BASE);
    init_timer_block(QAR_TIMER0_BASE);
    init_uart_block(QAR_UART0_BASE);
    init_uart_block(QAR_UART1_BASE);
    init_can_block(QAR_CAN0_BASE);
    init_spi_block(QAR_SPI0_BASE);
    init_i2c_block(QAR_I2C0_BASE);
    init_adc_block(QAR_ADC0_BASE);
}
