#include <stdint.h>

#include "hal/spi.h"

#define SPI_BASE QAR_SPI0_BASE

static uint8_t spi_exchange(uint8_t value)
{
    qar_spi_write(SPI_BASE, value);
    while ((QAR_SPI_STATUS(SPI_BASE) & QAR_SPI_STATUS_RX_VALID) == 0)
        ;
    return (uint8_t)(QAR_SPI_RXDATA(SPI_BASE) & 0xFF);
}

int main(void)
{
    qar_spi_init(SPI_BASE, 1, QAR_SPI_CTRL_LOOPBACK);
    qar_spi_set_cs(SPI_BASE, 0x1u);

    volatile uint8_t rx0 = spi_exchange(0xA5u);
    volatile uint8_t rx1 = spi_exchange(0x3Cu);

    (void)rx0;
    (void)rx1;

    while (1) {
    }

    return 0;
}
