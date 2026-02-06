BITS 32
extern page
extern kentry
_start:
    ; Reload custom GDT
    lgdt [gdt_descriptor]

    ; Reload data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Save MBI
    mov esi, ebx

    ; Enable PAE + call paging setup
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax
    call page

    ; Enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Load CR3 with PML4
    mov eax, pml4
    mov cr3, eax

    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ; Far jump to 64-bit kernel
    jmp 0x08:lm_entry

BITS 64
lm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov rdi, rsi
    call kentry
    hlt
