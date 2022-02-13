cmake_minimum_required(VERSION 2.6)

PROJECT(umbim C)

OPTION(PROXY OFF)

ADD_DEFINITIONS(-Os -ggdb -Wextra -Wall -Werror --std=gnu99 -Wmissing-declarations -Wno-unused-parameter)

SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")

SET(SOURCES cli.c mbim-enum.c mbim-dev.c mbim-msg.c )

SET(LIBS ubox)

IF(DEBUG)
  ADD_DEFINITIONS(-DDEBUG -g3)
ENDIF()

IF(PROXY)
  ADD_DEFINITIONS(-DLIBQMI_MBIM_PROXY)
ENDIF()

ADD_EXECUTABLE(umbim ${SOURCES})

TARGET_LINK_LIBRARIES(umbim ${LIBS})

INSTALL(TARGETS umbim
	RUNTIME DESTINATION sbin
)
