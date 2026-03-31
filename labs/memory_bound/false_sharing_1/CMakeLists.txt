cmake_minimum_required(VERSION 3.20)

find_package(OpenMP CONFIG)

if (OpenMP_CXX_FOUND)
    add_perf_ninja_lab(
    EXTRA_TARGETS OpenMP::OpenMP_CXX
    )
else()
    message(WARNING "OpenMP not found, skipping false sharing lab")
endif()