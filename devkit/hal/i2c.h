#ifndef QAR_HAL_I2C_H
#define QAR_HAL_I2C_H

#include <stdint.h>

#define QAR_I2C0_BASE 0x40004400u

#define QAR_I2C_REG(base, offset) (*((volatile uint32_t *)((base) + (offset))))

#define QAR_I2C_CTRL(base)     QAR_I2C_REG((base), 0x00)
#define QAR_I2C_STATUS(base)   QAR_I2C_REG((base), 0x04)
#define QAR_I2C_CLKDIV(base)   QAR_I2C_REG((base), 0x08)
#define QAR_I2C_ADDR(base)     QAR_I2C_REG((base), 0x0C)
#define QAR_I2C_DATA(base)     QAR_I2C_REG((base), 0x10)
#define QAR_I2C_CMD(base)      QAR_I2C_REG((base), 0x14)
#define QAR_I2C_IRQ_EN(base)   QAR_I2C_REG((base), 0x18)
#define QAR_I2C_IRQ_STATUS(base) QAR_I2C_REG((base), 0x1C)

#define QAR_I2C_CTRL_ENABLE    (1u << 0)
#define QAR_I2C_CTRL_START     (1u << 1)
#define QAR_I2C_CTRL_STOP      (1u << 2)
#define QAR_I2C_CTRL_ACK       (1u << 3)

#define QAR_I2C_STATUS_BUSY    (1u << 0)
#define QAR_I2C_STATUS_NACK    (1u << 1)
#define QAR_I2C_STATUS_ARB_LOST (1u << 2)
#define QAR_I2C_STATUS_RX_VALID (1u << 3)
#define QAR_I2C_STATUS_TX_READY (1u << 4)

static inline void qar_i2c_init(uint32_t base, uint32_t clk_divider)
{
    QAR_I2C_CLKDIV(base) = clk_divider;
    QAR_I2C_CTRL(base) = QAR_I2C_CTRL_ENABLE;
}

static inline void qar_i2c_set_address(uint32_t base, uint32_t addr)
{
    QAR_I2C_ADDR(base) = addr;
}

static inline void qar_i2c_write_byte(uint32_t base, uint8_t byte)
{
    while ((QAR_I2C_STATUS(base) & QAR_I2C_STATUS_TX_READY) == 0)
        ;
    QAR_I2C_DATA(base) = byte;
    QAR_I2C_CMD(base) = 0x1; /* issue write */
}

static inline uint8_t qar_i2c_read_byte(uint32_t base, int ack)
{
    QAR_I2C_CMD(base) = ack ? 0x2 : 0x0;
    while ((QAR_I2C_STATUS(base) & QAR_I2C_STATUS_RX_VALID) == 0)
        ;
    return (uint8_t)(QAR_I2C_DATA(base) & 0xFF);
}

#endif /* QAR_HAL_I2C_H */
