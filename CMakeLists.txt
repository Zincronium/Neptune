cmake_minimum_required(VERSION 3.25)

# Prevent CMake from testing compiler
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(NeptuneKernel LANGUAGES C CXX ASM_NASM)

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

# FIX 1: Add -m32 to flags.
# Even though we jump to 64-bit later, the ELF binary and C++
# entry code must be compiled as 32-bit for the linker to produce elf_i386.
add_compile_options(
        -m32
        -ffreestanding
        -fno-exceptions
        -fno-rtti
        -fno-stack-protector
        -mno-red-zone
        -Wall -Wextra -Wpedantic
)

# Enable NASM
enable_language(ASM_NASM)

# -----------------------------------------------------------------------------
# Gather sources
# -----------------------------------------------------------------------------
file(GLOB_RECURSE KERNEL_SOURCES "kernel/*.cpp" "lib/*.cpp")
file(GLOB_RECURSE ASM_SOURCES "boot/*.asm")

set(ASM32_SOURCES "")
set(ASM64_SOURCES "")
foreach(f ${ASM_SOURCES})
    file(READ ${f} firstline LIMIT 20) # Increased limit to ensure match
    if(firstline MATCHES "bits 32")
        list(APPEND ASM32_SOURCES ${f})
    else()
        list(APPEND ASM64_SOURCES ${f})
    endif()
endforeach()

# -----------------------------------------------------------------------------
# Compile NASM sources (FIX 2: Ensure output is elf32 for ALL)
# -----------------------------------------------------------------------------
set(ASM_OBJECTS "")
foreach(f ${ASM32_SOURCES} ${ASM64_SOURCES})
    get_filename_component(fname ${f} NAME_WE)
    set(obj ${CMAKE_BINARY_DIR}/${fname}.o)
    add_custom_command(
            OUTPUT ${obj}
            COMMAND nasm -f elf32 ${f} -o ${obj}
            DEPENDS ${f}
    )
    list(APPEND ASM_OBJECTS ${obj})
endforeach()

# -----------------------------------------------------------------------------
# Output executable
# -----------------------------------------------------------------------------
set(KERNEL_OUTPUT neptune.elf)
add_executable(${KERNEL_OUTPUT} ${KERNEL_SOURCES} ${ASM_OBJECTS})

target_include_directories(${KERNEL_OUTPUT} PRIVATE
        ${CMAKE_SOURCE_DIR}/kernel
        ${CMAKE_SOURCE_DIR}/lib
)

# -----------------------------------------------------------------------------
# Linker script (FIX 3: Explicitly KEEP the multiboot section)
# -----------------------------------------------------------------------------
set(LINKER_SCRIPT "
ENTRY(_start)
SECTIONS
{
    /* The kernel will be loaded at 1MB physically */
    . = 0x100000;
    _kernel_phys_start = .;

    /* But it will run at this virtual address */
    . += 0xFFFF800000000000;
    _kernel_virt_start = .;

    .multiboot : AT(_kernel_phys_start) {
        KEEP(*(.multiboot))
    }

    .text : AT(ADDR(.text) - 0xFFFF800000000000) { *(.text*) }
    .data : AT(ADDR(.data) - 0xFFFF800000000000) { *(.data*) }
    .bss  : AT(ADDR(.bss)  - 0xFFFF800000000000) { *(.bss*) *(COMMON) }

    kernel_end = .;
}
")
file(WRITE ${CMAKE_BINARY_DIR}/linker.ld "${LINKER_SCRIPT}")

# -----------------------------------------------------------------------------
# Linker flags (FIX 4: Added -m32 for the GCC frontend)
# -----------------------------------------------------------------------------
target_link_options(${KERNEL_OUTPUT} PRIVATE
        -m32
        -nostdlib
        -T ${CMAKE_BINARY_DIR}/linker.ld
        -z max-page-size=0x1000
        -Wl,-melf_i386
        -static
)

# -----------------------------------------------------------------------------
# ISO Generation
# -----------------------------------------------------------------------------
set(ISO_DIR "${CMAKE_BINARY_DIR}/isodir")
set(ISO_PATH "${CMAKE_BINARY_DIR}/neptune.iso")

# --- ISO Creation ---
set(ISO_DIR "${CMAKE_BINARY_DIR}/isodir")
set(ISO_PATH "${CMAKE_BINARY_DIR}/neptune.iso")

add_custom_target(iso
        COMMAND ${CMAKE_COMMAND} -E make_directory ${ISO_DIR}/boot/grub
        COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_BINARY_DIR}/${KERNEL_OUTPUT} ${ISO_DIR}/boot/
        COMMAND echo "set timeout=0" > ${ISO_DIR}/boot/grub/grub.cfg
        COMMAND echo "set default=0" >> ${ISO_DIR}/boot/grub/grub.cfg
        # Add these two lines:
        COMMAND echo "insmod all_video" >> ${ISO_DIR}/boot/grub/grub.cfg
        COMMAND echo "set gfxpayload=keep" >> ${ISO_DIR}/boot/grub/grub.cfg

        COMMAND echo "menuentry 'NeptuneOS' {" >> ${ISO_DIR}/boot/grub/grub.cfg
        COMMAND echo "  multiboot2 /boot/${KERNEL_OUTPUT}" >> ${ISO_DIR}/boot/grub/grub.cfg
        COMMAND echo "  boot" >> ${ISO_DIR}/boot/grub/grub.cfg
        COMMAND echo "}" >> ${ISO_DIR}/boot/grub/grub.cfg
        COMMAND grub-mkrescue -o ${ISO_PATH} ${ISO_DIR}
        DEPENDS ${KERNEL_OUTPUT}
        COMMENT "Building bootable UEFI ISO with GRUB"
)

# --- QEMU Execution ---
# Note: Removed the backslashes to prevent the parse error
add_custom_target(run
        COMMAND qemu-system-x86_64
        -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd
        -drive if=pflash,format=raw,file=/usr/share/OVMF/OVMF_VARS_4M.fd
        -cdrom ${ISO_PATH}
        -m 512M
        -vga std
        -monitor stdio
        -no-reboot
        -no-shutdown
        -d int -no-reboot -D qemu.log
        DEPENDS iso
        COMMENT "Running NeptuneOS in UEFI mode"
)