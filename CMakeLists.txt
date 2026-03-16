cmake_minimum_required(VERSION 3.20.0)
project(shmatomic VERSION 1.0.0 LANGUAGES CXX)

# 1. CROSS-COMPILER CONFIG (Ensure these paths match your host environment)
set(CMAKE_C_COMPILER /usr/bin/aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER /usr/bin/aarch64-linux-gnu-g++)

# 2. C++20 IS REQUIRED for std::atomic<std::shared_ptr>
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(shmatomic shmatomic.cpp)

# 3. LINKING & LIBRARIES
# Added 'atomic' which is crucial for aarch64 128-bit CAS operations
target_link_libraries(shmatomic PRIVATE pthread rt atomic)

# 4. STATIC LINKING & OPTIMIZATION
target_link_options(shmatomic PRIVATE
    -static
    -static-libstdc++ 
    -static-libgcc
)

# Enable high optimization for Release builds to test real-world thread contention
target_compile_options(shmatomic PRIVATE 
    -Wall -Wextra 
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Debug>:-O0 -g>
    "-fdebug-prefix-map=${CMAKE_SOURCE_DIR}=."
)

# 5. DEFINITIONS
target_compile_definitions(shmatomic PRIVATE $<$<CONFIG:Debug>:DEBUG>)