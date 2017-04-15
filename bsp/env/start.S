// See LICENSE for license details.

	.section .init
	.globl _start
	.type _start,@function

_start:
	la gp, _gp
	la sp, _sp

	csrr t0, mhartid
1:bnez t0, 1b

	/* Clear bss section */
	la a0, __bss_start
	la a1, _end
	bgeu a0, a1, 2f
1:
	sw zero, (a0)
	addi a0, a0, 4
	bltu a0, a1, 1b
2:

	/* Call global constructors */
	la a0, __libc_fini_array
	call atexit
	call __libc_init_array

#ifndef __riscv_float_abi_soft
	/* Enable FPU */
	li t0, MSTATUS_FS
	csrs mstatus, t0
	csrr t1, mstatus
	and t1, t1, t0
	beqz t1, 1f
	fssr x0
1:
#endif


	/* argc = argv = 0 */
	li a0, 0
	li a1, 0
	call main
	tail exit
