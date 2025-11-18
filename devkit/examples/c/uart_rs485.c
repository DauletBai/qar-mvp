#include <stdint.h>

#include "hal/uart.h"

#define UART_BASE QAR_UART0_BASE

static void send_byte(uint8_t b)
{
    qar_uart_write(UART_BASE, b);
}

int main(void)
{
    /* Configure UART0: enable, idle detection disabled, auto RS-485 direction */
    qar_uart_init(UART_BASE, 500, QAR_UART_CTRL_ENABLE);
    qar_uart_config_rs485(UART_BASE, 0x1u); /* auto direction */

    /* Enable idle interrupt */
    qar_uart_enable_irq(UART_BASE, QAR_UART_IRQ_IDLE);
    qar_uart_set_idle_cycles(UART_BASE, 1000);

    /* Transmit two bytes */
    send_byte(0x33);
    send_byte(0x55);

    /* Wait for idle interrupt */
    while ((qar_uart_status(UART_BASE) & QAR_UART_STATUS_IDLE) == 0)
        ;

    /* Clear idle interrupt */
    qar_uart_clear_irq(UART_BASE, QAR_UART_IRQ_IDLE);

    while (1) {
    }

    return 0;
}
