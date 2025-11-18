#ifndef QAR_HAL_MMIO_H
#define QAR_HAL_MMIO_H

#include <stdint.h>

#define QAR_MMIO32(base, offset) (*((volatile uint32_t *)(uintptr_t)((uintptr_t)(base) + (offset))))

#endif /* QAR_HAL_MMIO_H */
