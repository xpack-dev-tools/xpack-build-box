#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (http://xpack.github.io)
# Copyright (c) 2019-2026 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software
# for any purpose is hereby granted, under the terms of the MIT license.
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

build_script_path="$0"
if [[ "${build_script_path}" != /* ]]
then
  # Make relative path absolute.
  build_script_path="$(pwd)/$0"
fi

script_folder_path="$(dirname "${build_script_path}")"
script_folder_name="$(basename "${script_folder_path}")"

# =============================================================================

# This script installs a set of tools to bootstrap the
# macOS XBB (xPack Build Box).
# Basically it tries to be similar to the Docker images.

# -----------------------------------------------------------------------------

XBB_VERSION="2.1"
echo
echo "macOS XBB Bootstrap v${XBB_VERSION} build script started..."

# -----------------------------------------------------------------------------

XBB_FOLDER="${HOME}/opt/xbb-bootstrap"

WORK_FOLDER_PATH="${HOME}/Work/darwin-$(basename "${XBB_FOLDER}")"

IS_BOOTSTRAP="y"

# -----------------------------------------------------------------------------

source "${script_folder_path}/common-functions-source.sh"
source "${script_folder_path}/common-libs-functions-source.sh"
source "${script_folder_path}/common-apps-functions-source.sh"

CC=clang
CXX=clang++

prepare_xbb_env

create_xbb_source

xbb_activate()
{
  :
}

# -----------------------------------------------------------------------------

# To differentiate the binaries from the XBB ones which use `-7`.
XBB_GCC_SUFFIX="-7bs"
XBB_GCC_BRANDING="xPack Build Box Bootstrap GCC\x2C 64-bit"

# =============================================================================

# Libraries

build_zlib "1.2.11"

build_gmp "6.1.2"
build_mpfr "3.1.6"
build_mpc "1.0.3"
build_isl "0.21"

# Applications

build_coreutils "8.31"

build_pkg_config "0.29.2"

build_m4 "1.4.18"

build_gawk "4.2.1"
build_sed "4.7"
build_autoconf "2.69"
build_automake "1.16"
build_libtool "2.4.6"

build_diffutils "3.7"
build_patch "2.7.6"

build_bison "3.3.2"

# macOS 10.10 uses 2.5.3, an update is not mandatory.
# build_flex "2.6.4"

build_make "4.2.1"

# macOS 10.10 uses 5.18.2, an update is not mandatory.
# build_perl "5.28.1"

build_cmake "3.13.4"

# makedepend is needed by openssl
build_util_macros "1.17.1"
build_xorg_xproto "7.0.31"
build_makedepend "1.0.5"

# By all means DO NOT build binutils, since this will override Apple
# specific tools (ar, strip, etc) and break the build in multiple ways.

# Preferably leave it to the end, to benefit from all the goodies
# compiled so far.
do_gcc "7.4.0"

# -----------------------------------------------------------------------------

check_binaries

# -----------------------------------------------------------------------------

echo
echo "macOS version ${macos_version}"
echo "XCode Command Line Tools version ${xclt_version}"

echo
echo "You may want to ' chmod -R -w \"${INSTALL_FOLDER_PATH}\" '"

echo
echo "macOS XBB Bootstrap v${XBB_VERSION} created in \"${INSTALL_FOLDER_PATH}\""
say done

# -----------------------------------------------------------------------------
