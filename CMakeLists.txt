cmake_minimum_required(VERSION 3.14)
project(eli LANGUAGES CXX)

set(BINARY_NAME "eli")
cmake_policy(SET CMP0091 NEW)

add_executable(${BINARY_NAME} WIN32
  "runner.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

apply_standard_settings(${BINARY_NAME})
target_compile_features(${BINARY_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${BINARY_NAME} PRIVATE UNICODE _UNICODE)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
add_dependencies(${BINARY_NAME} flutter_assemble)
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
