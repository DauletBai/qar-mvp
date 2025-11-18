#include <stdint.h>

#include "hal/gpio.h"
#include "hal/timer.h"

#define GPIO_BASE QAR_GPIO0_BASE
#define TIMER_BASE QAR_TIMER0_BASE

static void firmware_delay(uint32_t ticks)
{
    /* crude busy-wait using timer counter */
    uint32_t start = QAR_TIMER_COUNTER(TIMER_BASE);
    while ((QAR_TIMER_COUNTER(TIMER_BASE) - start) < ticks)
        ;
}

int main(void)
{
    /* Configure lower 8 pins as outputs, bit 8 as input */
    qar_gpio_config_dir(GPIO_BASE, 0x00FFu);

    /* Enable PWM hand-off for pins 0..1 if firmware uses timer PWM */
    QAR_GPIO_ALT_PWM(GPIO_BASE) = 0x0003u;

    /* Set initial output pattern */
    qar_gpio_write(GPIO_BASE, 0x0005u);

    /* Configure IRQ/filters for button on bit 8 */
    const uint32_t button_mask = 1u << 8;
    qar_gpio_config_irq(GPIO_BASE, button_mask, button_mask, button_mask);
    qar_gpio_config_debounce(GPIO_BASE, button_mask, 64);

    /* Enable timer with a simple prescaler so firmware_delay works */
    qar_timer_init(TIMER_BASE, 0, QAR_TIMER_CTRL_ENABLE);

    while (1) {
        uint32_t irq_status = QAR_GPIO_IRQ_STATUS(GPIO_BASE);
        if (irq_status & button_mask) {
            /* Toggle an indicator LED on pin 0 and clear IRQ */
            qar_gpio_set(GPIO_BASE, 0x1u);
            firmware_delay(1000);
            qar_gpio_clear(GPIO_BASE, 0x1u);
            qar_gpio_clear_irq(GPIO_BASE, button_mask);
        }

        /* Simple heartbeat across pins 0..7 */
        static uint32_t pattern = 0x0001u;
        qar_gpio_write(GPIO_BASE, pattern);
        pattern = (pattern == 0x0080u) ? 0x0001u : (pattern << 1);
        firmware_delay(5000);
    }

    return 0;
}
