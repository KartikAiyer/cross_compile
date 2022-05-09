set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(triple aarch64-linux-gnu)

set(CMAKE_C_COMPILER ${PROJECT_SOURCE_DIR}/toolchain/cross-pi-gcc-10.2.0-64/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER ${PROJECT_SOURCE_DIR}/toolchain/cross-pi-gcc-10.2.0-64/bin/aarch64-linux-gnu-g++)
set(CMAKE_C_COMPILER_TARGET ${triple})
set(CMAKE_CXX_COMPILER_TARGET ${triple})
set(CMAKE_CROSSCOMPILING TRUE)