#include "hal_init.h"

__attribute__((weak)) void qar_sdk_init(void);

__attribute__((constructor)) static void qar_call_init(void)
{
    if (qar_sdk_init)
        qar_sdk_init();
}
