#ifndef QAR_HAL_SPI_H
#define QAR_HAL_SPI_H

#include <stdint.h>
#include "mmio.h"

#define QAR_SPI0_BASE 0x40004000u

#define QAR_SPI_REG(base, offset) QAR_MMIO32((base), (offset))

#define QAR_SPI_CTRL(base)     QAR_SPI_REG((base), 0x00)
#define QAR_SPI_STATUS(base)   QAR_SPI_REG((base), 0x04)
#define QAR_SPI_CLKDIV(base)   QAR_SPI_REG((base), 0x08)
#define QAR_SPI_TXDATA(base)   QAR_SPI_REG((base), 0x0C)
#define QAR_SPI_RXDATA(base)   QAR_SPI_REG((base), 0x10)
#define QAR_SPI_CS(base)       QAR_SPI_REG((base), 0x14)
#define QAR_SPI_IRQ_EN(base)   QAR_SPI_REG((base), 0x18)
#define QAR_SPI_IRQ_STATUS(base) QAR_SPI_REG((base), 0x1C)

#define QAR_SPI_CTRL_ENABLE    (1u << 0)
#define QAR_SPI_CTRL_CPOL      (1u << 1)
#define QAR_SPI_CTRL_CPHA      (1u << 2)
#define QAR_SPI_CTRL_LSB_FIRST (1u << 3)
#define QAR_SPI_CTRL_LOOPBACK  (1u << 4)

#define QAR_SPI_STATUS_TX_READY (1u << 0)
#define QAR_SPI_STATUS_RX_VALID (1u << 1)
#define QAR_SPI_STATUS_BUSY     (1u << 2)
#define QAR_SPI_STATUS_FAULT    (1u << 3)
#define QAR_SPI_STATUS_TX_OVF   (1u << 4)
#define QAR_SPI_STATUS_RX_OVF   (1u << 5)
#define QAR_SPI_STATUS_CS_FAULT (1u << 6)

#define QAR_SPI_IRQ_RX_READY    (1u << 0)
#define QAR_SPI_IRQ_TX_EMPTY    (1u << 1)
#define QAR_SPI_IRQ_FAULT       (1u << 2)
#define QAR_SPI_IRQ_TX_OVF      (1u << 3)
#define QAR_SPI_IRQ_RX_OVF      (1u << 4)
#define QAR_SPI_IRQ_CS_FAULT    (1u << 5)

static inline void qar_spi_init(uint32_t base, uint32_t clk_div, uint32_t ctrl_flags)
{
    QAR_SPI_CLKDIV(base) = clk_div;
    QAR_SPI_CTRL(base) = ctrl_flags | QAR_SPI_CTRL_ENABLE;
}

static inline void qar_spi_set_cs(uint32_t base, uint32_t mask)
{
    QAR_SPI_CS(base) = mask;
}

static inline void qar_spi_write(uint32_t base, uint32_t value)
{
    while ((QAR_SPI_STATUS(base) & QAR_SPI_STATUS_TX_READY) == 0)
        ;
    QAR_SPI_TXDATA(base) = value;
}

static inline uint32_t qar_spi_read(uint32_t base)
{
    while ((QAR_SPI_STATUS(base) & QAR_SPI_STATUS_RX_VALID) == 0)
        ;
    return QAR_SPI_RXDATA(base);
}

#endif /* QAR_HAL_SPI_H */
