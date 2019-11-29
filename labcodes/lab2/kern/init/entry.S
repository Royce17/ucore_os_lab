#include <mmu.h>
#include <memlayout.h>

#define REALLOC(x) (x - KERNBASE)

#.sect - Allows you to specify your own kind of section.
#.bss - Reserve space for all your global variables here. These are variables you want to be able to change.
#.data - Reserve space for all your global data here. This means stuff you can't change, like string constants, error messages, etc.
#.text - This is the section where all your executable code goes.
#.text 表示代码开始
.text

#It simply defines the kern_entry function to be global, ie. accessible from anywhere, including other files.
#表示 kern_entry 可以在其他地方调用
#汇编器在立即操作数前加一个美元符号（$）
.globl kern_entry
kern_entry:
    # load pa of boot pgdir
    movl $REALLOC(__boot_pgdir), %eax
    movl %eax, %cr3

    # enable paging
    movl %cr0, %eax
    orl $(CR0_PE | CR0_PG | CR0_AM | CR0_WP | CR0_NE | CR0_TS | CR0_EM | CR0_MP), %eax
    andl $~(CR0_TS | CR0_EM), %eax
    movl %eax, %cr0

    # update eip
    # now, eip = 0x1.....
    leal next, %eax
    # set eip = KERNBASE + 0x1.....
    jmp *%eax
next:

    # unmap va 0 ~ 4M, it's temporary mapping
    xorl %eax, %eax
    movl %eax, __boot_pgdir

    # set ebp, esp
    movl $0x0, %ebp
    # the kernel stack region is from bootstack -- bootstacktop,
    # the kernel stack size is KSTACKSIZE (8KB)defined in memlayout.h
    movl $bootstacktop, %esp
    # now kernel stack is ready , call the first C function
    call kern_init

# should never get here
spin:
    jmp spin

#.data - Reserve space for all your global data here. This means stuff you can't change, like string constants, error messages, etc.
#.data - 存储全局变量
.data
#.align integer
#The .align directive causes the next data generated to be aligned modulo integer bytes. Integer must be a positive integer expression and must be a power of 2.
#.align 导致下一个数据生成为模 integer 字节
.align PGSIZE
    .globl bootstack
bootstack:
#.space size , fill
#This directive emits size bytes, each of value fill.If the comma and fill are omitted, fill is assumed to be zero.
    .space KSTACKSIZE
    .globl bootstacktop
bootstacktop:

# kernel builtin pgdir
# an initial page directory (Page Directory Table, PDT)
# These page directory table and page table can be reused!
.section .data.pgdir
.align PGSIZE
__boot_pgdir:
.globl __boot_pgdir
    # map va 0 ~ 4M to pa 0 ~ 4M (temporary)
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space (KERNBASE >> PGSHIFT >> 10 << 2) - (. - __boot_pgdir) # pad to PDE of KERNBASE
    # map va KERNBASE + (0 ~ 4M) to pa 0 ~ 4M
    .long REALLOC(__boot_pt1) + (PTE_P | PTE_U | PTE_W)
    .space PGSIZE - (. - __boot_pgdir) # pad to PGSIZE

.set i, 0
__boot_pt1:
.rept 1024
    .long i * PGSIZE + (PTE_P | PTE_W)
    .set i, i + 1
.endr

