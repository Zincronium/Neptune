cmake_minimum_required(VERSION 3.25)
project(NeptuneKernel LANGUAGES C CXX ASM_NASM)

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

# Compiler flags for freestanding kernel
add_compile_options(
        -ffreestanding
        -fno-exceptions
        -fno-rtti
        -fno-stack-protector
        -mno-red-zone
        -Wall -Wextra -Wpedantic
)

# NASM flags
enable_language(ASM_NASM)

# -----------------------------------------------------------------------------
# Gather all sources recursively
# -----------------------------------------------------------------------------
file(GLOB_RECURSE KERNEL_SOURCES "kernel/*.cpp" "lib/*.cpp")
file(GLOB_RECURSE ASM_SOURCES "boot/*.asm")

# -----------------------------------------------------------------------------
# Output executable
# -----------------------------------------------------------------------------
set(KERNEL_OUTPUT neptune.elf)

add_executable(${KERNEL_OUTPUT} ${KERNEL_SOURCES} ${ASM_SOURCES})

# -----------------------------------------------------------------------------
# Include directories
# -----------------------------------------------------------------------------
include_directories(
        ${CMAKE_SOURCE_DIR}/kernel
        ${CMAKE_SOURCE_DIR}/lib
)

# -----------------------------------------------------------------------------
# Assembly properties
# -----------------------------------------------------------------------------
set_source_files_properties(${ASM_SOURCES} PROPERTIES
        COMPILE_FLAGS "-f elf64"
)

# -----------------------------------------------------------------------------
# Inline linker script
# -----------------------------------------------------------------------------
set(LINKER_SCRIPT "
ENTRY(_start)
SECTIONS
{
    . = 0x100000;
    .text : { *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
")

# Write inline linker script to CMake binary dir
file(WRITE ${CMAKE_BINARY_DIR}/linker.ld "${LINKER_SCRIPT}")

# -----------------------------------------------------------------------------
# Linker flags
# -----------------------------------------------------------------------------
target_link_options(${KERNEL_OUTPUT} PRIVATE
        -nostdlib
        -T ${CMAKE_BINARY_DIR}/linker.ld
        -z max-page-size=0x1000
        -Wl,-melf_x86_64
)

# -----------------------------------------------------------------------------
# QEMU run target
# -----------------------------------------------------------------------------
add_custom_target(run
        COMMAND qemu-system-x86_64 -kernel ${CMAKE_BINARY_DIR}/${KERNEL_OUTPUT} -m 512M -serial stdio -no-reboot
        DEPENDS ${KERNEL_OUTPUT}
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Running NeptuneKernel in QEMU"
)
