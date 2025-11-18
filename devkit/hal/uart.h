#ifndef QAR_HAL_UART_H
#define QAR_HAL_UART_H

#include <stdint.h>
#include "mmio.h"

#define QAR_UART0_BASE 0x40001000u
#define QAR_UART1_BASE 0x40002000u

#define QAR_UART_REG(base, offset) QAR_MMIO32((base), (offset))

#define QAR_UART_DATA(base)       QAR_UART_REG((base), 0x00)
#define QAR_UART_STATUS(base)     QAR_UART_REG((base), 0x04)
#define QAR_UART_CTRL(base)       QAR_UART_REG((base), 0x08)
#define QAR_UART_BAUD(base)       QAR_UART_REG((base), 0x0C)
#define QAR_UART_IRQ_EN(base)     QAR_UART_REG((base), 0x10)
#define QAR_UART_IRQ_STATUS(base) QAR_UART_REG((base), 0x14)
#define QAR_UART_RS485(base)      QAR_UART_REG((base), 0x18)
#define QAR_UART_IDLE_CFG(base)   QAR_UART_REG((base), 0x1C)
#define QAR_UART_LIN_CTRL(base)   QAR_UART_REG((base), 0x20)
#define QAR_UART_LIN_CMD(base)    QAR_UART_REG((base), 0x24)
#define QAR_UART_LIN_TX_ID(base)  QAR_UART_REG((base), 0x28)
#define QAR_UART_LIN_HEADER(base) QAR_UART_REG((base), 0x2C)

#define QAR_UART_CTRL_ENABLE     (1u << 0)
#define QAR_UART_CTRL_PARITY_EN  (1u << 1)
#define QAR_UART_CTRL_PARITY_ODD (1u << 2)
#define QAR_UART_CTRL_TWO_STOP   (1u << 3)

#define QAR_UART_STATUS_RX_READY (1u << 0)
#define QAR_UART_STATUS_TX_SPACE (1u << 1)
#define QAR_UART_STATUS_FRAMING  (1u << 2)
#define QAR_UART_STATUS_OVERRUN  (1u << 3)
#define QAR_UART_STATUS_TX_BUSY  (1u << 4)
#define QAR_UART_STATUS_PARITY   (1u << 5)
#define QAR_UART_STATUS_IDLE     (1u << 6)
#define QAR_UART_STATUS_LIN_BREAK  (1u << 7)
#define QAR_UART_STATUS_LIN_HEADER (1u << 8)
#define QAR_UART_STATUS_LIN_SYNCERR (1u << 9)

#define QAR_UART_IRQ_RX_READY    (1u << 0)
#define QAR_UART_IRQ_TX_EMPTY    (1u << 1)
#define QAR_UART_IRQ_ERROR       (1u << 2)
#define QAR_UART_IRQ_IDLE        (1u << 3)
#define QAR_UART_IRQ_LIN_BREAK   (1u << 4)
#define QAR_UART_IRQ_LIN_HEADER  (1u << 5)

static inline void qar_uart_init(uint32_t base, uint32_t baud_divider, uint32_t ctrl_flags)
{
    QAR_UART_BAUD(base) = baud_divider;
    QAR_UART_CTRL(base) = ctrl_flags | QAR_UART_CTRL_ENABLE;
    QAR_UART_IRQ_EN(base) = 0x0;
    QAR_UART_IDLE_CFG(base) = 0;
    QAR_UART_LIN_CTRL(base) = 13;
}

static inline void qar_uart_set_idle_cycles(uint32_t base, uint32_t cycles)
{
    QAR_UART_IDLE_CFG(base) = cycles;
}

static inline void qar_uart_enable_irq(uint32_t base, uint32_t mask)
{
    QAR_UART_IRQ_EN(base) |= mask;
}

static inline void qar_uart_disable_irq(uint32_t base, uint32_t mask)
{
    QAR_UART_IRQ_EN(base) &= ~mask;
}

static inline void qar_uart_clear_irq(uint32_t base, uint32_t mask)
{
    QAR_UART_IRQ_STATUS(base) = mask;
}

static inline void qar_uart_config_rs485(uint32_t base, uint32_t value)
{
    QAR_UART_RS485(base) = value;
}

static inline void qar_uart_lin_set_break(uint32_t base, uint32_t bit_periods)
{
    QAR_UART_LIN_CTRL(base) = bit_periods;
}

static inline void qar_uart_lin_request_break(uint32_t base)
{
    QAR_UART_LIN_CMD(base) = 0x1;
}

static inline void qar_uart_lin_clear_break(uint32_t base)
{
    QAR_UART_LIN_CMD(base) = 0x2;
}

static inline void qar_uart_lin_arm_header(uint32_t base)
{
    QAR_UART_LIN_CMD(base) = 0x4;
}

static inline void qar_uart_lin_set_tx_id(uint32_t base, uint8_t id)
{
    QAR_UART_LIN_TX_ID(base) = (uint32_t)id;
}

static inline void qar_uart_lin_start_auto_header(uint32_t base)
{
    QAR_UART_LIN_CMD(base) = 0x8;
}

static inline uint32_t qar_uart_lin_header(uint32_t base)
{
    return QAR_UART_LIN_HEADER(base);
}

static inline uint32_t qar_uart_status(uint32_t base)
{
    return QAR_UART_STATUS(base);
}

static inline int qar_uart_can_write(uint32_t base)
{
    return (QAR_UART_STATUS(base) & QAR_UART_STATUS_TX_SPACE) != 0;
}

static inline void qar_uart_write(uint32_t base, uint8_t byte)
{
    while (!qar_uart_can_write(base))
        ;
    QAR_UART_DATA(base) = byte;
}

static inline int qar_uart_available(uint32_t base)
{
    return (QAR_UART_STATUS(base) & QAR_UART_STATUS_RX_READY) != 0;
}

static inline int qar_uart_read(uint32_t base)
{
    if (!qar_uart_available(base))
        return -1;
    return (int)(QAR_UART_DATA(base) & 0xFF);
}

#endif /* QAR_HAL_UART_H */
