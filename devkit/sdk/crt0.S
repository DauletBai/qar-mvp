    .section .text.start
    .globl _start
_start:
    la  sp, __stack_top

    /* Zero BSS */
    la  t0, __bss_start
    la  t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    call main
    j    2b

    .section .text.trap
    .globl _trap_vector
_trap_vector:
    mret

    .section .bss
    .globl __bss_start
__bss_start:
    .globl __bss_end
__bss_end:
    .globl __stack_top
__stack_top:
