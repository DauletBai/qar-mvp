#ifndef QAR_HAL_CAN_H
#define QAR_HAL_CAN_H

#include <stdint.h>

#define QAR_CAN0_BASE 0x40003000u

#define QAR_CAN_REG(base, offset) (*((volatile uint32_t *)((base) + (offset))))

#define QAR_CAN_CTRL(base)      QAR_CAN_REG((base), 0x00)
#define QAR_CAN_STATUS(base)    QAR_CAN_REG((base), 0x04)
#define QAR_CAN_BITTIME(base)   QAR_CAN_REG((base), 0x08)
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

static inline void qar_can_init(uint32_t base, uint32_t bittime, int loopback)
{
    QAR_CAN_BITTIME(base) = bittime;
    QAR_CAN_CTRL(base) = (loopback ? 0x2 : 0x0) | 0x1;
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
    return (QAR_CAN_STATUS(base) & 0x1) != 0;
}

static inline uint32_t qar_can_read_word(uint32_t base)
{
    return QAR_CAN_RX_DATA0(base);
}

#endif /* QAR_HAL_CAN_H */
