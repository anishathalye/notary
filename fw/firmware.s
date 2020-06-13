.global _reset
.type _reset, %function
_reset:
/* clear registers and
 * some microarchitectural CPU state */
    li ra, 0
    la sp, _stack_top /* 0x20000800 */
    li gp, 0
    li tp, 0
    li t0, 0
    li t1, 0
    li t2, 0
    li s0, 0
    li s1, 0
    li a0, 0
    li a1, 0
    li a2, 0
    li a3, 0
    li a4, 0
    li a5, 0
    li a6, 0
    li a7, 0
    li s2, 0
    li s3, 0
    li s4, 0
    li s5, 0
    li s6, 0
    li s7, 0
    li s8, 0
    li s9, 0
    li s10, 0
    li s11, 0
    li t3, 0
    li t4, 0
    li t5, 0
    li t6, 0
/* clear state in
 * memory write machinery */
    sw zero, 0(zero)
/* clear gpio */
    la t0, _gpio /* 0x40000000 */
    sw zero, 0(t0)
/* clear sram */
    la t0, _ssram /* 0x20000000 */
    la t1, _esram /* 0x20020000 */
_loop:
    sw zero, 0x00(t0)
    sw zero, 0x04(t0)
    sw zero, 0x08(t0)
    sw zero, 0x0c(t0)
    sw zero, 0x10(t0)
    sw zero, 0x14(t0)
    sw zero, 0x18(t0)
    sw zero, 0x1c(t0)
    sw zero, 0x20(t0)
    sw zero, 0x24(t0)
    sw zero, 0x28(t0)
    sw zero, 0x2c(t0)
    sw zero, 0x30(t0)
    sw zero, 0x34(t0)
    sw zero, 0x38(t0)
    sw zero, 0x3c(t0)
    addi t0, t0, 0x40
    bne t0, t1, _loop
/* done with deterministic start,
 * proceed to load code over UART */
