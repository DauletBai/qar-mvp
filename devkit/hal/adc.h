#ifndef QAR_HAL_ADC_H
#define QAR_HAL_ADC_H

#include <stdint.h>
#include "mmio.h"

#define QAR_ADC0_BASE 0x40006000u

#define QAR_ADC_REG(base, offset) QAR_MMIO32((base), (offset))

#define QAR_ADC_CTRL(base)        QAR_ADC_REG((base), 0x00)
#define QAR_ADC_STATUS(base)      QAR_ADC_REG((base), 0x04)
#define QAR_ADC_RESULT(base)      QAR_ADC_REG((base), 0x08)
#define QAR_ADC_IRQ_EN(base)      QAR_ADC_REG((base), 0x0C)
#define QAR_ADC_IRQ_STATUS(base)  QAR_ADC_REG((base), 0x10)
#define QAR_ADC_SEQ_MASK(base)    QAR_ADC_REG((base), 0x14)
#define QAR_ADC_SAMPLE_DIV(base)  QAR_ADC_REG((base), 0x18)

#define QAR_ADC_CTRL_ENABLE       (1u << 0)
#define QAR_ADC_CTRL_CONTINUOUS   (1u << 1)
#define QAR_ADC_CTRL_START        (1u << 2)
#define QAR_ADC_CTRL_CHANNEL_SHIFT 4

#define QAR_ADC_STATUS_BUSY       (1u << 0)
#define QAR_ADC_STATUS_READY      (1u << 1)
#define QAR_ADC_STATUS_OVERRUN    (1u << 2)
#define QAR_ADC_STATUS_CONT_MASK  (1u << 3)

#define QAR_ADC_IRQ_DATA_READY    (1u << 0)
#define QAR_ADC_IRQ_OVERRUN       (1u << 1)

#define QAR_ADC_RESULT_VALUE(val)   ((val) & 0xFFFu)
#define QAR_ADC_RESULT_CHANNEL(val) (((val) >> 16) & 0xF)

static inline void qar_adc_set_sequence(uint32_t base, uint32_t mask, uint16_t sample_div)
{
    QAR_ADC_SEQ_MASK(base) = mask & 0xF;
    QAR_ADC_SAMPLE_DIV(base) = sample_div;
}

static inline void qar_adc_enable_continuous(uint32_t base, uint32_t mask, uint16_t sample_div)
{
    qar_adc_set_sequence(base, mask, sample_div);
    QAR_ADC_CTRL(base) = QAR_ADC_CTRL_ENABLE | QAR_ADC_CTRL_CONTINUOUS;
}

static inline void qar_adc_disable_continuous(uint32_t base)
{
    QAR_ADC_CTRL(base) = QAR_ADC_CTRL_ENABLE;
}

static inline void qar_adc_start_single(uint32_t base, uint32_t channel)
{
    uint32_t ctrl = QAR_ADC_CTRL_ENABLE |
        ((channel & 0x3u) << QAR_ADC_CTRL_CHANNEL_SHIFT) |
        QAR_ADC_CTRL_START;
    QAR_ADC_CTRL(base) = ctrl;
}

static inline uint32_t qar_adc_status(uint32_t base)
{
    return QAR_ADC_STATUS(base);
}

static inline uint32_t qar_adc_read(uint32_t base)
{
    return QAR_ADC_RESULT(base);
}

static inline void qar_adc_enable_irq(uint32_t base, uint32_t mask)
{
    QAR_ADC_IRQ_EN(base) |= mask;
}

static inline void qar_adc_clear_irq(uint32_t base, uint32_t mask)
{
    QAR_ADC_IRQ_STATUS(base) = mask;
}

#endif /* QAR_HAL_ADC_H */
