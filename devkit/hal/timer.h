#ifndef QAR_HAL_TIMER_H
#define QAR_HAL_TIMER_H

#include <stdint.h>
#include "mmio.h"

#define QAR_TIMER0_BASE 0x40005000u

#define QAR_TIMER_REG(base, offset) QAR_MMIO32((base), (offset))

#define QAR_TIMER_CTRL(base)         QAR_TIMER_REG((base), 0x00)
#define QAR_TIMER_PRESCALE(base)     QAR_TIMER_REG((base), 0x04)
#define QAR_TIMER_COUNTER(base)      QAR_TIMER_REG((base), 0x08)
#define QAR_TIMER_STATUS(base)       QAR_TIMER_REG((base), 0x0C)
#define QAR_TIMER_IRQ_EN(base)       QAR_TIMER_REG((base), 0x10)
#define QAR_TIMER_CMP0(base)         QAR_TIMER_REG((base), 0x14)
#define QAR_TIMER_CMP0_PERIOD(base)  QAR_TIMER_REG((base), 0x18)
#define QAR_TIMER_CMP1(base)         QAR_TIMER_REG((base), 0x1C)
#define QAR_TIMER_CMP1_PERIOD(base)  QAR_TIMER_REG((base), 0x20)
#define QAR_TIMER_WDT_LOAD(base)     QAR_TIMER_REG((base), 0x24)
#define QAR_TIMER_WDT_CTRL(base)     QAR_TIMER_REG((base), 0x28)
#define QAR_TIMER_WDT_COUNT(base)    QAR_TIMER_REG((base), 0x2C)
#define QAR_TIMER_PWM0_PERIOD(base)  QAR_TIMER_REG((base), 0x30)
#define QAR_TIMER_PWM0_DUTY(base)    QAR_TIMER_REG((base), 0x34)
#define QAR_TIMER_PWM1_PERIOD(base)  QAR_TIMER_REG((base), 0x38)
#define QAR_TIMER_PWM1_DUTY(base)    QAR_TIMER_REG((base), 0x3C)
#define QAR_TIMER_PWM_STATUS(base)   QAR_TIMER_REG((base), 0x40)
#define QAR_TIMER_CAPTURE_CTRL(base) QAR_TIMER_REG((base), 0x44)
#define QAR_TIMER_CAPTURE0_VALUE(base) QAR_TIMER_REG((base), 0x48)
#define QAR_TIMER_CAPTURE1_VALUE(base) QAR_TIMER_REG((base), 0x4C)

#define QAR_TIMER_CTRL_ENABLE      (1u << 0)
#define QAR_TIMER_CTRL_CMP0_AUTO   (1u << 1)
#define QAR_TIMER_CTRL_CMP1_AUTO   (1u << 2)

#define QAR_TIMER_STATUS_CMP0      (1u << 0)
#define QAR_TIMER_STATUS_CMP1      (1u << 1)
#define QAR_TIMER_STATUS_WDT       (1u << 2)
#define QAR_TIMER_STATUS_CAPTURE0  (1u << 3)
#define QAR_TIMER_STATUS_CAPTURE1  (1u << 4)

static inline void qar_timer_init(uint32_t base, uint32_t prescale, uint32_t ctrl_flags)
{
    QAR_TIMER_PRESCALE(base) = prescale;
    QAR_TIMER_CTRL(base) = ctrl_flags | QAR_TIMER_CTRL_ENABLE;
}

static inline void qar_timer_set_compare0(uint32_t base, uint32_t value, uint32_t period)
{
    QAR_TIMER_CMP0(base) = value;
    QAR_TIMER_CMP0_PERIOD(base) = period;
}

static inline void qar_timer_set_compare1(uint32_t base, uint32_t value, uint32_t period)
{
    QAR_TIMER_CMP1(base) = value;
    QAR_TIMER_CMP1_PERIOD(base) = period;
}

static inline void qar_timer_enable_irq(uint32_t base, uint32_t mask)
{
    QAR_TIMER_IRQ_EN(base) |= mask;
}

static inline void qar_timer_disable_irq(uint32_t base, uint32_t mask)
{
    QAR_TIMER_IRQ_EN(base) &= ~mask;
}

static inline void qar_timer_clear_status(uint32_t base, uint32_t mask)
{
    QAR_TIMER_STATUS(base) = mask;
}

static inline uint32_t qar_timer_counter(uint32_t base)
{
    return QAR_TIMER_COUNTER(base);
}

static inline void qar_timer_config_wdt(uint32_t base, uint32_t load, int enable_now)
{
    QAR_TIMER_WDT_LOAD(base) = load;
    QAR_TIMER_WDT_CTRL(base) = (enable_now ? 0x1 : 0x0) | (enable_now ? 0x2 : 0x0);
}

static inline void qar_timer_kick_wdt(uint32_t base)
{
    QAR_TIMER_WDT_CTRL(base) = 0x3;
}

static inline void qar_timer_config_pwm(uint32_t base, uint32_t channel, uint32_t period, uint32_t duty)
{
    if (channel == 0) {
        QAR_TIMER_PWM0_PERIOD(base) = period;
        QAR_TIMER_PWM0_DUTY(base) = duty;
    } else {
        QAR_TIMER_PWM1_PERIOD(base) = period;
        QAR_TIMER_PWM1_DUTY(base) = duty;
    }
}

static inline uint32_t qar_timer_pwm_status(uint32_t base)
{
    return QAR_TIMER_PWM_STATUS(base) & 0x3;
}

static inline uint32_t qar_timer_manual_capture(uint32_t base, uint32_t channel)
{
    uint32_t mask = (channel == 0) ? 0x1u : 0x2u;
    QAR_TIMER_CAPTURE_CTRL(base) = mask;
    if (channel == 0)
        return QAR_TIMER_CAPTURE0_VALUE(base);
    return QAR_TIMER_CAPTURE1_VALUE(base);
}

#endif /* QAR_HAL_TIMER_H */
