#ifndef QAR_HAL_TIMER_H
#define QAR_HAL_TIMER_H

#include <stdint.h>

#define QAR_TIMER0_BASE 0x40005000u

#define QAR_TIMER_REG(base, offset) (*((volatile uint32_t *)((base) + (offset))))

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

#define QAR_TIMER_CTRL_ENABLE      (1u << 0)
#define QAR_TIMER_CTRL_CMP0_AUTO   (1u << 1)
#define QAR_TIMER_CTRL_CMP1_AUTO   (1u << 2)

#define QAR_TIMER_STATUS_CMP0      (1u << 0)
#define QAR_TIMER_STATUS_CMP1      (1u << 1)
#define QAR_TIMER_STATUS_WDT       (1u << 2)

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

#endif /* QAR_HAL_TIMER_H */
