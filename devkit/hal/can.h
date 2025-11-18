#ifndef QAR_HAL_CAN_H
#define QAR_HAL_CAN_H

#include <stdint.h>

#define QAR_CAN0_BASE 0x40003000u

#define QAR_CAN_REG(base, offset) (*((volatile uint32_t *)((base) + (offset))))

#define QAR_CAN_CTRL(base)      QAR_CAN_REG((base), 0x00)
#define QAR_CAN_STATUS(base)    QAR_CAN_REG((base), 0x04)
#define QAR_CAN_BITTIME(base)   QAR_CAN_REG((base), 0x08)
#define QAR_CAN_FILTER_ID(base) QAR_CAN_REG((base), 0x18)
#define QAR_CAN_FILTER_MASK(base) QAR_CAN_REG((base), 0x1C)
#define QAR_CAN_IRQ_EN(base)    QAR_CAN_REG((base), 0x10)
#define QAR_CAN_IRQ_STATUS(base) QAR_CAN_REG((base), 0x14)
#define QAR_CAN_TX_ID(base)     QAR_CAN_REG((base), 0x20)
#define QAR_CAN_TX_DLC(base)    QAR_CAN_REG((base), 0x24)
#define QAR_CAN_TX_DATA0(base)  QAR_CAN_REG((base), 0x28)
#define QAR_CAN_TX_DATA1(base)  QAR_CAN_REG((base), 0x2C)
#define QAR_CAN_TX_CMD(base)    QAR_CAN_REG((base), 0x30)
#define QAR_CAN_RX_ID(base)     QAR_CAN_REG((base), 0x34)
#define QAR_CAN_RX_DLC(base)    QAR_CAN_REG((base), 0x38)
#define QAR_CAN_RX_DATA0(base)  QAR_CAN_REG((base), 0x3C)
#define QAR_CAN_RX_DATA1(base)  QAR_CAN_REG((base), 0x40)
#define QAR_CAN_RX_FIFO(base)   QAR_CAN_REG((base), 0x44)

#define QAR_CAN_CTRL_ENABLE       (1u << 0)
#define QAR_CAN_CTRL_LOOPBACK     (1u << 1)
#define QAR_CAN_CTRL_LISTEN_ONLY  (1u << 2)
#define QAR_CAN_CTRL_FILTER_BYPASS (1u << 3)

#define QAR_CAN_STATUS_RX_PENDING (1u << 0)
#define QAR_CAN_STATUS_TX_IDLE    (1u << 1)
#define QAR_CAN_STATUS_RX_OVERFLOW (1u << 2)

#define QAR_CAN_IRQ_RX_READY (1u << 0)
#define QAR_CAN_IRQ_TX_DONE  (1u << 1)
#define QAR_CAN_IRQ_RX_OVF   (1u << 2)

static inline void qar_can_init(uint32_t base, uint32_t bittime, uint32_t ctrl_flags)
{
    QAR_CAN_BITTIME(base) = bittime;
    QAR_CAN_CTRL(base) = ctrl_flags | QAR_CAN_CTRL_ENABLE;
}

static inline void qar_can_set_ctrl(uint32_t base, uint32_t ctrl_flags)
{
    QAR_CAN_CTRL(base) = ctrl_flags;
}

static inline void qar_can_enable_irq(uint32_t base, uint32_t mask)
{
    QAR_CAN_IRQ_STATUS(base) = mask; /* clear sticky bits before enabling */
    QAR_CAN_IRQ_EN(base) |= mask;
}

static inline void qar_can_disable_irq(uint32_t base, uint32_t mask)
{
    QAR_CAN_IRQ_EN(base) &= ~mask;
}

static inline void qar_can_clear_irq(uint32_t base, uint32_t mask)
{
    QAR_CAN_IRQ_STATUS(base) = mask;
}

static inline void qar_can_send_word(uint32_t base, uint32_t id, uint32_t data0, uint32_t data1, uint8_t dlc)
{
    QAR_CAN_TX_ID(base) = id;
    QAR_CAN_TX_DLC(base) = dlc;
    QAR_CAN_TX_DATA0(base) = data0;
    QAR_CAN_TX_DATA1(base) = data1;
    QAR_CAN_TX_CMD(base) = 1;
}

static inline int qar_can_rx_ready(uint32_t base)
{
    return (QAR_CAN_STATUS(base) & QAR_CAN_STATUS_RX_PENDING) != 0;
}

static inline void qar_can_read_payload(uint32_t base, uint32_t *id, uint32_t *data0, uint32_t *data1)
{
    if (id)
        *id = QAR_CAN_RX_ID(base);
    if (data0)
        *data0 = QAR_CAN_RX_DATA0(base);
    if (data1)
        *data1 = QAR_CAN_RX_DATA1(base);
}

static inline void qar_can_pop_rx(uint32_t base)
{
    QAR_CAN_RX_FIFO(base) = 0x1;
}

static inline void qar_can_flush_rx(uint32_t base)
{
    QAR_CAN_RX_FIFO(base) = 0x2;
}

static inline uint32_t qar_can_rx_count(uint32_t base)
{
    return QAR_CAN_RX_FIFO(base) & 0x7;
}

#endif /* QAR_HAL_CAN_H */
