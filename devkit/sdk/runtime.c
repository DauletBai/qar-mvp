#include "hal_init.h"

__attribute__((weak)) void qar_sdk_init(void) { }

__attribute__((constructor)) static void qar_call_init(void) { qar_sdk_init(); }
