#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
#
# If a copy of the license was not distributed with this file, it can
# be obtained from https://opensource.org/licenses/mit.
#
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Safety settings (see https://gist.github.com/ilg-ul/383869cbb01f61a51c4d).

if [[ ! -z ${DEBUG} ]]
then
  set ${DEBUG} # Activate the expand mode if DEBUG is anything but empty.
else
  DEBUG=""
fi

set -o errexit # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset # Exit if variable not set.

# Remove the initial space and instead use '\n'.
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Identify the script location, to reach, for example, the helper scripts.

script_path="$0"
if [[ "${script_path}" != /* ]]
then
  # Make relative path absolute.
  script_path="$(pwd)/$0"
fi

script_name="$(basename "${script_path}")"

script_folder_path="$(dirname "${script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

function run_verbose()
{
  # Does not include the .exe extension.
  local app_path=$1
  shift

  echo
  echo "[${app_path} $@]"
  "${app_path}" "$@" 2>&1
}

# =============================================================================


PATH="/Users/ilg/Library/xPacks/@xpack-dev-tools/cmake/3.18.5-1.1/.content/bin:${PATH}"
PATH="/Users/ilg/Library/xPacks/@xpack-dev-tools/ninja-build/1.10.1-1.1/.content/bin:${PATH}"
export PATH

build_folder_path="${HOME}/Work/llvm/build"
# source_folder_path="${HOME}/Work/xbb-bootstrap-3.3-macosx-10.15.7-x86_64/sources/llvm-project-10.0.1"
source_folder_path="${HOME}/Work/xbb-bootstrap-3.3-macosx-10.15.7-x86_64/sources/llvm-project-11.0.0"
INSTALL_FOLDER_PATH="${HOME}/Work/llvm/install"

CC=clang
CXX=clang++
CPPFLAGS="-I/Users/ilg/.local/xbb-bootstrap/include"
CFLAGS=
CXXFLAGS=
LDFLAGS="-L/Users/ilg/.local/xbb-bootstrap/lib"

mkdir -pv "${build_folder_path}"
cd "${build_folder_path}"

if true # [ ! -f "build.ninja" ]
then

  echo
  echo "Running llvm cmake..."

  config_options=()

  config_options+=("-GNinja")
  config_options+=("-DCMAKE_INSTALL_PREFIX=${INSTALL_FOLDER_PATH}")

if true
then
  config_options+=("-DCMAKE_C_COMPILER=${CC}")
  config_options+=("-DCMAKE_CXX_COMPILER=${CXX}")
  config_options+=("-DCMAKE_C_FLAGS=${CPPFLAGS} ${CFLAGS}")
  config_options+=("-DCMAKE_CXX_FLAGS=${CPPFLAGS} ${CXXFLAGS}")
  config_options+=("-DCMAKE_EXE_LINKER_FLAGS=${LDFLAGS}")
fi

  config_options+=("-DCMAKE_BUILD_TYPE=Release")

  config_options+=("-DLLVM_TARGETS_TO_BUILD=X86")
  config_options+=("-DLLVM_ENABLE_PROJECTS=clang;clang-tools-extra;lld;lldb;mlir")
  config_options+=("-DLLVM_ENABLE_RUNTIMES=compiler-rt;libcxx;libcxxabi;libunwind")

  config_options+=("-DLLVM_POLLY_LINK_INTO_TOOLS=ON")
  config_options+=("-DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON")
  config_options+=("-DLLVM_LINK_LLVM_DYLIB=ON")
  config_options+=("-DLLVM_BUILD_LLVM_C_DYLIB=ON")
  config_options+=("-DLLVM_ENABLE_EH=ON")
  config_options+=("-DLLVM_ENABLE_FFI=ON")
  config_options+=("-DLLVM_ENABLE_LIBCXX=ON")
  config_options+=("-DLLVM_ENABLE_RTTI=ON")
  config_options+=("-DLLVM_INCLUDE_DOCS=OFF")
  config_options+=("-DLLVM_INCLUDE_TESTS=OFF")
  config_options+=("-DLLVM_INSTALL_UTILS=ON")
  config_options+=("-DLLVM_ENABLE_Z3_SOLVER=OFF")
  config_options+=("-DLLVM_OPTIMIZED_TABLEGEN=ON")
  config_options+=("-DLLVM_TARGETS_TO_BUILD=all")

  config_options+=("-DLLDB_USE_SYSTEM_DEBUGSERVER=ON")
  config_options+=("-DLLDB_ENABLE_PYTHON=OFF")
  config_options+=("-DLLDB_ENABLE_LUA=OFF")
  config_options+=("-DLLDB_ENABLE_LZMA=OFF")
  config_options+=("-DLIBOMP_INSTALL_ALIASES=ON")

if true
then
  config_options+=("-DLLVM_BUILD_LLVM_DYLIB=ON")
  config_options+=("-DLLVM_LINK_LLVM_DYLIB=ON")
  config_options+=("-DLLVM_INSTALL_UTILS=ON")
  config_options+=("-DLLVM_ENABLE_RTTI=ON")
  config_options+=("-DLLVM_ENABLE_FFI=ON")
  config_options+=("-DLLVM_BUILD_TESTS=ON")
  config_options+=("-DLLVM_BUILD_DOCS=OFF")
  config_options+=("-DLLVM_ENABLE_SPHINX=OFF")
  config_options+=("-DLLVM_ENABLE_DOXYGEN=OFF")
  config_options+=("-DLLVM_ENABLE_WARNINGS=OFF")
fi

  run_verbose cmake \
    "${config_options[@]}" \
    "${source_folder_path}/llvm"

fi

run_verbose cmake --build .

run_verbose cmake --build . --target install

