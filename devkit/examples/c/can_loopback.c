#include <stdint.h>

#include "hal/can.h"

#define CAN_BASE QAR_CAN0_BASE

static void send_frame(uint32_t id, uint32_t data0, uint32_t data1, uint8_t dlc)
{
    qar_can_send_word(CAN_BASE, id, data0, data1, dlc);
}

static void drain_rx(void)
{
    uint32_t id = 0, data0 = 0, data1 = 0;
    qar_can_read_payload(CAN_BASE, &id, &data0, &data1);
    qar_can_pop_rx(CAN_BASE);

    /* Placeholder: in a real firmware we would log these into DMEM or act on them.
       Keeping the values volatile prevents the compiler from optimizing everything away. */
    volatile uint32_t last_id = id;
    volatile uint32_t last_data0 = data0;
    volatile uint32_t last_data1 = data1;
    (void)last_id;
    (void)last_data0;
    (void)last_data1;
}

int main(void)
{
    /* Configure CAN for internal loopback + filter bypass */
    uint32_t ctrl_flags = QAR_CAN_CTRL_LOOPBACK | QAR_CAN_CTRL_FILTER_BYPASS;
    qar_can_init(CAN_BASE, 0x00000013u, ctrl_flags);

    /* Program an 11-bit filter for IDs around 0x123 */
    QAR_CAN_FILTER_ID(CAN_BASE) = 0x123u;
    QAR_CAN_FILTER_MASK(CAN_BASE) = 0x7FFu;

    /* Enable RX/TX interrupts (polled in this demo) */
    qar_can_enable_irq(CAN_BASE, QAR_CAN_IRQ_RX_READY | QAR_CAN_IRQ_TX_DONE);

    /* Transmit two frames through loopback */
    send_frame(0x123u, 0xDEADBEEFu, 0u, 4);
    send_frame(0x321u, 0xCAFEBABEu, 0x01020304u, 8);

    /* Poll RX FIFO until both frames arrive */
    while (qar_can_rx_count(CAN_BASE) < 2)
        ;

    drain_rx();
    drain_rx();

    /* Quiet mode example: turn off loopback copy while still driving TX */
    ctrl_flags |= QAR_CAN_CTRL_LISTEN_ONLY;
    qar_can_set_ctrl(CAN_BASE, ctrl_flags);
    send_frame(0x200u, 0x11111111u, 0u, 4); /* observed on bus only */

    while (1) {
        /* Idle loop where firmware could enter low power or process other tasks */
    }
}
