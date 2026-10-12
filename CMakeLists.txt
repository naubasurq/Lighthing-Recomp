# ffxiii - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(ffxiii LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)
include(generated/default/sources.cmake)

# Sources
set(FFXIII_SOURCES
    src/main.cpp
)

if(WIN32)
    add_executable(ffxiii WIN32 ${FFXIII_SOURCES})
else()
    add_executable(ffxiii ${FFXIII_SOURCES})
endif()

rexglue_setup_target(ffxiii)
