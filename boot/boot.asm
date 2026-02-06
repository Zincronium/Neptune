bits 16
extern page
extern kentry
gdt_start:
dq 0x0000000000000000

; Code segment: base=0, limit=4GB, code, readable
; access=0x9A, flags=0xCF
dq 0x00CF9A000000FFFF

; Data segment: base=0, limit=4GB, data, writable
; access=0x92, flags=0xCF
dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start
_start:
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_label
bits 32
pm_label:
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    call page
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1
    wrmsr
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:lm_entry
bits 64
lm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    call kentry
    hlt