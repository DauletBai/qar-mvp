#ifndef QAR_SDK_HAL_INIT_H
#define QAR_SDK_HAL_INIT_H

#include "hal/uart.h"

static inline void qar_sdk_init(void)
{
    /* Example init: ensure UART idle IRQs are disabled at boot. */
    qar_uart_disable_irq(QAR_UART0_BASE, 0xFFFFFFFFu);
}

#endif /* QAR_SDK_HAL_INIT_H */
