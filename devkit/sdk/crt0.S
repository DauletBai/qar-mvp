    .section .text.start
    .globl _start
_start:
    la  sp, __stack_top

    /* Copy .data from load address to RAM */
    la  t0, __data_start
    la  t1, __data_end
    la  t2, __data_load_start
1:
    bgeu t0, t1, 2f
    lw   t3, 0(t2)
    sw   t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j    1b
2:

    /* Zero BSS */
    la  t0, __bss_start
    la  t1, __bss_end
3:
    bgeu t0, t1, 4f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    3b
4:
    call main
    j    4b

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
