cmake_minimum_required(VERSION 3.10)
project(BookMeSilly)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt Configuration
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 COMPONENTS Core Gui Widgets REQUIRED)

# Add Catch2 for unit testing
include(FetchContent)
FetchContent_Declare(
    catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.4.0
)
FetchContent_MakeAvailable(catch2)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)

# Backend Library
file(GLOB BACKEND_SOURCES "src/backend/*.cpp")
file(GLOB BACKEND_HEADERS "include/backend/*.h")
add_library(backend ${BACKEND_SOURCES} ${BACKEND_HEADERS})
target_include_directories(backend PUBLIC ${CMAKE_SOURCE_DIR}/include)

# Frontend Library
file(GLOB FRONTEND_SOURCES "src/frontend/*.cpp")
file(GLOB FRONTEND_HEADERS "include/frontend/*.h")
add_library(frontend ${FRONTEND_SOURCES} ${FRONTEND_HEADERS})
target_include_directories(frontend PUBLIC ${CMAKE_SOURCE_DIR}/include)
target_link_libraries(frontend PUBLIC backend Qt6::Core Qt6::Gui Qt6::Widgets)

# Main Executable
add_executable(app src/main.cpp)
target_link_libraries(app PRIVATE backend frontend Qt6::Core Qt6::Gui Qt6::Widgets)

# Tests (using Catch2)
enable_testing()

add_executable(test_calculator tests/unit/backend/test_calculator.cpp)
target_link_libraries(test_calculator PRIVATE backend Catch2::Catch2WithMain)
add_test(NAME test_calculator COMMAND test_calculator)
