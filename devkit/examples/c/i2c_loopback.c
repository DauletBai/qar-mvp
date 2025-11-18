#include <stdint.h>

#include "hal/i2c.h"

#define I2C_BASE QAR_I2C0_BASE
#define QAR_I2C_CTRL_LOOPBACK_ACK (1u << 4)

static void wait_cmd_clear(uint32_t cmd_mask)
{
    while (QAR_I2C_CMD(I2C_BASE) & cmd_mask)
        ;
}

static void wait_idle(void)
{
    while (QAR_I2C_STATUS(I2C_BASE) & QAR_I2C_STATUS_BUSY)
        ;
}

int main(void)
{
    qar_i2c_init(I2C_BASE, 10);
    QAR_I2C_CTRL(I2C_BASE) = QAR_I2C_CTRL_ENABLE | QAR_I2C_CTRL_LOOPBACK_ACK;

    /* Stage 7-bit address (0x50<<1) and payload byte */
    qar_i2c_stage_tx(I2C_BASE, 0xA0u);
    qar_i2c_stage_tx(I2C_BASE, 0x55u);

    qar_i2c_issue_cmd(I2C_BASE, QAR_I2C_CMD_START);
    wait_cmd_clear(QAR_I2C_CMD_START);

    qar_i2c_issue_cmd(I2C_BASE, QAR_I2C_CMD_WRITE);
    wait_cmd_clear(QAR_I2C_CMD_WRITE);
    qar_i2c_issue_cmd(I2C_BASE, QAR_I2C_CMD_WRITE);
    wait_cmd_clear(QAR_I2C_CMD_WRITE);

    qar_i2c_issue_cmd(I2C_BASE, QAR_I2C_CMD_STOP);
    wait_cmd_clear(QAR_I2C_CMD_STOP);
    wait_idle();

    volatile uint32_t status = QAR_I2C_STATUS(I2C_BASE);
    (void)status;

    while (1) {
    }

    return 0;
}
