#include <stdint.h>

#include "hal/uart.h"

#define UART_BASE QAR_UART0_BASE

static void lin_send_payload(uint8_t byte0, uint8_t byte1)
{
    qar_uart_write(UART_BASE, byte0);
    qar_uart_write(UART_BASE, byte1);
}

int main(void)
{
    /* Configure UART0 for LIN mode (8N1, auto-direction disabled for clarity) */
    qar_uart_init(UART_BASE, 500, QAR_UART_CTRL_ENABLE);
    qar_uart_lin_set_break(UART_BASE, 16);         /* ~13 bit periods */

    const uint8_t lin_id = 0x3C;                   /* demo LIN ID */
    qar_uart_lin_set_tx_id(UART_BASE, lin_id);

    /* Configure slave auto-response (2-byte payload) and pre-load data before issuing the master header. */
    qar_uart_lin_config_slave(UART_BASE, lin_id, 2, 1);
    qar_uart_lin_arm_slave(UART_BASE);
    lin_send_payload(0x55, 0xAA);

    /* Fire automatic break + Sync/ID */
    qar_uart_lin_request_break(UART_BASE);
    qar_uart_lin_start_auto_header(UART_BASE);

    /* Wait until header is captured (STATUS bit). Polling loop demonstrates HAL usage. */
    while ((qar_uart_status(UART_BASE) & QAR_UART_STATUS_LIN_HEADER) == 0)
        ;

    /* Clear header IRQ and read back captured sync/ID for verification */
    qar_uart_clear_irq(UART_BASE, QAR_UART_IRQ_LIN_HEADER);
    volatile uint32_t header = qar_uart_lin_header(UART_BASE);
    (void)header;

    while (1) {
        /* Idle loop: a real firmware would now wait for slave response */
    }

    return 0;
}
