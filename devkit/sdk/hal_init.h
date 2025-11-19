#ifndef QAR_SDK_HAL_INIT_H
#define QAR_SDK_HAL_INIT_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * qar_sdk_init()
 *
 * Default hardware-abstraction bootstrap entry point that is invoked
 * automatically by the SDK runtime before main(). The implementation
 * (see devkit/sdk/hal_init.c) programs safe reset values for GPIO, UART,
 * timers, CAN, SPI, I2C, and ADC peripherals so that C firmware always
 * starts from a known state. Firmware may override this symbol by
 * providing its own qar_sdk_init definition.
 */
void qar_sdk_init(void);

#ifdef __cplusplus
}
#endif

#endif /* QAR_SDK_HAL_INIT_H */
