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

# This script installs a set of tools to bootstrap the
# macOS XBB (xPack Build Box).
# Basically it tries to be similar to the Docker images.

# -----------------------------------------------------------------------------

XBB_VERSION="3.3"
XBB_LAYER="xbb-bootstrap"

WORK_FOLDER_PATH="${HOME}/Work"

XBB_INSTALL_FOLDER_PATH="${HOME}/.local/xbb-bootstrap"

# -----------------------------------------------------------------------------

helper_folder_path="$(dirname "${script_folder_path}")/helper"

source "${helper_folder_path}/common-functions-source.sh"
source "${helper_folder_path}/common-docker-functions-source.sh"

source "${helper_folder_path}/common-libs-functions-source.sh"
source "${helper_folder_path}/common-apps-functions-source.sh"

source "${helper_folder_path}/common-versions-bootstrap-source.sh"

function xbb_activate()
{
  # Use it for consistency reasons with macOS, where many tools are
  # not available and must be provided by the bootstrap.
  xbb_activate_installed_bin
}

function do_cleanup()
{
  :
}

# -----------------------------------------------------------------------------

cd "${script_folder_path}"

do_prerequisites

echo
echo "$(uname) ${HOST_MACHINE} XBB bootstrap v${XBB_VERSION} build script started..."

# -----------------------------------------------------------------------------

build_versioned_components

# -----------------------------------------------------------------------------

echo
echo "$(uname) ${HOST_MACHINE} XBB bootstrap v${XBB_VERSION} created in \"${INSTALL_FOLDER_PATH}\""

do_cleanup

stop_timer

# -----------------------------------------------------------------------------

if [ "${HOST_UNAME}" == "Darwin" ]
then
  echo
  echo "macOS version ${MACOS_VERSION}"
  echo "XCode Command Line Tools version ${xclt_version}"
fi

echo
echo "You may want to ' chmod -R -w \"${INSTALL_FOLDER_PATH}\" '"

# -----------------------------------------------------------------------------
