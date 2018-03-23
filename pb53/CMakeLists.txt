set(PB_SRC
  src/pb.c

)

include_directories(
  ..
)

add_library(pb STATIC
  ${PB_SRC}
)

set_target_properties(pb
    PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
)
