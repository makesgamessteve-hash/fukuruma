cmake_minimum_required(VERSION 3.24)
project(fukuruma C)

option(FK_WERROR "Treat warnings as errors" OFF)
option(FK_COVERAGE "Instrument the engine for gcov" OFF)
option(FK_SANITIZE "Build with AddressSanitizer and UndefinedBehaviorSanitizer" OFF)

# --- SDL3 (pinned release, static) -----------------------------------------
include(FetchContent)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_Declare(SDL3
  URL https://github.com/libsdl-org/SDL/releases/download/release-3.4.20/SDL3-3.4.20.tar.gz
  URL_HASH SHA256=f3bb06f55bed9557227a700af2ea62e49497ebdf58037732a731a5fb3ef8581f
  DOWNLOAD_EXTRACT_TIMESTAMP TRUE)
FetchContent_MakeAvailable(SDL3)

# Strict C11 for our code only (set after SDL, which needs GNU extensions on the web).
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# --- Vendored third-party code (built without project warnings) ------------
file(GLOB FK_LUA_SRC ${CMAKE_SOURCE_DIR}/third_party/lua/*.c)
add_library(fk_third_party STATIC ${FK_LUA_SRC} third_party/stb/stb_impl.c third_party/cgltf/cgltf_impl.c)
target_include_directories(fk_third_party SYSTEM PUBLIC third_party/lua third_party/stb third_party/cgltf)
if(UNIX)
  target_compile_definitions(fk_third_party PRIVATE LUA_USE_POSIX)
  target_link_libraries(fk_third_party PUBLIC m)
endif()

# --- Engine ------------------------------------------------------------------
function(fk_settings target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /fp:precise)
    if(FK_WERROR)
      target_compile_options(${target} PRIVATE /WX)
    endif()
  else()
    # -ffp-contract=off: no fused multiply-add, so results match on every platform.
    target_compile_options(${target} PRIVATE -Wall -Wextra -Wshadow -ffp-contract=off)
    if(FK_WERROR)
      target_compile_options(${target} PRIVATE -Werror)
    endif()
  endif()
  if(FK_COVERAGE)
    target_compile_options(${target} PRIVATE --coverage -fprofile-update=atomic -O0) # atomic: jobs run on threads
    target_link_options(${target} PRIVATE --coverage)
  endif()
  if(FK_SANITIZE)
    target_compile_options(${target} PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer)
    target_link_options(${target} PRIVATE -fsanitize=address,undefined)
  endif()
endfunction()

file(GLOB_RECURSE FK_ENGINE_SRC CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/engine/src/*.c)
list(REMOVE_ITEM FK_ENGINE_SRC ${CMAKE_SOURCE_DIR}/engine/src/platform/main.c)
add_library(fk_engine STATIC ${FK_ENGINE_SRC})
target_include_directories(fk_engine PUBLIC engine/src)
target_link_libraries(fk_engine PUBLIC fk_third_party SDL3::SDL3-static)
fk_settings(fk_engine)
if(NOT MSVC AND CMAKE_BUILD_TYPE STREQUAL "Debug")
  # The generators' hot loops (noise, planet chunks, galaxy) stay quick in debug and coverage builds (still
  # instrumented); -ffp-contract=off keeps their results identical.
  file(GLOB FK_GEN_SRC ${CMAKE_SOURCE_DIR}/engine/src/gen/*.c)
  # Coverage: plain counters in these loops (atomic ones cost several times the work; a rare lost count when two
  # workers hit the same line is harmless for line coverage).
  set_source_files_properties(${FK_GEN_SRC} PROPERTIES COMPILE_OPTIONS "-O2;$<$<BOOL:${FK_COVERAGE}>:-fprofile-update=single>")
endif()

add_executable(fukuruma engine/src/platform/main.c)
target_link_libraries(fukuruma PRIVATE fk_engine)
fk_settings(fukuruma)

if(EMSCRIPTEN)
  set_target_properties(fukuruma PROPERTIES SUFFIX ".html")
  target_link_options(fukuruma PRIVATE
    -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -sGL_ENABLE_GET_PROC_ADDRESS=1
    -sALLOW_MEMORY_GROWTH=1 -sEXIT_RUNTIME=0 -lidbfs.js
    "SHELL:--pre-js ${CMAKE_SOURCE_DIR}/web/storage.js" "SHELL:--pre-js ${CMAKE_SOURCE_DIR}/web/xr.js" # (SHELL: keeps CMake from merging the repeated flag)
    --shell-file ${CMAKE_SOURCE_DIR}/web/shell.html
    "SHELL:--preload-file ${CMAKE_SOURCE_DIR}/data@/data"
    "SHELL:--preload-file ${CMAKE_SOURCE_DIR}/tests/game@/tests/game")
  # shortcut: relinks only when the shell or a data/test file listed at configure time changes; re-run cmake after adding files.
  file(GLOB_RECURSE FK_WEB_DEPS ${CMAKE_SOURCE_DIR}/data/* ${CMAKE_SOURCE_DIR}/tests/game/*)
  set_property(TARGET fukuruma APPEND PROPERTY LINK_DEPENDS ${CMAKE_SOURCE_DIR}/web/shell.html ${CMAKE_SOURCE_DIR}/web/xr.js
    ${FK_WEB_DEPS})
  add_custom_command(TARGET fukuruma POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy fukuruma.html index.html
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
  return()
endif()

# The game reads data/ beside the executable. shortcut: files deleted from data/ stay in the build folder until it is cleaned.
add_custom_target(fk_data ALL
  COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/data $<TARGET_FILE_DIR:fukuruma>/data)

# --- Tests -------------------------------------------------------------------
enable_testing()
file(GLOB FK_UNIT_SRC CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/tests/unit/*.c)
add_executable(fk_tests ${FK_UNIT_SRC})
target_link_libraries(fk_tests PRIVATE fk_engine)
target_include_directories(fk_tests SYSTEM PRIVATE third_party/utest)
fk_settings(fk_tests)

set(FK_EXE $<TARGET_FILE:fukuruma>)
set(FK_SRC ${CMAKE_SOURCE_DIR})
set(FK_RUN ${CMAKE_COMMAND} -DEXE=${FK_EXE} -DSRC=${FK_SRC} -DOUT=${CMAKE_BINARY_DIR}/test-run)

target_compile_definitions(fk_tests PRIVATE FK_TESTS_DIR="${FK_SRC}/tests")
add_test(NAME unit_c COMMAND fk_tests)
add_test(NAME unit_lua COMMAND fukuruma --test ${FK_SRC}/tests/lua)
add_test(NAME game_boot_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/boot.lua)
add_test(NAME data_missing COMMAND ${FK_RUN} -DNAME=data_missing -DEXPECT=1
  -DMATCH=data/scripts/main.lua -DARGS=--no-render -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME data_other_cwd COMMAND ${FK_RUN} -DNAME=data_other_cwd -DDATA=${FK_SRC}/data -DEXPECT=0
  -DCWD=${CMAKE_BINARY_DIR}/test-run "-DARGS=--no-render|--scenario|${FK_SRC}/tests/game/boot.lua" -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME game_tick_error_headless COMMAND ${FK_RUN} -DNAME=tick_error
  "-DDATA=${FK_SRC}/data|${FK_SRC}/tests/fixtures/tick_error/data" -DEXPECT=1 -DMATCH=traceback -DARGS=--headless
  -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME game_bad_shader COMMAND ${FK_RUN} -DNAME=bad_shader
  "-DDATA=${FK_SRC}/data|${FK_SRC}/tests/fixtures/bad_shader/data" -DEXPECT=1 -DMATCH=shader
  "-DARGS=--headless|--scenario|${FK_SRC}/tests/game/boot.lua" -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME scenario_timeout_exit_code COMMAND ${FK_RUN} -DNAME=timeout -DDATA=${FK_SRC}/data -DEXPECT=2
  "-DARGS=--no-render|--scenario|${FK_SRC}/tests/fixtures/scenarios/timeout.lua" -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME video_unavailable COMMAND fukuruma)
set_tests_properties(video_unavailable PROPERTIES ENVIRONMENT SDL_VIDEO_DRIVER=bogus PASS_REGULAR_EXPRESSION "cannot start video")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  # A windowed (interactive) run keeps its window open after a script error; SIGTERM ends it cleanly.
  add_test(NAME game_interactive_error COMMAND ${FK_RUN} -DNAME=interactive_error
    "-DDATA=${FK_SRC}/data|${FK_SRC}/tests/fixtures/tick_error/data" -DEXPECT=124 -DMATCH=boom
    "-DWRAP=timeout|-s|TERM|-k|5|2" -P ${FK_SRC}/tests/run_exe.cmake)
  set_tests_properties(game_interactive_error PROPERTIES ENVIRONMENT SDL_VIDEO_DRIVER=offscreen LABELS game)
endif()
add_test(NAME game_call_order COMMAND ${FK_RUN} -DNAME=call_order
  "-DDATA=${FK_SRC}/data|${FK_SRC}/tests/fixtures/counting/data" -DEXPECT=0
  "-DARGS=--no-render|--scenario|${FK_SRC}/tests/fixtures/scenarios/call_order.lua" -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME game_only_tick COMMAND ${FK_RUN} -DNAME=only_tick
  "-DDATA=${FK_SRC}/data|${FK_SRC}/tests/fixtures/only_tick/data" -DEXPECT=0
  "-DARGS=--no-render|--scenario|${FK_SRC}/tests/fixtures/scenarios/pass.lua" -P ${FK_SRC}/tests/run_exe.cmake)
add_test(NAME game_simulation_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/simulation.lua)
add_test(NAME game_input_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/input.lua)
add_test(NAME game_input COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/input.lua)
add_test(NAME game_boot COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/boot.lua)
add_test(NAME game_showcase_lighting COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/showcase_lighting.lua)
add_test(NAME game_showcase_materials COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/showcase_materials.lua)
add_test(NAME game_showcase_skinning COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/showcase_skinning.lua)
add_test(NAME game_feel COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/feel.lua)
add_test(NAME game_feel_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/feel.lua)
add_test(NAME game_audio_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/audio.lua)
add_test(NAME game_save_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/save.lua)
add_test(NAME game_first_person COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/first_person.lua)
add_test(NAME game_first_person_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/first_person.lua)
add_test(NAME game_scale_ladder COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/scale_ladder.lua)
add_test(NAME game_scale_ladder_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/scale_ladder.lua)
add_test(NAME game_orbits_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/orbits.lua)
add_test(NAME game_physics COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/physics.lua)
add_test(NAME game_physics_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/physics.lua)
add_test(NAME game_systems_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/systems.lua)
add_test(NAME game_navigation COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/navigation.lua)
add_test(NAME game_navigation_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/navigation.lua)
add_test(NAME game_planets COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/planets.lua)
add_test(NAME game_terrain_materials COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/terrain_materials.lua)
add_test(NAME game_water COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/water.lua)
add_test(NAME game_weather COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/weather.lua)
add_test(NAME game_rivers COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/rivers.lua)
add_test(NAME game_chain COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/chain.lua)
add_test(NAME game_drive COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/drive.lua)
add_test(NAME game_travel COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/travel.lua)
add_test(NAME game_interiors COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/interiors.lua)
add_test(NAME game_hangars COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/hangars.lua)
add_test(NAME game_sensors COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/sensors.lua)
add_test(NAME game_survival COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/survival.lua)
add_test(NAME game_civilisations COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/civilisations.lua)
add_test(NAME game_progression COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/progression.lua)
add_test(NAME game_fukuruma COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/fukuruma.lua)
add_test(NAME game_chain_views COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/chain_views.lua)
add_test(NAME game_touch_layout COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/touch_layout.lua)
add_test(NAME game_stereo COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/stereo.lua)
add_test(NAME game_clouds COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/clouds.lua)
add_test(NAME game_dig COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/dig.lua)
add_test(NAME game_descent COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/descent.lua)
add_test(NAME game_stars COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/stars.lua)
add_test(NAME game_graphics_menu COMMAND fukuruma --headless --scenario ${FK_SRC}/tests/game/graphics_menu.lua)
add_test(NAME game_graphics_menu_norender COMMAND fukuruma --no-render --scenario ${FK_SRC}/tests/game/graphics_menu.lua)
add_test(NAME game_boot_reproducible COMMAND ${CMAKE_COMMAND} -DEXE=${FK_EXE} -DSRC=${FK_SRC}
  -P ${FK_SRC}/tests/reproducible.cmake)
set_tests_properties(unit_c unit_lua game_boot_norender data_missing data_other_cwd scenario_timeout_exit_code video_unavailable
  game_call_order game_only_tick game_simulation_norender game_input_norender game_graphics_menu_norender
  game_feel_norender game_audio_norender game_save_norender game_first_person_norender
  game_scale_ladder_norender game_orbits_norender game_physics_norender
  game_systems_norender game_navigation_norender PROPERTIES LABELS unit)
set_tests_properties(game_tick_error_headless game_bad_shader game_boot game_boot_reproducible game_input
  game_showcase_lighting game_showcase_materials game_showcase_skinning game_feel game_graphics_menu game_first_person
  game_scale_ladder game_physics game_navigation game_planets game_stars game_descent game_terrain_materials game_dig game_clouds game_water game_weather game_rivers game_chain game_drive game_travel game_fukuruma game_chain_views game_touch_layout game_stereo game_interiors game_hangars game_sensors game_survival game_civilisations game_progression PROPERTIES LABELS game)
get_property(FK_ALL_TESTS DIRECTORY PROPERTY TESTS)
set_tests_properties(${FK_ALL_TESTS} PROPERTIES TIMEOUT 60) # a hanging test fails fast instead of blocking CI
set_tests_properties(unit_c unit_lua game_planets game_descent game_navigation game_terrain_materials game_dig game_clouds game_water game_weather game_rivers game_chain game_drive game_travel game_fukuruma game_chain_views game_touch_layout game_stereo game_interiors game_hangars game_sensors game_survival game_civilisations game_progression PROPERTIES TIMEOUT 300)
# The sandbox scenes draw the world's ground (software rendering, instrumented builds): slower than the rest.
set_tests_properties(game_boot game_boot_reproducible game_input game_feel game_first_person game_showcase_lighting
  game_physics game_graphics_menu PROPERTIES TIMEOUT 300) # planet chunks are slow in unoptimised coverage builds
set_tests_properties(game_terrain_materials game_weather game_hangars game_interiors game_survival game_civilisations game_progression PROPERTIES TIMEOUT 900) # the heaviest: with the coverage run's parallel tests
# The slow scenarios (20 s and more) run at the end of a milestone and on CI, not after every change (AGENTS.md):
# ctest -LE slow is the quick set.
set_property(TEST game_terrain_materials game_dig game_weather game_navigation game_descent game_rivers game_physics
  game_boot_reproducible game_showcase_lighting game_graphics_menu game_feel game_water game_first_person game_clouds
  game_drive game_interiors game_hangars game_sensors game_survival game_civilisations game_progression
  APPEND PROPERTY LABELS slow)

if(FK_COVERAGE)
  find_package(Python3 REQUIRED COMPONENTS Interpreter)
  find_program(FK_GCOVR gcovr REQUIRED)
  cmake_host_system_information(RESULT FK_CORES QUERY NUMBER_OF_LOGICAL_CORES)
  add_custom_target(coverage # the tests in parallel: gcov merges each process's counts under a file lock
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --parallel ${FK_CORES}
    COMMAND ${CMAKE_COMMAND} -E env LUA_PATH=${FK_SRC}/third_party/luacov/?.lua
      $<TARGET_FILE:fukuruma> --test ${FK_SRC}/tests/lua --coverage
    COMMAND ${Python3_EXECUTABLE} ${FK_SRC}/tools/coverage/lua_gate.py luacov.report.out 95
    COMMAND ${FK_GCOVR} --gcov-ignore-parse-errors=suspicious_hits.warn --gcov-ignore-parse-errors=negative_hits.warn --root ${FK_SRC} --filter ${FK_SRC}/engine/src
      --print-summary --txt coverage-c.txt --html-details coverage-c.html --fail-under-line 95 ${CMAKE_BINARY_DIR}
    WORKING_DIRECTORY $<TARGET_FILE_DIR:fukuruma>
    VERBATIM)
  add_dependencies(coverage fukuruma fk_tests fk_data)
endif()
