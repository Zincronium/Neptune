bits 32

section .multiboot
align 8
    MAGIC    equ 0xe85250d6
    ARCH     equ 0
    LENGTH   equ multiboot_header_end - multiboot_header_start
    CHECKSUM equ -(MAGIC + ARCH + LENGTH)

multiboot_header_start:
    dd MAGIC
    dd ARCH
    dd LENGTH
    dd CHECKSUM
    align 8
    dw 5, 0
    dd 20, 1024, 768, 32
    align 8
    dw 0, 0
    dd 8
multiboot_header_end:

; Define the offset here so NASM can do the math without relocation warnings
OFFSET equ 0xFFFF800000000000

SECTION .text
extern page
extern kentry
global _start

_start:
    cli
    mov edi, ebx            ; Save multiboot pointer

    ; Setup temporary physical stack
    ; We subtract the offset to get the 1MB-range physical address
    mov esp, stack_top_phys

    ; 1. Enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; 2. Setup Paging (CR3 is loaded inside page())
    call page

    ; 3. Enable Long Mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; 4. Enable Paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; 5. Load GDT (Physical address)
    lgdt [gdt_descriptor_phys]

    jmp 0x08:lm_entry

bits 64
lm_entry:
    ; 6. The Absolute Jump to Higher Half
    mov rax, .upper_half
    jmp rax

.upper_half:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    ; 7. Setup proper Higher Half Stack
    mov rsp, stack_top

    ; 8. Pass Multiboot pointer (physical) to kentry
    ; EDI was saved at the very beginning of _start
    mov rdi, rdi            ; EDI is the low 32 bits of RDI

    call kentry

.hlt:
    hlt
    jmp .hlt

SECTION .data
align 16
gdt_start:
    dq 0x0000000000000000
    dq 0x00209A0000000000
    dq 0x0000920000000000
gdt_end:

gdt_descriptor_phys:
    dw gdt_end - gdt_start - 1
    ; Use 'dq' and calculate address to avoid relocation truncation warnings
    dq (gdt_start - OFFSET)

SECTION .bss
align 16
stack_bottom:
    resb 16384
stack_top:

; Constant for the physical stack address
stack_top_phys equ (stack_top - OFFSET)