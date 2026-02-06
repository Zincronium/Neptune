BITS 16
global _start
extern page
extern kentry

gdt_start:
    dq 0x0000000000000000      ; Null descriptor
    dq 0x00CF9A000000FFFF      ; Code segment (base=0, limit=4GB)
    dq 0x00CF92000000FFFF      ; Data segment (base=0, limit=4GB)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

_start:
    ; Load GDT
    lgdt [gdt_descriptor]

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump into 32-bit protected mode
    jmp 0x08:pm_label          ; CS = 0x08 code segment in GDT

BITS 32
pm_label:
    ; Reload data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; EBX contains the Multiboot info pointer
    mov esi, ebx               ; Save mbi in ESI for transition

    ; Enable PAE + call paging setup
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    call page                   ; sets up PML4, PDPT, PD, PT

    ; Enable long mode
    mov ecx, 0xC0000080         ; IA32_EFER
    rdmsr
    or eax, 1 << 8              ; LME
    wrmsr

    ; Load CR3 with PML4
    mov eax, pml4
    mov cr3, eax

    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31             ; CR0.PG
    mov cr0, eax

    ; Far jump to 64-bit kernel
    jmp 0x08:lm_entry           ; CS = 0x08 code selector

BITS 64
lm_entry:
    ; Reload data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Pass mbi to kentry in RDI
    mov rdi, rsi
    call kentry

    hlt
