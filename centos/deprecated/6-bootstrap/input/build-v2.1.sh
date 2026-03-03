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

# Script to build a Docker image with a bootstrap system, used to later build
# the final xPack Build Box (xbb).
#
# Since the orginal CentOS 6 is too old to compile some of the modern
# sources, two steps are required. In the first step are compiled the most
# recent versions allowed by CentOS 6; being based on GCC 7.4, they should
# be enough for a few years to come. With them, in the second step, are
# compiled the very latest versions.

# Credits: Inspired by Holy Build Box build script.

# Note: the initial approach was to disable the creation of all shared
# libraries and try to build everything as static. Unfortunately some
# of the tools are not able to do this correctly, and the final version
# was simplified to the defaults, which generally include both shared and
# static versions for the libraries. The drawback is that, in addition to
# PATH, for the programs to start, the LD_LIBRARY_PATH must also be set
# correctly.

XBB_VERSION="2.1"
XBB_INPUT_FOLDER="/xbb-input"
source "${XBB_INPUT_FOLDER}/common-functions-source.sh"
source "${XBB_INPUT_FOLDER}/common-libs-functions-source.sh"
source "${XBB_INPUT_FOLDER}/common-apps-functions-source.sh"

prepare_xbb_env

create_xbb_source
source "${XBB_FOLDER}/xbb-source.sh"

create_pkg_config_verbose

echo
g++ --version

# =============================================================================

# WARNING: the order is important, since some of the builds depend
# on previous ones.

# For extra safety, the ${XBB_FOLDER} folder is not permanently in the PATH,
# it is added explicitly with xbb_activate in sub-shells;
# by default, the environment is that of the original CentOS.

# -----------------------------------------------------------------------------

XBB_GCC_BRANDING="xPack Build Box Bootstrap GCC\x2C ${BITS}-bit"
XBB_GCC_SUFFIX="-7bs"

if true
then
  # New zlib, it is used in most of the tools.
  build_zlib "1.2.11"

  # Library, required by tar.
  build_xz "5.2.3"

  # New tar, with xz support.
  build_tar "1.30" # Requires xz.

  # From this moment on, .xz archives can be processed.

  # New openssl, required by curl, cmake, python, etc.
  build_openssl "1.0.2r"

  # New curl, that better understands all protocols.
  build_curl "7.57.0"
fi

if true
then
  # GNU tools.
  build_m4 "1.4.18"
  build_gawk "4.2.0"
  build_autoconf "2.69"

  # Requires autoconf 2.65 or better
  build_automake "1.15"
  build_libtool "2.4.6"
  build_gettext "0.19.8"
  build_patch "2.7.5"
  build_diffutils "3.6"
  build_bison "3.0.4"
  build_make "4.2.1"

  # Third party tools.
  build_pkg_config "0.29.2"

  build_flex "2.6.4" # Requires gettext.

  build_perl "5.24.1"
fi

if true
then
  # Libraries, required by gcc.
  build_gmp "6.1.2"
  build_mpfr "3.1.6"
  build_mpc "1.0.3"
  build_isl "0.18"
fi

if true
then
  # Native binutils and gcc.
  build_native_binutils "2.31" # Requires gmp, mpfr, mpc, isl.
  build_native_gcc "7.4.0" # Requires gmp, mpfr, mpc, isl.
fi

# Switch to the newly compiled GCC.
export CC="gcc${XBB_GCC_SUFFIX}"
export CXX="g++${XBB_GCC_SUFFIX}"

(
  xbb_activate_installed_bin

  echo
  ${CXX} --version
)

if true
then
  # Recent versions require C++11.
  build_cmake "3.13.4"
fi

if true
then
  do_python "2.7.14"
  build_scons "3.0.1"
fi

if true
then
  # Strip debug from *.a and *.so.
  do_strip_libs
  do_cleaunup
fi


echo
echo "Done"

# -----------------------------------------------------------------------------
