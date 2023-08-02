cmake_minimum_required (VERSION 3.11)
project (libltfat C CXX)

# JMZ 2023-07-27
# - check whether the linker supports '--no-undefined'
# - drop '-rpath,"$ORIGIN"' from the linker flags
#   (use CMAKE_BUILD_RPATH_USE_ORIGIN=ON instead)

include(CheckCCompilerFlag)
if (${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.18.0")
  include(CheckLinkerFlag)
endif()

#set(CMAKE_BUILD_TYPE "Release")

set(CMAKE_VERBOSE_MAKEFILE ON)

if (APPLE)
  set(CMAKE_INSTALL_NAME_DIR "@loader_path" CACHE STRING "Directory name for installed targets on Apple platforms." )
else()
  option(CMAKE_BUILD_RPATH_USE_ORIGIN "Whether to use relative paths for the build 'RPATH' (Linux only)." ON)
endif()

option(BUILD_SHARED_LIBS
  "Build .so/.dll" ON)

option(NOBLASLAPACK
  "Disable BLAS and LAPACK dependency" ON)

option(NOFFTW
  "Disable FFTW dependency" ON)

if (MSVC)
  set(USECPP 1)
else (MSVC)
  option(USECPP
    "Use C++ compiler" OFF)
endif (MSVC)

if (NOT NOFFTW)
  FIND_LIBRARY(FFTW3_LIB NAMES fftw3 libfftw3)
  FIND_LIBRARY(FFTW3F_LIB NAMES fftw3f libfftw3f)
endif (NOT NOFFTW)

if (NOT NOBLASLAPACK)
  FIND_LIBRARY(BLAS_LIB NAMES blas libblas)
  FIND_LIBRARY(LAPACK_LIB NAMES lapack liblapack)
endif (NOT NOBLASLAPACK)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/build)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/build)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/build)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)


if (NOBLASLAPACK)
  add_definitions(-DNOBLASLAPACK)
endif (NOBLASLAPACK)

if (NOFFTW)
  add_definitions(-DKISS)
else (NOFFTW)
  add_definitions(-DFFTW)
endif (NOFFTW)

if (MSVC)
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W4 /wd4706")
  SET(HAVE_FLAG_WL_NO_UNDEFINED 0)
else (MSVC)
  SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")

  if (${CMAKE_VERSION} VERSION_LESS "3.18.0")
    set(WL_NO_UNDEFINED_OPT "-Wl,--no-undefined")
    check_c_compiler_flag(${WL_NO_UNDEFINED_OPT} HAVE_FLAG_WL_NO_UNDEFINED)
  else()
    set(WL_NO_UNDEFINED_OPT "-Wl,--no-undefined")
    check_linker_flag(C "${WL_NO_UNDEFINED_OPT}" HAVE_FLAG_WL_NO_UNDEFINED)
  endif()

  SET(LIBS m)
  if(CMAKE_CROSSCOMPILING)
    SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -static-libgcc")
  endif(CMAKE_CROSSCOMPILING)
endif(MSVC)

set(OLD_CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
set(OLD_CMAKE_C_FLAGS ${CMAKE_C_FLAGS})

if(USECPP)
  set (CMAKE_CXX_STANDARD 11)
else(USECPP)
  set (CMAKE_C_STANDARD 99)
endif(USECPP)

if (MSVC)
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /D_HAS_EXCEPTIONS=0 /EHsc")
else (MSVC)
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions -fno-rtti")
  SET(LIBS m)
endif(MSVC)

if (HAVE_FLAG_WL_NO_UNDEFINED)
  SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${WL_NO_UNDEFINED_OPT}")
endif()

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/modules/libltfat/include)

add_subdirectory(modules/libltfat/src)

option(DO_LIBPHASERET
  "Compile libphaseret module" OFF)

if (DO_LIBPHASERET)
  add_subdirectory(modules/libphaseret/src)
endif (DO_LIBPHASERET)

add_subdirectory(examples EXCLUDE_FROM_ALL)
