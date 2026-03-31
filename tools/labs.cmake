function(add_perf_ninja_lab_targets)
  set(options
    DISABLE_FAST_MATH
    DISABLE_O3
  )
  set(oneValueArgs
    CXX_EXTRA_FLAGS
  )
  set(multiValueArgs
    ARGS
    VALIDATE_ARGS
    LAB_ARGS
    EXTRA_TARGETS
    EXT_LAB_srcs
    EXT_VALIDATE_srcs
    EXTRA_INCLUDE_DIRECTORIES
  )
  cmake_parse_arguments(PNL "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(PNL_LAB_ARGS ${PNL_ARGS} ${PNL_LAB_ARGS})
  set(PNL_VALIDATE_ARGS ${PNL_ARGS} ${PNL_VALIDATE_ARGS})

  # Unique target prefix from relative source path (without leading "labs/")
  file(RELATIVE_PATH PERF_NINJA_REL_PATH "${CMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")
  string(REPLACE "\\" "/" PERF_NINJA_REL_PATH "${PERF_NINJA_REL_PATH}")

  # Remove leading "labs/" if present
  string(REGEX REPLACE "^labs/" "" PERF_NINJA_REL_PATH "${PERF_NINJA_REL_PATH}")

  # Convert to target prefix
  string(REPLACE "/" "." PERF_NINJA_TARGET_PREFIX "${PERF_NINJA_REL_PATH}")
  string(REGEX REPLACE "[^A-Za-z0-9_.+-]" "_" PERF_NINJA_TARGET_PREFIX "${PERF_NINJA_TARGET_PREFIX}")

  set(LAB_TARGET            "${PERF_NINJA_TARGET_PREFIX}.lab")
  set(VALIDATE_TARGET       "${PERF_NINJA_TARGET_PREFIX}.validate")
  set(VALIDATE_RUN_TARGET   "${PERF_NINJA_TARGET_PREFIX}.validateLab")
  set(BENCHMARK_RUN_TARGET  "${PERF_NINJA_TARGET_PREFIX}.benchmarkLab")

  # Set compiler options
  if(NOT MSVC)
    # set(CMAKE_C_FLAGS "-O3 -march=native ${CMAKE_C_FLAGS}") # Let config guess the best flags for the current machine
  else()
    include("${CMAKE_CURRENT_LIST_DIR}/msvc_simd_isa.cmake")
    if(SUPPORT_MSVC_AVX512)
      set(MSVC_SIMD_FLAGS "/arch:AVX512")
    elseif(SUPPORT_MSVC_AVX2)
      set(MSVC_SIMD_FLAGS "/arch:AVX2")
    elseif(SUPPORT_MSVC_AVX)
      set(MSVC_SIMD_FLAGS "/arch:AVX")
    else()
      set(MSVC_SIMD_FLAGS "")
    endif()
    set(CMAKE_C_FLAGS "/O2 ${MSVC_SIMD_FLAGS} ${CMAKE_C_FLAGS}")
  endif()



  # Set Windows stack size as on Linux: 2MB on 32-bit, 8MB on 64-bit
  if(WIN32)
    math(EXPR stack_size "${CMAKE_SIZEOF_VOID_P}*${CMAKE_SIZEOF_VOID_P}*128*1024")
    if(MSVC)
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /STACK:${stack_size}")
    else()
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Xlinker /stack:${stack_size}")
    endif()
  endif()

  # https://github.com/google/benchmark
  find_package(benchmark PATHS "${CMAKE_CURRENT_LIST_DIR}/benchmark/build" REQUIRED)
  set(BENCHMARK_LIBRARY "benchmark::benchmark")

  # Find source files
  file(GLOB srcs *.c *.h *.cpp *.hpp *.cxx *.hxx *.inl)
  list(FILTER srcs EXCLUDE REGEX ".*bench.cpp$")
  list(FILTER srcs EXCLUDE REGEX ".*validate.cpp$")

  # Add main targets
  add_executable(${LAB_TARGET} bench.cpp ${srcs} ${PNL_EXT_LAB_srcs})
  add_executable(${VALIDATE_TARGET} validate.cpp ${srcs} ${PNL_EXT_VALIDATE_srcs})

  # Keep executable output names simple
  set_target_properties(${LAB_TARGET} PROPERTIES OUTPUT_NAME "lab")
  set_target_properties(${VALIDATE_TARGET} PROPERTIES OUTPUT_NAME "validate")

  if(NOT PNL_DISABLE_FAST_MATH)
    if(NOT MSVC)
      target_compile_options(${LAB_TARGET} PRIVATE -ffast-math)
      target_compile_options(${VALIDATE_TARGET} PRIVATE -ffast-math)
    else()
      target_compile_options(${LAB_TARGET} PRIVATE /fp:fast)
      target_compile_options(${VALIDATE_TARGET} PRIVATE /fp:fast)
    endif()
  endif()

  if(PNL_DISABLE_O3)
    if(NOT MSVC)
      target_compile_options(${LAB_TARGET} PRIVATE -O0)
      target_compile_options(${VALIDATE_TARGET} PRIVATE -O0)
    else()
      target_compile_options(${LAB_TARGET} PRIVATE /Od)
      target_compile_options(${VALIDATE_TARGET} PRIVATE /Od)
    endif()
  endif()

  # Extra per-target C++ flags
  if(PNL_CXX_EXTRA_FLAGS)
    target_compile_options(${LAB_TARGET} PRIVATE ${PNL_CXX_EXTRA_FLAGS})
    target_compile_options(${VALIDATE_TARGET} PRIVATE ${PNL_CXX_EXTRA_FLAGS})
  endif()

  # Add extra include directories
  if(PNL_EXTRA_INCLUDE_DIRECTORIES)
    target_include_directories(${LAB_TARGET} PRIVATE ${PNL_EXTRA_INCLUDE_DIRECTORIES})
    target_include_directories(${VALIDATE_TARGET} PRIVATE ${PNL_EXTRA_INCLUDE_DIRECTORIES})
  endif()

  # Check optional arguments
  if(NOT DEFINED CI)
    set(CI OFF)
  endif()

  if("${BENCHMARK_MIN_TIME}" STREQUAL "")
    set(BENCHMARK_MIN_TIME "2s")
  endif()

  set(LAB_BENCHMARK_ARGS
    --benchmark_min_time=${BENCHMARK_MIN_TIME}
    --benchmark_out_format=json
    --benchmark_out=result.json
  )

  add_custom_target(${VALIDATE_RUN_TARGET}
    COMMAND $<TARGET_FILE:${VALIDATE_TARGET}> ${PNL_VALIDATE_ARGS}
    DEPENDS ${VALIDATE_TARGET}
    VERBATIM
  )

  add_custom_target(${BENCHMARK_RUN_TARGET}
    COMMAND $<TARGET_FILE:${LAB_TARGET}> ${PNL_LAB_ARGS} ${LAB_BENCHMARK_ARGS}
    DEPENDS ${LAB_TARGET}
    VERBATIM
  )

  # Other settings
  if(NOT MSVC)
    if(WIN32)
      target_link_libraries(${LAB_TARGET} PRIVATE shlwapi)
      target_link_libraries(${VALIDATE_TARGET} PRIVATE shlwapi)
    else()
      target_link_libraries(${LAB_TARGET} PRIVATE pthread m)
      target_link_libraries(${VALIDATE_TARGET} PRIVATE pthread m)
    endif()

    if(MINGW)
      target_link_libraries(${LAB_TARGET} PRIVATE shlwapi)
      target_link_libraries(${VALIDATE_TARGET} PRIVATE shlwapi)
    endif()
  else()
    target_link_libraries(${LAB_TARGET} PRIVATE Shlwapi.lib)
    target_link_libraries(${VALIDATE_TARGET} PRIVATE Shlwapi.lib)

    set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT ${LAB_TARGET})

    string(REPLACE ";" " " LAB_ARGS_STR "${PNL_LAB_ARGS}")
    string(REPLACE ";" " " VALIDATE_ARGS_STR "${PNL_VALIDATE_ARGS}")

    set_property(TARGET ${LAB_TARGET} PROPERTY VS_DEBUGGER_COMMAND_ARGUMENTS "${LAB_ARGS_STR}")
    set_property(TARGET ${VALIDATE_TARGET} PROPERTY VS_DEBUGGER_COMMAND_ARGUMENTS "${VALIDATE_ARGS_STR}")

    set_property(GLOBAL PROPERTY USE_FOLDERS ON)

    set_target_properties(${VALIDATE_RUN_TARGET} PROPERTIES FOLDER CI)
    set_target_properties(${BENCHMARK_RUN_TARGET} PROPERTIES FOLDER CI)
  endif()

  set(ALL_LINK_TARGETS
    fmt::fmt
    benchmark::benchmark
    ${PNL_EXTRA_TARGETS}
  )

  target_link_libraries(${LAB_TARGET} PRIVATE ${ALL_LINK_TARGETS})
  target_link_libraries(${VALIDATE_TARGET} PRIVATE ${ALL_LINK_TARGETS})

  # set_property(GLOBAL APPEND PROPERTY PERF_NINJA_LAB_TARGETS "${LAB_TARGET}")
  # set_property(GLOBAL APPEND PROPERTY PERF_NINJA_VALIDATE_TARGETS "${VALIDATE_TARGET}")
  # set_property(GLOBAL APPEND PROPERTY PERF_NINJA_VALIDATE_RUN_TARGETS "${VALIDATE_RUN_TARGET}")
  # set_property(GLOBAL APPEND PROPERTY PERF_NINJA_BENCHMARK_RUN_TARGETS "${BENCHMARK_RUN_TARGET}")
endfunction()