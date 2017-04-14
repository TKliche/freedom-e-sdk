// See LICENSE for license details.

#ifndef _SIFIVE_PLATFORM_H
#define _SIFIVE_PLATFORM_H

// Some things missing from the official encoding.h
#if __riscv_xlen == 32
#define MCAUSE_INT         _AC(0x80000000,UL)
#define MCAUSE_CAUSE       _AC(0x7FFFFFFF,UL)
#elif __riscv_xlen == 64
#define MCAUSE_INT         _AC(0x8000000000000000,ULL)
#define MCAUSE_CAUSE       _AC(0x7FFFFFFFFFFFFFFF,ULL)
#else
#error "Unknown XLEN"
#endif

#include "sifive/const.h"
#include "sifive/devices/clint.h"
#include "sifive/devices/plic.h"
#include "sifive/devices/uart.h"

/****************************************************************************
 * Platform definitions
 *****************************************************************************/

#define CLINT_BASE_ADDR _AC(0x02000000,UL)
#define PLIC_BASE_ADDR _AC(0x0C000000,UL)
#define UART0_BASE_ADDR _AC(0x10013000,UL)
#define UART1_BASE_ADDR _AC(0x10023000,UL)
#define MEM_BASE_ADDR _AC(0x80000000,UL)

// Interrupt Numbers
#define INT_RESERVED 0
#define INT_UART0_BASE 1
#define INT_UART1_BASE 2

// Helper functions
#define _REG64(p, i) (*(volatile uint64_t *)((p) + (i)))
#define _REG32(p, i) (*(volatile uint32_t *)((p) + (i)))
#define _REG16(p, i) (*(volatile uint16_t *)((p) + (i)))
// Bulk set bits in `reg` to either 0 or 1.
// E.g. SET_BITS(MY_REG, 0x00000007, 0) would generate MY_REG &= ~0x7
// E.g. SET_BITS(MY_REG, 0x00000007, 1) would generate MY_REG |= 0x7
#define SET_BITS(reg, mask, value) if ((value) == 0) { (reg) &= ~(mask); } else { (reg) |= (mask); }
#define CLINT_REG(offset) _REG32(CLINT_BASE_ADDR, offset)
#define PLIC_REG(offset) _REG32(PLIC_BASE_ADDR, offset)
#define UART0_REG(offset) _REG32(UART0_BASE_ADDR, offset)
#define UART1_REG(offset) _REG32(UART1_BASE_ADDR, offset)

#endif /* _SIFIVE_PLATFORM_H */
