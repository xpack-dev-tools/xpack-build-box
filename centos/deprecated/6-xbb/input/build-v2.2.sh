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

# Script to build a subsequent version of a Docker image with the
# xPack Build Box (XBB).

# -----------------------------------------------------------------------------

# apt-get install --yes bzip2
# bzip2 --version
# tar --version

# apt-get install --yes autoconf automake
# autoconf --version
# automake --version

# apt-get install --yes patch diffutils
# patch --version
# diff --version

# libxext-dev libx11-dev

# -----------------------------------------------------------------------------

XBB_VERSION="2.2"
echo
echo "centOS XBB v${XBB_VERSION} script started..."

# -----------------------------------------------------------------------------

XBB_INPUT_FOLDER="/xbb-input"
source "${XBB_INPUT_FOLDER}/common-functions-source.sh"
source "${XBB_INPUT_FOLDER}/common-libs-functions-source.sh"
source "${XBB_INPUT_FOLDER}/common-apps-functions-source.sh"

prepare_xbb_env

# source "${XBB_BOOTSTRAP_FOLDER}/xbb-source.sh"

# Create the xbb-source.sh file. Will be used by applications.
# create_xbb_source

# Copy pkg-config-verbose from bootstrap to here.
# mkdir -p "${XBB_FOLDER}/bin"
# /usr/bin/install -m755 -c "${XBB_BOOTSTRAP_FOLDER}/bin/pkg-config-verbose" "${XBB_FOLDER}/bin/pkg-config-verbose"

# -----------------------------------------------------------------------------

# xbb_activate - activate the bootstrap binaries
# xbb_activate_installed_bin - activate the new xbb binaries
# xbb_activate_installed_dev - activate the new xbb headers & libraries

(
  xbb_activate

  echo
  echo "xbb_activate"
  echo ${PATH}
  echo ${LD_LIBRARY_PATH}

  echo
  g++ --version
  # g++-7bs --version
)

# -----------------------------------------------------------------------------

# Required by libSDL, without it QEMU does not start in graphical mode.
# yum provides '*/X11/extensions/Xext.h'
# yum provides '*/GL/gl.h'
yum install -y libX11-devel libXext-devel mesa-libGL-devel

# -----------------------------------------------------------------------------

echo
echo "Done"

# -----------------------------------------------------------------------------
