# Copies the game executable into a fresh folder (with optional data folders), runs it there and
# checks its exit code and output. Used by CTest for the asset-layout and error-reporting specs.
set(dir ${OUT}/${NAME})
file(REMOVE_RECURSE ${dir})
file(MAKE_DIRECTORY ${dir})
get_filename_component(exe_name ${EXE} NAME)
file(COPY ${EXE} DESTINATION ${dir})
# DATA and ARGS use '|' between items, because CTest would split ';' into separate arguments.
string(REPLACE "|" ";" DATA "${DATA}")
string(REPLACE "|" ";" ARGS "${ARGS}")
string(REPLACE "|" ";" WRAP "${WRAP}") # optional command in front of the executable, e.g. a timeout
foreach(d ${DATA}) # later folders overlay earlier ones
  file(COPY ${d}/ DESTINATION ${dir}/data)
endforeach()
if(NOT CWD)
  set(CWD ${dir})
endif()
execute_process(COMMAND ${WRAP} ${dir}/${exe_name} ${ARGS}
  WORKING_DIRECTORY ${CWD} RESULT_VARIABLE code OUTPUT_VARIABLE out ERROR_VARIABLE out)
message("${out}")
if(NOT code EQUAL EXPECT)
  message(FATAL_ERROR "exit code ${code}, expected ${EXPECT}")
endif()
if(MATCH AND NOT out MATCHES "${MATCH}")
  message(FATAL_ERROR "output does not contain '${MATCH}'")
endif()
