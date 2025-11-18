#include <stdint.h>

#include "hal/timer.h"
#include "hal/gpio.h"

#define TIMER_BASE QAR_TIMER0_BASE
#define GPIO_BASE  QAR_GPIO0_BASE

static void pwm_config(uint32_t period, uint32_t duty0, uint32_t duty1)
{
    QAR_TIMER_PWM0_PERIOD(TIMER_BASE) = period;
    QAR_TIMER_PWM0_DUTY(TIMER_BASE)   = duty0;
    QAR_TIMER_PWM1_PERIOD(TIMER_BASE) = period;
    QAR_TIMER_PWM1_DUTY(TIMER_BASE)   = duty1;
}

static void capture_start(void)
{
    QAR_TIMER_CAPTURE_CTRL(TIMER_BASE) = 0x3u; /* enable capture on both channels */
}

static uint32_t capture_read(uint32_t channel)
{
    if (channel == 0)
        return QAR_TIMER_CAPTURE0_VALUE(TIMER_BASE);
    return QAR_TIMER_CAPTURE1_VALUE(TIMER_BASE);
}

int main(void)
{
    /* Route PWM outputs to GPIO pins 0 and 1 */
    QAR_GPIO_ALT_PWM(GPIO_BASE) = 0x3u;

    /* Configure timer: enable auto reload for CMP0/1 */
    qar_timer_init(TIMER_BASE, 0, QAR_TIMER_CTRL_ENABLE |
                                  QAR_TIMER_CTRL_CMP0_AUTO |
                                  QAR_TIMER_CTRL_CMP1_AUTO);

    pwm_config(1024, 256, 768);
    capture_start();

    while (1) {
        /* simple ramp on duty cycle */
        for (uint32_t duty = 0; duty < 1024; duty += 64) {
            QAR_TIMER_PWM0_DUTY(TIMER_BASE) = duty;
            QAR_TIMER_PWM1_DUTY(TIMER_BASE) = 1023 - duty;

            /* dummy read to simulate diagnostics */
            volatile uint32_t cap0 = capture_read(0);
            volatile uint32_t cap1 = capture_read(1);
            (void)cap0;
            (void)cap1;
        }
    }

    return 0;
}
