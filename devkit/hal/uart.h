#ifndef QAR_HAL_UART_H
#define QAR_HAL_UART_H

#include <stdint.h>

#define QAR_UART0_BASE 0x40001000u
#define QAR_UART1_BASE 0x40002000u

#define QAR_UART_REG(base, offset) (*((volatile uint32_t *)((base) + (offset))))

#define QAR_UART_DATA(base)       QAR_UART_REG((base), 0x00)
#define QAR_UART_STATUS(base)     QAR_UART_REG((base), 0x04)
#define QAR_UART_CTRL(base)       QAR_UART_REG((base), 0x08)
#define QAR_UART_BAUD(base)       QAR_UART_REG((base), 0x0C)
#define QAR_UART_IRQ_EN(base)     QAR_UART_REG((base), 0x10)
#define QAR_UART_IRQ_STATUS(base) QAR_UART_REG((base), 0x14)
#define QAR_UART_RS485(base)      QAR_UART_REG((base), 0x18)

static inline void qar_uart_init(uint32_t base, uint32_t baud_divider)
{
    QAR_UART_CTRL(base) = 0x1; /* enable */
    QAR_UART_BAUD(base) = baud_divider;
    QAR_UART_IRQ_EN(base) = 0x0;
}

static inline int qar_uart_can_write(uint32_t base)
{
    return (QAR_UART_STATUS(base) & (1u << 1)) != 0;
}

static inline void qar_uart_write(uint32_t base, uint8_t byte)
{
    while (!qar_uart_can_write(base))
        ;
    QAR_UART_DATA(base) = byte;
}

static inline int qar_uart_available(uint32_t base)
{
    return (QAR_UART_STATUS(base) & 1u) != 0;
}

static inline int qar_uart_read(uint32_t base)
{
    if (!qar_uart_available(base))
        return -1;
    return (int)(QAR_UART_DATA(base) & 0xFF);
}

#endif /* QAR_HAL_UART_H */
