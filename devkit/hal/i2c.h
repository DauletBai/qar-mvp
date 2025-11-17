#ifndef QAR_HAL_I2C_H
#define QAR_HAL_I2C_H

#include <stdint.h>

#define QAR_I2C0_BASE 0x40004400u

#define QAR_I2C_REG(base, offset) (*((volatile uint32_t *)((base) + (offset))))

#define QAR_I2C_CTRL(base)     QAR_I2C_REG((base), 0x00)
#define QAR_I2C_CLKDIV(base)   QAR_I2C_REG((base), 0x04)
#define QAR_I2C_STATUS(base)   QAR_I2C_REG((base), 0x08)
#define QAR_I2C_IRQ_EN(base)   QAR_I2C_REG((base), 0x0C)
#define QAR_I2C_IRQ_STATUS(base) QAR_I2C_REG((base), 0x10)
#define QAR_I2C_TXDATA(base)   QAR_I2C_REG((base), 0x14)
#define QAR_I2C_RXDATA(base)   QAR_I2C_REG((base), 0x18)
#define QAR_I2C_CMD(base)      QAR_I2C_REG((base), 0x1C)

#define QAR_I2C_CTRL_ENABLE    (1u << 0)

#define QAR_I2C_STATUS_BUSY    (1u << 0)
#define QAR_I2C_STATUS_RX_RDY  (1u << 1)
#define QAR_I2C_STATUS_TX_EMPTY (1u << 2)
#define QAR_I2C_STATUS_FAULT   (1u << 3)

#define QAR_I2C_CMD_START      (1u << 0)
#define QAR_I2C_CMD_STOP       (1u << 1)
#define QAR_I2C_CMD_WRITE      (1u << 2)
#define QAR_I2C_CMD_READ       (1u << 3)

static inline void qar_i2c_init(uint32_t base, uint32_t clk_divider)
{
    QAR_I2C_CLKDIV(base) = clk_divider;
    QAR_I2C_CTRL(base) = QAR_I2C_CTRL_ENABLE;
}

static inline void qar_i2c_stage_tx(uint32_t base, uint8_t byte)
{
    QAR_I2C_TXDATA(base) = byte;
}

static inline void qar_i2c_issue_cmd(uint32_t base, uint32_t cmd)
{
    QAR_I2C_CMD(base) = cmd;
}

static inline uint8_t qar_i2c_pop_rx(uint32_t base)
{
    return (uint8_t)(QAR_I2C_RXDATA(base) & 0xFF);
}

#endif /* QAR_HAL_I2C_H */
