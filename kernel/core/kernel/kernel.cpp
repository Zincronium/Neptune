#include <stdint.h>
typedef uint32_t __multiboot_u32;
struct multiboot_tag {
    __multiboot_u32 type;
    __multiboot_u32 size;
};

struct multiboot_tag_framebuffer {
    __multiboot_u32 type;
    __multiboot_u32 size;
    uint64_t addr;
    __multiboot_u32 pitch;
    __multiboot_u32 width;
    __multiboot_u32 height;
    uint8_t bpp;
    uint8_t framebuffer_type;
    uint16_t reserved;
};

// Global variables to store info once found
uint32_t* fb_addr = nullptr;
uint32_t fb_width = 0;
uint32_t fb_height = 0;
uint32_t fb_pitch = 0;
void draw_pixel(int x, int y, uint32_t color) {
    if (x >= fb_width || y >= fb_height) return;

    // We use pitch/4 because the pitch is in bytes
    fb_addr[y * (fb_pitch / 4) + x] = color;
}

void clear_screen(uint32_t color) {
    for (uint32_t y = 0; y < fb_height; y++) {
        for (uint32_t x = 0; x < fb_width; x++) {
            draw_pixel(x, y, color);
        }
    }
}
extern "C" void kentry(uint64_t addr) {
    uint8_t* tag_ptr = (uint8_t*)(addr + 8);

    // TRAP 1: If we can't even read 'addr', we'll crash here.
    // If it DOESN'T crash here, our identity map for low memory is GOOD.
    volatile uint32_t magic_check = *(uint32_t*)addr;

    while (true) {
        multiboot_tag* tag = (multiboot_tag*)tag_ptr;
        if (tag->type == 0) break;

        if (tag->type == 8) {
            auto* fb = (multiboot_tag_framebuffer*)tag;

            // DANGER: Let's assume the address is physical.
            // If fb->addr is 0xFD000000, our page table should handle it.
            uint32_t* fb_ptr = (uint32_t*)fb->addr;

            // TRAP 2: Attempt a single write.
            // If it crashes, the mapping for high physical memory (PCI hole) is BAD.
            *fb_ptr = 0x00FF00;

            // If we reach here, we won!
            fb_addr = fb_ptr;
            fb_width = fb->width;
            fb_height = fb->height;
            fb_pitch = fb->pitch;
            clear_screen(0xFF0F0F);
            break;
        }
        tag_ptr += ((tag->size + 7) & ~7);
    }
}