cmake_minimum_required(VERSION 3.10...3.29)
project(directory_monitor VERSION 1.0.0 LANGUAGES C)

# Set C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Allow user to specify target platform and architecture
set(TARGET_PLATFORM "NATIVE" CACHE STRING "Target platform: NATIVE, WINDOWS, LINUX")
set(TARGET_ARCH "x86_64" CACHE STRING "Target architecture: arm64, x86_64, x86/i686")
set(DART_SDK_PATH "" CACHE PATH "Path to Dart SDK")

# Validate target platform and architecture
set(VALID_PLATFORMS "NATIVE;WINDOWS;LINUX")
set(VALID_ARCHS "arm64;x86_64;x86;i686;")

if(NOT TARGET_PLATFORM IN_LIST VALID_PLATFORMS)
    message(FATAL_ERROR "Invalid TARGET_PLATFORM: ${TARGET_PLATFORM}. Use one of: ${VALID_PLATFORMS}")
endif()

if(NOT TARGET_ARCH IN_LIST VALID_ARCHS)
    message(FATAL_ERROR "Invalid TARGET_ARCH: ${TARGET_ARCH}. Use one of: ${VALID_ARCHS}")
endif()

# Validate Dart SDK path for Windows and Linux
if((WIN32 OR TARGET_PLATFORM STREQUAL "WINDOWS" OR(UNIX AND NOT APPLE)) AND NOT DART_SDK_PATH)
    message(FATAL_ERROR "DART_SDK_PATH must be set for Windows or Linux")
endif()

# Platform and architecture settings
if(TARGET_PLATFORM STREQUAL "NATIVE")
    if(APPLE)
        # macOS native compilation
        if(TARGET_ARCH STREQUAL "x86" OR TARGET_ARCH STREQUAL "i686")
            message(FATAL_ERROR "macOS does not support x86 architecture")
        endif()

        set(CMAKE_OSX_ARCHITECTURES "${TARGET_ARCH}")
    elseif(WIN32)
        # Windows native compilation
        if(TARGET_ARCH STREQUAL "arm64")
            set(CMAKE_GENERATOR_PLATFORM ARM64)
        elseif(TARGET_ARCH STREQUAL "x86_64")
            set(CMAKE_GENERATOR_PLATFORM x64)
        elseif(TARGET_ARCH STREQUAL "x86" OR TARGET_ARCH STREQUAL "i686")
            set(CMAKE_GENERATOR_PLATFORM Win32)
        endif()
    elseif(UNIX AND NOT APPLE)
        # Linux native compilation
        if(TARGET_ARCH STREQUAL "x86" OR TARGET_ARCH STREQUAL "i686")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
        elseif(TARGET_ARCH STREQUAL "x86_64")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m64")
        elseif(TARGET_ARCH STREQUAL "arm64")
            set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a")
        endif()
    else()
        message(FATAL_ERROR "NATIVE platform only supported on macOS, Windows, or Linux")
    endif()
elseif(TARGET_PLATFORM STREQUAL "WINDOWS")
    # Windows cross-compilation
    set(CMAKE_SYSTEM_NAME Windows)

    if(TARGET_ARCH STREQUAL "arm64")
        set(CMAKE_C_COMPILER "aarch64-w64-mingw32-gcc")
    elseif(TARGET_ARCH STREQUAL "x86_64")
        set(CMAKE_C_COMPILER "x86_64-w64-mingw32-gcc")
    elseif(TARGET_ARCH STREQUAL "x86" OR TARGET_ARCH STREQUAL "i686")
        set(CMAKE_C_COMPILER "i686-w64-mingw32-gcc")
    endif()
elseif(TARGET_PLATFORM STREQUAL "LINUX")
    # Linux cross-compilation
    set(CMAKE_SYSTEM_NAME Linux)

    if(TARGET_ARCH STREQUAL "arm64")
        set(CMAKE_C_COMPILER "aarch64-linux-gnu-gcc")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -march=armv8-a")
    elseif(TARGET_ARCH STREQUAL "x86_64")
        set(CMAKE_C_COMPILER "x86_64-linux-gnu-gcc")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m64")
    elseif(TARGET_ARCH STREQUAL "x86" OR TARGET_ARCH STREQUAL "i686")
        set(CMAKE_C_COMPILER "i686-linux-gnu-gcc")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
    endif()
endif()

# Add shared library
add_library(directory_monitor SHARED src/directory_monitor.c)

# Include header directories
target_include_directories(directory_monitor PRIVATE src)

if(DART_SDK_PATH)
    target_include_directories(directory_monitor PRIVATE ${DART_SDK_PATH}/include)
else()
    message(WARNING "DART_SDK_PATH not set and could not be auto-detected, compilation may fail")
endif()

# Platform-specific link settings
if(APPLE)
    # macOS: CoreServices and pthread
    target_link_libraries(directory_monitor PRIVATE
        "-framework CoreServices"
        "-lpthread"
        "-undefined dynamic_lookup"
    )
elseif(WIN32 OR TARGET_PLATFORM STREQUAL "WINDOWS")
    # Windows: Windows API and Dart library
    target_include_directories(directory_monitor PRIVATE ${CMAKE_SOURCE_DIR}/include)

    if(DART_SDK_PATH)
        find_library(DART_LIBRARY dart HINTS ${DART_SDK_PATH}/bin)

        if(DART_LIBRARY)
            target_link_libraries(directory_monitor PRIVATE ${DART_LIBRARY})
        else()
            message(WARNING "Dart library not found, linking may fail")
        endif()
    endif()

    target_link_libraries(directory_monitor PRIVATE
        "-lkernel32"
        "-luser32"
        "-ladvapi32"
    )
    target_compile_definitions(directory_monitor PRIVATE BUILD_DLL)
elseif(UNIX AND NOT APPLE)
    # Linux: pthread and rt
    target_link_libraries(directory_monitor PRIVATE
        "-lpthread"
        "-lrt"
    )
endif()

# Set output path and name
set_target_properties(directory_monitor PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/libs"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/libs"
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
)

# Platform and architecture-specific file naming
if(WIN32 OR TARGET_PLATFORM STREQUAL "WINDOWS")
    set_target_properties(directory_monitor PROPERTIES
        OUTPUT_NAME "DW_${TARGET_ARCH}"
        SUFFIX ".dll"
    )
elseif(UNIX AND NOT APPLE)
    set_target_properties(directory_monitor PROPERTIES
        OUTPUT_NAME "DW_${TARGET_ARCH}"
        SUFFIX ".so"
    )
elseif(APPLE)
    set_target_properties(directory_monitor PROPERTIES
        OUTPUT_NAME "DW_${TARGET_ARCH}"
        SUFFIX ".dylib"
    )
endif()

# Print build information
message(STATUS "Building directory_monitor for platform: ${TARGET_PLATFORM}, architecture: ${TARGET_ARCH}")
message(STATUS "Output directory: ${CMAKE_BINARY_DIR}/libs")
message(STATUS "Dart SDK path: ${DART_SDK_PATH}")