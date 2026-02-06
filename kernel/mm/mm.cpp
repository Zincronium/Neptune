#include <stdint.h>
extern "C" char kernel_end;

alignas(4096) static uint64_t pml4[512];
alignas(4096) static uint64_t pdpt[512 * 4]; // enough for multiple PDs
alignas(4096) static uint64_t pd[512 * 16];   // enough for multiple PTs
alignas(4096) static uint64_t pt[512 * 64];   // adjust if kernel bigger
static inline void set_cr3(uint64_t* pml4_phys) {
    __asm__ volatile (
        "mov %0, %%cr3"
        :
        : "r"(pml4_phys)
        : "memory"
    );
}

extern "C" void page() {
    constexpr uint64_t PAGE_SIZE = 0x1000;
    constexpr uint64_t HIGHER_HALF_BASE = 0xFFFF800000000000ULL;

    for (int i = 0; i < 512; i++) pml4[i] = 0;

    uint64_t phys = 0x100000; // start of kernel
    uint64_t page_count = 0;

    int pdpt_idx = 0;
    int pd_idx = 0;
    int pt_idx = 0;

    // setup first PML4 entries for identity and higher-half
    pml4[0] = (uint64_t)&pdpt[pdpt_idx * 512] | 0x3;       // identity
    pml4[256] = (uint64_t)&pdpt[pdpt_idx * 512] | 0x3;     // higher-half

    while (phys < (uint64_t)&kernel_end) {
        if (pt_idx == 512) {
            pt_idx = 0;
            pd_idx++;
            pd[pd_idx] = (uint64_t)&pt[page_count] | 0x3;
        }

        if (pd_idx == 512) {
            pd_idx = 0;
            pdpt_idx++;
            pdpt[pdpt_idx] = (uint64_t)&pd[pd_idx] | 0x3;
        }

        uint64_t entry_flags = 0x3; // Present + RW

        // identity mapping
        pt[pt_idx] = (phys & 0x000FFFFFFFFFF000ULL) | entry_flags;

        // higher-half mapping
        uint64_t vaddr = HIGHER_HALF_BASE + phys;
        pt[pt_idx] = (phys & 0x000FFFFFFFFFF000ULL) | entry_flags;

        phys += PAGE_SIZE;
        pt_idx++;
        page_count++;
    }
    set_cr3(reinterpret_cast<uint64_t*>(pml4));
}
