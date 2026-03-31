cmake_minimum_required(VERSION 3.20)

include_directories(lua)
file(GLOB LUA_SRC lua/*.c)

add_perf_ninja_lab_targets(
    EXT_LAB_srcs ${LUA_SRC}
    EXT_VALIDATE_srcs ${LUA_SRC}
    VALIDATE_ARGS "${CMAKE_CURRENT_SOURCE_DIR}/reference_output.txt"
)
