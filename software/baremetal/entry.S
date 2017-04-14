#include "platform.h"
#include <sifive/smp.h>

.section .init
.global _start
_start:
	la t0, trapvec
	csrw mtvec, t0

	smp_pause(s1, s2)

	la t0, _fbss
	la t1, _ebss
	bgeu t0, t1, 2f
1:
	sd zero, 0(t0)
	addi t0, t0, 8
	bltu t0, t1, 1b
2:
	fence

	smp_resume(s1, s2)

	la sp, _stack
	csrr t0, mhartid
	slli t0, t0, 8
	sub sp, sp, t0

	call main
	tail exit

.global exit
	nop
	nop
	nop
exit:
	nop
	nop
	nop
	j exit

.global trapvec
	nop
	nop
	nop
trapvec:
	nop
	nop
	nop
	j trapvec
