# Specify the cross compiler
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_C_COMPILER   /home/linuxbrew/.linuxbrew/bin/x86_64-elf-gcc)
set(CMAKE_CXX_COMPILER /home/linuxbrew/.linuxbrew/bin/x86_64-elf-g++)
set(CMAKE_ASM_NASM_COMPILER /usr/bin/nasm)  # or your nasm path

# Tell CMake not to look for standard libraries
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Disable trying to run test programs
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
