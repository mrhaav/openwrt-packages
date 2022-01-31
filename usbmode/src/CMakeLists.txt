cmake_minimum_required(VERSION 2.6)

PROJECT(usbmode C)
ADD_DEFINITIONS(-Os -ggdb -Wall -Werror --std=gnu99 -Wmissing-declarations)

FIND_PATH(ubox_include_dir libubox/blobmsg_json.h)
INCLUDE_DIRECTORIES(${ubox_include_dir})

SET(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")

SET(SOURCES main.c switch.c)

find_package(PkgConfig)
pkg_check_modules(LIBUSB1 REQUIRED libusb-1.0)
ADD_DEFINITIONS(${LIBUSB1_CFLAGS})
FIND_LIBRARY(libusb NAMES usb-1.0 HINTS ${LIBUSB1_LIBDIR})
FIND_LIBRARY(json NAMES json-c json)

SET(LIBS ubox blobmsg_json ${libusb} ${json})

IF(DEBUG)
  ADD_DEFINITIONS(-DDEBUG -g3)
ENDIF()

ADD_EXECUTABLE(usbmode ${SOURCES})
TARGET_LINK_LIBRARIES(usbmode ${LIBS})

INSTALL(TARGETS usbmode
	RUNTIME DESTINATION sbin
)
