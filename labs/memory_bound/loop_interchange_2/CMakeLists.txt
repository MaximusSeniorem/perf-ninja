cmake_minimum_required(VERSION 3.20)

add_perf_ninja_lab_targets(
  VALIDATE_ARGS
    "${CMAKE_CURRENT_SOURCE_DIR}/pexels-pixabay-434334.pbm"
    "${CMAKE_CURRENT_SOURCE_DIR}/output-golden.pgm"
  LAB_ARGS
    "${CMAKE_CURRENT_SOURCE_DIR}/pexels-pixabay-434334.pbm"
    "output.pgm"
)