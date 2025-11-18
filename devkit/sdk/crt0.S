    .section .text.start
    .globl _start
_start:
    la  sp, __stack_top
    call main
    j   .

    .section .bss
    .globl __stack_top
__stack_top:
