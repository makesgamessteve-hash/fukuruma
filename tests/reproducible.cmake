# Runs the boot scenario twice with the same seed (its own: the seed shapes the galaxy, so the reference image
# needs it) and checks that both final frames are identical.
foreach(i 1 2)
  set(dir ${CMAKE_CURRENT_BINARY_DIR}/test-run/repro${i})
  file(REMOVE_RECURSE ${dir})
  file(MAKE_DIRECTORY ${dir})
  execute_process(COMMAND ${EXE} --headless --seed 1 --scenario ${SRC}/tests/game/boot.lua
    WORKING_DIRECTORY ${dir} RESULT_VARIABLE code)
  if(NOT code EQUAL 0)
    message(FATAL_ERROR "run ${i} exited with ${code}")
  endif()
endforeach()
execute_process(COMMAND ${CMAKE_COMMAND} -E compare_files
  ${CMAKE_CURRENT_BINARY_DIR}/test-run/repro1/test-output/boot.png
  ${CMAKE_CURRENT_BINARY_DIR}/test-run/repro2/test-output/boot.png
  RESULT_VARIABLE diff)
if(NOT diff EQUAL 0)
  message(FATAL_ERROR "the two runs produced different frames")
endif()
