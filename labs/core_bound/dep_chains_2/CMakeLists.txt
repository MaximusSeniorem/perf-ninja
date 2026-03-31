cmake_minimum_required(VERSION 3.20)

if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  set(SLP_DISABLE_FLAG -fno-slp-vectorize)
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(SLP_DISABLE_FLAG -fno-tree-slp-vectorize)
endif()

add_perf_ninja_lab_targets(
  DISABLE_O3
  CXX_EXTRA_FLAGS ${SLP_DISABLE_FLAG}
)
