#include <stdint.h>

// IMPORTANT: This must match your Linker Script's VMA offset!
#define KERNEL_VIRT_OFFSET 0xFFFF800000000000ULL

// Use a macro to ensure math is done correctly at compile time
#define V2P(addr) ((uint64_t)(addr) - KERNEL_VIRT_OFFSET)

// Use 'alignas' to ensure these are on 4KB boundaries
// Use 'static' so they stay in the data segment, not the stack!
alignas(4096) static uint64_t pml4[512];
alignas(4096) static uint64_t pdpt[512];
alignas(4096) static uint64_t pd[2048]; // 4 Page Directories for 4GB
extern "C" void page() {
    // 1. Clear structures (Standard 512 entries per table)
    for (int i = 0; i < 512; i++) {
        pml4[i] = 0;
        pdpt[i] = 0;
    }
    for (int i = 0; i < 2048; i++) {
        pd[i] = 0;
    }

    uint64_t pdpt_p = V2P(pdpt);

    // 2. PML4 Setup
    // Index 0: Identity map (lower half)
    pml4[0] = pdpt_p | 0x03;

    // Index 256: For 0xFFFF800000000000 (Higher Half)
    pml4[256] = pdpt_p | 0x03;

    // Index 511: For 0xFFFFFFFF80000000 (Common "-2GB" Higher Half)
    // Adding this ensures that even if your linker script target shifted, it's mapped.
    pml4[511] = pdpt_p | 0x03;

    // 3. PDPT -> PDs (Mapping the first 4GB)
    // Each PDPT entry covers 1GB via a Page Directory
    for (int i = 0; i < 4; i++) {
        uint64_t pd_p = V2P(&pd[i * 512]);
        pdpt[i] = pd_p | 0x03;
    }

    // 4. PD -> 2MB Huge Pages
    // This populates all 4 Page Directories to cover 4GB of physical RAM
    for (int i = 0; i < 2048; i++) {
        // 0x83 = Present | Read-Write | Huge Page (PS bit)
        pd[i] = (uint64_t(i) * 0x200000) | 0x83;
    }

    // 5. Load CR3
    uint64_t pml4_p = V2P(pml4);
    asm volatile("mov %0, %%cr3" : : "r"(pml4_p) : "memory");
}