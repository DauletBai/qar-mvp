#ifndef QAR_HAL_GPIO_H
#define QAR_HAL_GPIO_H

#include <stdint.h>
#include "mmio.h"

#define QAR_GPIO0_BASE 0x40000000u

#define QAR_GPIO_REG(base, offset) QAR_MMIO32((base), (offset))

#define QAR_GPIO_DIR(base)        QAR_GPIO_REG((base), 0x00)
#define QAR_GPIO_OUT(base)        QAR_GPIO_REG((base), 0x04)
#define QAR_GPIO_IN(base)         QAR_GPIO_REG((base), 0x08)
#define QAR_GPIO_OUT_SET(base)    QAR_GPIO_REG((base), 0x0C)
#define QAR_GPIO_OUT_CLR(base)    QAR_GPIO_REG((base), 0x10)
#define QAR_GPIO_IRQ_EN(base)     QAR_GPIO_REG((base), 0x14)
#define QAR_GPIO_IRQ_STATUS(base) QAR_GPIO_REG((base), 0x18)
#define QAR_GPIO_ALT_PWM(base)    QAR_GPIO_REG((base), 0x1C)
#define QAR_GPIO_IRQ_RISE(base)   QAR_GPIO_REG((base), 0x20)
#define QAR_GPIO_IRQ_FALL(base)   QAR_GPIO_REG((base), 0x24)
#define QAR_GPIO_DB_EN(base)      QAR_GPIO_REG((base), 0x28)
#define QAR_GPIO_DB_CYCLES(base)  QAR_GPIO_REG((base), 0x2C)

static inline void qar_gpio_config_dir(uint32_t base, uint32_t dir_mask)
{
    QAR_GPIO_DIR(base) = dir_mask;
}

static inline void qar_gpio_write(uint32_t base, uint32_t value)
{
    QAR_GPIO_OUT(base) = value;
}

static inline void qar_gpio_set(uint32_t base, uint32_t mask)
{
    QAR_GPIO_OUT_SET(base) = mask;
}

static inline void qar_gpio_clear(uint32_t base, uint32_t mask)
{
    QAR_GPIO_OUT_CLR(base) = mask;
}

static inline uint32_t qar_gpio_read(uint32_t base)
{
    return QAR_GPIO_IN(base);
}

static inline void qar_gpio_config_irq(uint32_t base,
                                       uint32_t enable_mask,
                                       uint32_t rise_mask,
                                       uint32_t fall_mask)
{
    QAR_GPIO_IRQ_EN(base) = enable_mask;
    QAR_GPIO_IRQ_RISE(base) = rise_mask;
    QAR_GPIO_IRQ_FALL(base) = fall_mask;
}

static inline void qar_gpio_config_debounce(uint32_t base,
                                            uint32_t mask,
                                            uint16_t cycles)
{
    QAR_GPIO_DB_EN(base) = mask;
    QAR_GPIO_DB_CYCLES(base) = (uint32_t)cycles;
}

static inline void qar_gpio_clear_irq(uint32_t base, uint32_t mask)
{
    QAR_GPIO_IRQ_STATUS(base) = mask;
}

#endif /* QAR_HAL_GPIO_H */
