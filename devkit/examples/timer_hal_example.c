#include "hal/timer.h"

static volatile uint32_t pwm_flags;
static volatile uint32_t capture_log[2];

void timer_example(void)
{
    uint32_t base = QAR_TIMER0_BASE;

    /* Prescale = 0 → tick every core cycle, enable CMP0 auto-reload */
    qar_timer_init(base, 0, QAR_TIMER_CTRL_CMP0_AUTO);
    qar_timer_set_compare0(base, 500, 500); /* 500-cycle heartbeat */
    qar_timer_enable_irq(base, QAR_TIMER_STATUS_CMP0);

    /* Configure PWM0 = 50% duty, PWM1 = 25% duty */
    qar_timer_config_pwm(base, 0, 128, 64);
    qar_timer_config_pwm(base, 1, 128, 32);

    /* Periodically kick watchdog (configured for ~10 ms window) */
    qar_timer_config_wdt(base, 50000, 1);

    /* Manual capture example */
    capture_log[0] = qar_timer_manual_capture(base, 0);
    capture_log[1] = qar_timer_manual_capture(base, 1);

    /* Poll PWM status bits until both channels transition low */
    while ((qar_timer_pwm_status(base) & 0x3) != 0)
        pwm_flags++;

    /* Clear all pending events */
    qar_timer_clear_status(base,
        QAR_TIMER_STATUS_CMP0 |
        QAR_TIMER_STATUS_WDT |
        QAR_TIMER_STATUS_CAPTURE0 |
        QAR_TIMER_STATUS_CAPTURE1);
}
