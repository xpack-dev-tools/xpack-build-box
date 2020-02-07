#!/usr/bin/env bash

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
# This script creates the XBB xbb docker images.

XBB_VERSION="3.1"

WORK_FOLDER_PATH="${HOME}/Work"

XBB_FOLDER="/opt/xbb-xbb"
XBB_xbb_FOLDER="${XBB_FOLDER}"

IS_BOOTSTRAP="y"

# -----------------------------------------------------------------------------

helper_folder_path="${script_folder_path}/helper"

source "${helper_folder_path}/common-functions-source.sh"
source "${helper_folder_path}/common-docker-functions-source.sh"

source "${helper_folder_path}/common-libs-functions-source.sh"
source "${helper_folder_path}/common-apps-functions-source.sh"

source "${helper_folder_path}/common-versions-source.sh"

function do_cleanup()
{
  if [ -f "${WORK_FOLDER_PATH}/.dockerenv" ]
  then
    rm -rf "${WORK_FOLDER_PATH}"
  fi
}

function xbb_activate()
{
  xbb_activate_installed_bin  # Use xbb binaries
  xbb_activate_installed_dev  # Use xbb libraries and headers
}

# -----------------------------------------------------------------------------

detect_host

docker_prepare_env

prepare_xbb_env

create_xbb_source

echo
echo "$(uname) XBB xbb build script started..."

# -----------------------------------------------------------------------------

do_build_versions

do_strip_debug_libs

# -----------------------------------------------------------------------------

echo
echo "$(uname) XBB xbb created in \"${INSTALL_FOLDER_PATH}\""

do_cleanup

echo
echo "Container done."

# -----------------------------------------------------------------------------
