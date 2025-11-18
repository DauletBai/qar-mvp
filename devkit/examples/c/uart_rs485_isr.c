#include <stdint.h>

#include "hal/uart.h"

#define UART_BASE QAR_UART0_BASE

volatile uint32_t idle_count = 0;

void uart_isr(void)
{
    uint32_t status = qar_uart_status(UART_BASE);
    if (status & QAR_UART_STATUS_IDLE) {
        idle_count++;
        qar_uart_clear_irq(UART_BASE, QAR_UART_IRQ_IDLE);
    }
}

int main(void)
{
    qar_uart_init(UART_BASE, 500, QAR_UART_CTRL_ENABLE);
    qar_uart_set_idle_cycles(UART_BASE, 1000);
    qar_uart_enable_irq(UART_BASE, QAR_UART_IRQ_IDLE);
    send_byte(UART_BASE, 0x33);
    send_byte(UART_BASE, 0x55);
    while (1) {}
    return 0;
}
